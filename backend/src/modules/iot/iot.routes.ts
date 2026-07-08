import { FastifyInstance } from 'fastify';
import { iotService } from './iot.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function iotRoutes(app: FastifyInstance) {
  app.post('/iot/register', async (request, reply) => {
    const { deviceId, name, publicKey, attestation } = request.body as {
      deviceId: string; name?: string; publicKey: string; attestation: Record<string, unknown>;
    };
    const result = await iotService.registerDevice({ deviceId, name, publicKey, attestation });
    return reply.code(201).send(result);
  });

  app.get('/iot/pair-challenge/:deviceId', async (request, reply) => {
    const { deviceId } = request.params as { deviceId: string };
    const challenge = await iotService.generatePairingChallenge(deviceId);
    return reply.send(challenge);
  });

  app.post('/iot/pair', { preHandler: authMiddleware }, async (request, reply) => {
    const { deviceId, signature, challenge } = request.body as {
      deviceId: string; signature: string; challenge: string;
    };
    const ownerId = request.user!.sub;
    const result = await iotService.pairDevice(deviceId, ownerId, signature, challenge);
    return reply.send(result);
  });

  app.post('/iot/pair-qr', { preHandler: authMiddleware }, async (request, reply) => {
    const { deviceId, challenge, signature } = request.body as {
      deviceId: string; challenge: string; signature: string;
    };
    const ownerId = request.user!.sub;
    const result = await iotService.pairDeviceByQr(deviceId, ownerId, challenge, signature);
    return reply.send(result);
  });

  app.post('/iot/data', async (request, reply) => {
    const { deviceId, encryptedPayload, nonce, signature, payloadType, metricName, metricValue, unit, consentId } =
      request.body as {
        deviceId: string; encryptedPayload?: string; nonce?: string; signature: string;
        payloadType?: string; metricName?: string; metricValue?: number; unit?: string; consentId?: string;
      };
    const result = await iotService.ingestData({
      deviceId, encryptedPayload, nonce, signature, payloadType, metricName, metricValue, unit, consentId,
    });
    return reply.code(201).send(result);
  });

  app.get('/iot/devices', { preHandler: authMiddleware }, async (request, reply) => {
    const ownerId = request.user!.sub;
    const devices = await iotService.getDevices(ownerId);
    return reply.send(devices);
  });

  app.get('/iot/devices/:id', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const detail = await iotService.getDeviceDetail(id);
    return reply.send(detail);
  });

  app.get('/iot/devices/:id/telemetry', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { metric, limit } = request.query as { metric?: string; limit?: string };
    const history = await iotService.getTelemetryHistory(id, metric, limit ? parseInt(limit) : 100);
    return reply.send(history);
  });

  app.get('/iot/devices/:id/alerts', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { unread } = request.query as { unread?: string };
    const alerts = await iotService.getAlerts(id, unread === 'true');
    return reply.send(alerts);
  });

  app.post('/iot/alerts/:id/read', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const result = await iotService.markAlertRead(id);
    return reply.send(result);
  });

  app.post('/iot/thresholds', { preHandler: authMiddleware }, async (request, reply) => {
    const { deviceId, metric, minValue, maxValue, enabled } = request.body as {
      deviceId: string; metric: string; minValue?: number; maxValue?: number; enabled?: boolean;
    };
    const result = await iotService.setThreshold({ deviceId, metric, minValue, maxValue, enabled });
    return reply.send(result);
  });

  app.put('/iot/devices/:id/name', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { name } = request.body as { name: string };
    const result = await iotService.updateDeviceName(id, name);
    return reply.send(result);
  });

  app.post('/iot/unregister', { preHandler: authMiddleware }, async (request, reply) => {
    const { deviceId } = request.body as { deviceId: string };
    const result = await iotService.unregisterDevice(deviceId);
    return reply.send(result);
  });

  app.get('/iot/alerts', { preHandler: authMiddleware }, async (request, reply) => {
    const { unread } = request.query as { unread?: string };
    const alerts = await iotService.getAlerts('', unread === 'true');
    return reply.send(alerts);
  });
}
