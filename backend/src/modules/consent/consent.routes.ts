import { FastifyInstance } from 'fastify';
import { consentService } from './consent.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function consentRoutes(app: FastifyInstance) {
  app.post('/consent/request', { preHandler: authMiddleware }, async (request, reply) => {
    const { providerDID, purpose, dataClasses, duration } =
      request.body as {
        providerDID: string;
        purpose: string;
        dataClasses: string[];
        duration: number;
      };
    const citizenId = request.user!.sub;
    const result = await consentService.requestConsent({
      citizenId,
      providerDID,
      purpose,
      dataClasses,
      duration,
    });
    return reply.code(201).send(result);
  });

  app.post('/consent/grant', { preHandler: authMiddleware }, async (request, reply) => {
    const { consentId, signature, publicKey } = request.body as {
      consentId: string;
      signature: string;
      publicKey: string;
    };
    const result = await consentService.grantConsent(consentId, publicKey, signature);
    return reply.send(result);
  });

  app.post('/consent/revoke', { preHandler: authMiddleware }, async (request, reply) => {
    const { consentId, signature, publicKey } = request.body as {
      consentId: string;
      signature: string;
      publicKey: string;
    };
    const result = await consentService.revokeConsent(consentId, publicKey, signature);
    return reply.send(result);
  });

  app.get('/consent/history', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const history = await consentService.getHistory(userId);
    return reply.send(history);
  });

  app.get('/consent/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const consent = await consentService.getById(id);
    return reply.send(consent);
  });
}
