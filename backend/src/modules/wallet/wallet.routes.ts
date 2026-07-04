import { FastifyInstance } from 'fastify';
import { walletService } from './wallet.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function walletRoutes(app: FastifyInstance) {
  app.post('/wallet/create', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const result = await walletService.createWallet(userId);
    return reply.code(201).send(result);
  });

  app.post('/wallet/issue-vc', { preHandler: authMiddleware }, async (request, reply) => {
    const { type, issuer, issuerPrivateKey } = request.body as {
      type: string; issuer: string; issuerPrivateKey: string;
    };
    const userId = request.user!.sub;
    const result = await walletService.issueCredential({ userId, type, issuer, issuerPrivateKey });
    return reply.code(201).send(result);
  });

  app.get('/wallet/vcs', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const vcs = await walletService.getCredentials(userId);
    return reply.send(vcs);
  });

  app.get('/wallet/resolve/:did', async (request, reply) => {
    const { did } = request.params as { did: string };
    const doc = await walletService.resolveDID(did);
    return reply.send(doc);
  });
}
