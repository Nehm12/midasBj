/**
 * Routes du journal d'audit.
 *
 * POST /audit/event          → Enregistre un événement dans la chaîne
 * GET  /audit/trail/:entityId → Récupère la piste d'audit complète
 * POST /audit/verify         → Vérifie l'intégrité de la chaîne
 * GET  /audit/violations     → Liste les violations détectées
 */
import { FastifyInstance } from 'fastify';
import { auditService } from './audit.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function auditRoutes(app: FastifyInstance) {
  app.post('/audit/event', { preHandler: authMiddleware }, async (request, reply) => {
    const { entityType, entityId, action, actorDID, payload } =
      request.body as {
        entityType: string;
        entityId: string;
        action: string;
        actorDID?: string;
        payload?: Record<string, unknown>;
      };
    const result = await auditService.logEvent({
      entityType,
      entityId,
      action,
      actorDID,
      payload,
    });
    return reply.code(201).send(result);
  });

  app.get('/audit/trail/:entityId', async (request, reply) => {
    const { entityId } = request.params as { entityId: string };
    const trail = await auditService.getTrail(entityId);
    return reply.send(trail);
  });

  app.post('/audit/verify', async (request, reply) => {
    const { entityId } = request.body as { entityId: string };
    const valid = await auditService.verifyChain(entityId);
    return reply.send({ valid });
  });

  app.get('/audit/violations', async (request, reply) => {
    const violations = await auditService.getViolations();
    return reply.send(violations);
  });
}
