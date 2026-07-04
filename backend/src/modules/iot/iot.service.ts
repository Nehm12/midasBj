/**
 * Service de gestion des appareils IoT.
 *
 * registerDevice → Enregistre un nouvel appareil (via QR code ou API)
 * pairDevice     → Associe un appareil à un utilisateur (propriétaire)
 * ingestData     → Reçoit et stocke les données de télémétrie chiffrées
 * getDevices     → Liste les appareils d'un propriétaire
 *
 * Les données IoT sont chiffrées côté appareil (ChaCha20-Poly1305)
 * et ne peuvent être déchiffrées que par le propriétaire via X25519.
 */
import { DeviceStatus, Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';

export const iotService = {
  async registerDevice(data: {
    deviceId: string;
    publicKey: string;
    attestation: Record<string, unknown>;
  }) {
    return prisma.ioTDevice.create({
      data: {
        deviceId: data.deviceId,
        publicKey: data.publicKey,
        attestation: data.attestation as Prisma.JsonObject,
        status: DeviceStatus.PENDING,
      },
    });
  },

  async pairDevice(deviceId: string, ownerId: string) {
    return prisma.ioTDevice.update({
      where: { deviceId },
      data: {
        ownerId,
        status: DeviceStatus.PAIRED,
        pairedAt: new Date(),
      },
    });
  },

  async ingestData(data: {
    deviceId: string;
    encryptedPayload: string;
    nonce: string;
    signature: string;
    consentId?: string;
  }) {
    const device = await prisma.ioTDevice.findUniqueOrThrow({
      where: { deviceId: data.deviceId },
    });
    if (device.status !== DeviceStatus.PAIRED && device.status !== DeviceStatus.ACTIVE) {
      throw new Error('Device not paired');
    }
    await prisma.ioTDevice.update({
      where: { deviceId: data.deviceId },
      data: { lastSeenAt: new Date(), status: DeviceStatus.ACTIVE },
    });
    return prisma.ioTData.create({
      data: {
        deviceId: data.deviceId,
        encryptedPayload: data.encryptedPayload,
        nonce: data.nonce,
        signature: data.signature,
        consentId: data.consentId,
      },
    });
  },

  async getDevices(ownerId: string) {
    return prisma.ioTDevice.findMany({
      where: { ownerId },
      orderBy: { createdAt: 'desc' },
    });
  },
};
