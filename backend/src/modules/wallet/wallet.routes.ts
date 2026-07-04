/**
 * Routes du portefeuille DID / Verifiable Credentials.
 *
 * POST /wallet/create   → Crée un DID Document W3C pour l'utilisateur
 * POST /wallet/issue-vc → Émet un VerifiableCredential signé
 * GET  /wallet/vcs       → Liste les credentials de l'utilisateur
 * GET  /wallet/resolve/:did → Résout un DID en son document
 *
 * Les routes /create, /issue-vc et /vcs nécessitent un token JWT valide.
 */
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
