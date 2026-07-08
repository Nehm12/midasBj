import { FastifyInstance } from 'fastify';
import { auditService } from './audit.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function auditRoutes(app: FastifyInstance) {
  app.post('/audit/event', { preHandler: authMiddleware }, async (request, reply) => {
    const { entityType, entityId, action, actorDID, payload, userSignature } = request.body as {
      entityType: string; entityId: string; action: string;
      actorDID?: string; payload?: Record<string, unknown>;
      userSignature?: string;
    };
    const userId = request.user?.sub;
    const userDid = request.user?.did;
    const result = await auditService.logEvent({
      entityType, entityId, action, actorDID, payload, userId, userSignature, userDid,
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
    const result = await auditService.verifyChain(entityId);
    return reply.send(result);
  });

  app.get('/audit/violations', async (request, reply) => {
    const violations = await auditService.getViolations();
    return reply.send(violations);
  });

  app.get('/audit/search', async (request, reply) => {
    const { entityType, action, actorDID, from, to, limit, offset } = request.query as {
      entityType?: string; action?: string; actorDID?: string;
      from?: string; to?: string; limit?: string; offset?: string;
    };
    const result = await auditService.searchEvents({
      entityType, action, actorDID, from, to,
      limit: limit ? parseInt(limit) : undefined,
      offset: offset ? parseInt(offset) : undefined,
    });
    return reply.send(result);
  });

  app.get('/audit/export/:entityId', async (request, reply) => {
    const { entityId } = request.params as { entityId: string };
    const proof = await auditService.exportAuditProof(entityId);
    return reply
      .header('Content-Type', 'application/ld+json')
      .header('Content-Disposition', `attachment; filename="audit-proof-${entityId.substring(0, 8)}.jsonld"`)
      .send(proof);
  });

  app.get('/audit/entity-types', async (request, reply) => {
    const types = await auditService.getEntityTypes();
    return reply.send(types);
  });
}
