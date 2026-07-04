/**
 * Routes du module IoT.
 *
 * POST /iot/register → Enregistrement d'un appareil (QR code)
 * POST /iot/pair     → Appairage à un compte citoyen (JWT requis)
 * POST /iot/data     → Réception de données télémétriques chiffrées
 * GET  /iot/devices  → Liste des appareils du citoyen (JWT requis)
 */
import { FastifyInstance } from 'fastify';
import { iotService } from './iot.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function iotRoutes(app: FastifyInstance) {
  app.post('/iot/register', async (request, reply) => {
    const { deviceId, publicKey, attestation } = request.body as {
      deviceId: string;
      publicKey: string;
      attestation: Record<string, unknown>;
    };
    const result = await iotService.registerDevice({
      deviceId,
      publicKey,
      attestation,
    });
    return reply.code(201).send(result);
  });

  app.post('/iot/pair', { preHandler: authMiddleware }, async (request, reply) => {
    const { deviceId } = request.body as { deviceId: string };
    const ownerId = request.user!.sub;
    const result = await iotService.pairDevice(deviceId, ownerId);
    return reply.send(result);
  });

  app.post('/iot/data', async (request, reply) => {
    const { deviceId, encryptedPayload, nonce, signature, consentId } =
      request.body as {
        deviceId: string;
        encryptedPayload: string;
        nonce: string;
        signature: string;
        consentId?: string;
      };
    const result = await iotService.ingestData({
      deviceId,
      encryptedPayload,
      nonce,
      signature,
      consentId,
    });
    return reply.code(201).send(result);
  });

  app.get('/iot/devices', { preHandler: authMiddleware }, async (request, reply) => {
    const ownerId = request.user!.sub;
    const devices = await iotService.getDevices(ownerId);
    return reply.send(devices);
  });
}
