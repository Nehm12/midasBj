import { FastifyInstance } from 'fastify';
import { ConsentType } from '@prisma/client';
import { consentService } from './consent.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function consentRoutes(app: FastifyInstance) {
  app.post('/consent/request', { preHandler: authMiddleware }, async (request, reply) => {
    const {
      providerDID,
      providerDomain,
      purpose,
      dataClasses,
      consentType,
      duration,
      maxUsageCount,
    } = request.body as {
      providerDID?: string;
      providerDomain?: string;
      purpose: string;
      dataClasses?: string[];
      consentType?: ConsentType;
      duration?: number;
      maxUsageCount?: number;
    };
    const citizenId = request.user!.sub;
    const result = await consentService.requestConsent({
      citizenId,
      providerDID: providerDID ?? '',
      providerDomain: providerDomain ?? null,
      purpose,
      dataClasses: dataClasses ?? [],
      consentType: consentType ?? ConsentType.TEMPORARY,
      duration,
      maxUsageCount,
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

  app.post('/consent/deny', { preHandler: authMiddleware }, async (request, reply) => {
    const { consentId } = request.body as { consentId: string };
    const result = await consentService.denyConsent(consentId);
    return reply.send(result);
  });

  app.get('/consent/history', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const history = await consentService.getHistory(userId);
    return reply.send(history);
  });

  app.get('/consent/active', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const consents = await consentService.getActiveConsents(userId);
    return reply.send(consents);
  });

  app.get('/consent/data-classes', async (request, reply) => {
    const { purpose } = request.query as { purpose?: string };
    const result = await consentService.getAvailableDataClasses(purpose);
    return reply.send(result);
  });

  app.get('/consent/workflow/:id', { preHandler: authMiddleware }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const result = await consentService.getWorkflowState(id);
    return reply.send(result ?? { error: 'No workflow instance found' });
  });

  app.get('/consent/export', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const exportData = await consentService.exportUserData(userId);
    return reply
      .header('Content-Type', 'application/ld+json')
      .header('Content-Disposition', `attachment; filename="midas-export-${userId.substring(0, 8)}.jsonld"`)
      .send(exportData);
  });

  app.get('/consent/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const consent = await consentService.getById(id);
    return reply.send(consent);
  });
}
