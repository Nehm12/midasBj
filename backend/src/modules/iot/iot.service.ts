import crypto from 'node:crypto';
import { DeviceStatus, Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';
import { auditService } from '../audit/audit.service.js';
import { broadcastAlert } from '../../infrastructure/ws/alerts.js';

export const iotService = {
  async registerDevice(data: {
    deviceId: string;
    name?: string;
    publicKey: string;
    attestation: Record<string, unknown>;
  }) {
    const device = await prisma.ioTDevice.create({
      data: {
        deviceId: data.deviceId,
        name: data.name ?? 'Appareil IoT',
        publicKey: data.publicKey,
        attestation: data.attestation as Prisma.InputJsonValue,
        status: DeviceStatus.PENDING,
      },
    });

    await auditService.logEvent({
      entityType: 'IoTDevice',
      entityId: device.id,
      action: 'DEVICE_REGISTERED',
      payload: { deviceId: data.deviceId },
    });

    return device;
  },

  async generatePairingChallenge(deviceId: string) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { deviceId },
    });
    const challenge = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 300_000);
    return { challenge, deviceId: device.id, publicKey: device.publicKey, expiresAt };
  },

  async pairDevice(deviceId: string, ownerId: string, signature: string, challenge: string) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { deviceId },
    });
    const message = `pair:${deviceId}:${ownerId}:${challenge}`;
    if (!ed25519Crypto.verify(device.publicKey, message, signature)) {
      throw new Error('Invalid device pairing signature');
    }
    const updated = await prisma.ioTDevice.update({
      where: { deviceId },
      data: { ownerId, status: DeviceStatus.PAIRED, pairedAt: new Date() },
    });

    await auditService.logEvent({
      entityType: 'IoTDevice',
      entityId: updated.id,
      action: 'DEVICE_PAIRED',
      actorDID: ownerId,
      payload: { deviceId, ownerId },
    });

    return updated;
  },

  async ingestData(data: {
    deviceId: string;
    encryptedPayload?: string;
    nonce?: string;
    signature: string;
    payloadType?: string;
    metricName?: string;
    metricValue?: number;
    unit?: string;
    consentId?: string;
  }) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { deviceId: data.deviceId },
    });
    if (device.status !== DeviceStatus.PAIRED && device.status !== DeviceStatus.ACTIVE) {
      throw new Error('Device not paired');
    }

    const telemetry = await prisma.ioTData.create({
      data: {
        deviceId: data.deviceId,
        encryptedPayload: data.encryptedPayload ?? '',
        nonce: data.nonce ?? '',
        signature: data.signature,
        payloadType: data.payloadType ?? 'telemetry',
        metricName: data.metricName,
        metricValue: data.metricValue ?? 0,
        unit: data.unit,
        consentId: data.consentId,
      },
    });

    await prisma.ioTDevice.update({
      where: { deviceId: data.deviceId },
      data: { lastSeenAt: new Date(), status: DeviceStatus.ACTIVE },
    });

    if (data.metricName !== undefined && data.metricValue !== undefined) {
      await this._checkThresholds(device.id, data.metricName, data.metricValue);
    }

    return telemetry;
  },

  async _checkThresholds(deviceId: string, metric: string, value: number) {
    const thresholds = await prisma.ioTThreshold.findMany({
      where: { deviceId, metric, enabled: true },
    });
    for (const t of thresholds) {
      let violated = false;
      if (t.minValue !== null && value < t.minValue) violated = true;
      if (t.maxValue !== null && value > t.maxValue) violated = true;
      if (violated) {
        const alert = await prisma.ioTAlert.create({
          data: {
            deviceId,
            type: 'THRESHOLD_BREACH',
            severity: 'WARNING',
            message: `${metric} = ${value} hors seuil [${t.minValue ?? '-∞'}, ${t.maxValue ?? '+∞'}]`,
            metric,
            value,
            threshold: t.maxValue ?? t.minValue ?? 0,
          },
        });
        broadcastAlert({
          type: 'THRESHOLD_BREACH',
          deviceId, metric, value, min: t.minValue, max: t.maxValue,
          message: `${metric} = ${value} hors seuil [${t.minValue ?? '-∞'}, ${t.maxValue ?? '+∞'}]`,
        });
        await auditService.logEvent({
          entityType: 'IoTAlert',
          entityId: alert.id,
          action: 'THRESHOLD_BREACH',
          payload: { deviceId, metric, value, min: t.minValue, max: t.maxValue },
        });
      }
    }
  },

  async getDevices(ownerId: string) {
    return prisma.ioTDevice.findMany({
      where: { ownerId },
      include: { _count: { select: { data: true, alerts: true } } },
      orderBy: { updatedAt: 'desc' },
    });
  },

  async getDeviceDetail(deviceId: string) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { id: deviceId },
      include: {
        thresholds: true,
        _count: { select: { data: true, alerts: true } },
      },
    });
    const latestData = await prisma.ioTData.findMany({
      where: { deviceId: device.id },
      orderBy: { receivedAt: 'desc' },
      take: 10,
    });
    return { ...device, latestTelemetry: latestData };
  },

  async getTelemetryHistory(deviceId: string, metric?: string, limit = 100) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { id: deviceId },
    });
    const where: Record<string, unknown> = { deviceId: device.id };
    if (metric) where['metricName'] = metric;
    return prisma.ioTData.findMany({
      where: where as any,
      orderBy: { receivedAt: 'desc' },
      take: limit,
    });
  },

  async getAlerts(deviceId: string, unreadOnly = false) {
    const where: Record<string, unknown> = {};
    if (deviceId) where['deviceId'] = deviceId;
    if (unreadOnly) where['read'] = false;
    return prisma.ioTAlert.findMany({
      where: where as any,
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  },

  async markAlertRead(alertId: string) {
    return prisma.ioTAlert.update({
      where: { id: alertId },
      data: { read: true },
    });
  },

  async setThreshold(data: {
    deviceId: string;
    metric: string;
    minValue?: number;
    maxValue?: number;
    enabled?: boolean;
  }) {
    return prisma.ioTThreshold.upsert({
      where: { deviceId_metric: { deviceId: data.deviceId, metric: data.metric } },
      update: {
        minValue: data.minValue,
        maxValue: data.maxValue,
        enabled: data.enabled ?? true,
      },
      create: {
        deviceId: data.deviceId,
        metric: data.metric,
        minValue: data.minValue,
        maxValue: data.maxValue,
        enabled: data.enabled ?? true,
      },
    });
  },

  async updateDeviceName(deviceId: string, name: string) {
    return prisma.ioTDevice.update({
      where: { id: deviceId },
      data: { name },
    });
  },

  async pairDeviceByQr(deviceId: string, ownerId: string, challenge: string, signature: string) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { deviceId },
    });
    if (device.status !== DeviceStatus.PENDING) {
      throw new Error('Device already paired');
    }
    const message = `pair:${deviceId}:${challenge}`;
    if (!ed25519Crypto.verify(device.publicKey, message, signature)) {
      throw new Error('Invalid QR pairing signature');
    }
    const updated = await prisma.ioTDevice.update({
      where: { deviceId },
      data: { ownerId, status: DeviceStatus.PAIRED, pairedAt: new Date() },
    });
    await auditService.logEvent({
      entityType: 'IoTDevice',
      entityId: updated.id,
      action: 'DEVICE_PAIRED_QR',
      actorDID: ownerId,
      payload: { deviceId, ownerId, challenge },
    });
    return updated;
  },

  async unregisterDevice(deviceId: string) {
    const device = await prisma.ioTDevice.update({
      where: { id: deviceId },
      data: { status: DeviceStatus.DISABLED },
    });
    await auditService.logEvent({
      entityType: 'IoTDevice',
      entityId: device.id,
      action: 'DEVICE_UNREGISTERED',
      payload: { deviceId: device.deviceId },
    });
    return device;
  },
};
