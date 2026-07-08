/**
 * Routes du portefeuille DID / Verifiable Credentials.
 *
 * POST /wallet/create         → Crée un DID Document W3C (JWT requis)
 * POST /wallet/rotate-key     → Rotation de clé dans le DID (JWT requis)
 * POST /wallet/add-keyx       → Ajoute une clé d'échange X25519 (JWT requis)
 * POST /wallet/issue-vc       → Émet un VerifiableCredential (JWT requis)
 * POST /wallet/revoke-vc      → Révoque un VC (JWT requis)
 * GET  /wallet/vcs             → Liste des credentials (JWT requis)
 * GET  /wallet/resolve/:did    → Résout un DID (universel)
 * POST /wallet/derive-key      → Dérive une clé de chiffrement wallet
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

  app.post('/wallet/rotate-key', { preHandler: authMiddleware }, async (request, reply) => {
    const { newPublicKey } = request.body as { newPublicKey: string };
    const userId = request.user!.sub;
    const result = await walletService.rotateKey(userId, newPublicKey);
    return reply.send(result);
  });

  app.post('/wallet/add-keyx', { preHandler: authMiddleware }, async (request, reply) => {
    const { x25519PublicKey } = request.body as { x25519PublicKey: string };
    const userId = request.user!.sub;
    const result = await walletService.addKeyAgreementKey(userId, x25519PublicKey);
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

  app.post('/wallet/revoke-vc', { preHandler: authMiddleware }, async (request, reply) => {
    const { vcId } = request.body as { vcId: string };
    const userId = request.user!.sub;
    const result = await walletService.revokeCredential(vcId, userId);
    return reply.send(result);
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

  app.post('/wallet/derive-key', { preHandler: authMiddleware }, async (request, reply) => {
    const { secret } = request.body as { secret: string };
    const npi = request.user!.npi;
    const walletKey = await walletService.deriveWalletKey(npi, secret);
    return reply.send({ walletKey: walletKey.substring(0, 16) + '...' });
  });

  app.post('/wallet/present-vc', { preHandler: authMiddleware }, async (request, reply) => {
    const { vcId, challenge } = request.body as { vcId: string; challenge?: string };
    const userId = request.user!.sub;
    const presentation = await walletService.generatePresentation(vcId, userId, challenge);
    return reply.send(presentation);
  });
}
