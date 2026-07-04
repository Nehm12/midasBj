/**
 * Routes du registre des traitements (conformité RGPD).
 *
 * POST /processing-register     → Déclarer un traitement (JWT requis)
 * GET  /processing-register      → Liste de tous les traitements
 * GET  /processing-register/:id  → Détail d'un traitement
 */
import { FastifyInstance } from 'fastify';
import { processingRegisterService } from './processing-register.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function processingRegisterRoutes(app: FastifyInstance) {
  app.post(
    '/processing-register',
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { controller, purpose, dataClasses, retention, legalBasis } =
        request.body as {
          controller: string;
          purpose: string;
          dataClasses: string[];
          retention: number;
          legalBasis: string;
        };
      const result = await processingRegisterService.register({
        controller,
        purpose,
        dataClasses,
        retention,
        legalBasis,
      });
      return reply.code(201).send(result);
    },
  );

  app.get('/processing-register', async (request, reply) => {
    const entries = await processingRegisterService.list();
    return reply.send(entries);
  });

  app.get('/processing-register/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const entry = await processingRegisterService.getById(id);
    return reply.send(entry);
  });
}
