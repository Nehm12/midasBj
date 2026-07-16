/**
 * Routes du module d'authentification.
 *
 * GET  /auth/health        → Health check
 * POST /auth/register      → Enrôlement (NPI + clé publique)
 * POST /auth/login         → Connexion (signature Ed25519)
 * POST /auth/login-simple  → Connexion simplifiée (NPI seulement, dev/test)
 * POST /auth/keycloak      → Connexion via Keycloak OIDC
 * GET  /auth/session       → Validation du token JWT
 * POST /auth/rotate-key    → Rotation de clé publique (JWT requis)
 * GET  /auth/roles         → Rôles de l'utilisateur (JWT requis)
 * PUT  /auth/profile       → Mise à jour du profil (JWT requis)
 */
import { FastifyInstance } from 'fastify';
import { authService } from './auth.service.js';
import { authMiddleware } from '../../infrastructure/auth/middleware.js';

export async function authRoutes(app: FastifyInstance) {

  app.get('/auth/health', async () => ({
    status: 'ok',
    service: 'auth',
    timestamp: new Date().toISOString(),
  }));

  app.post('/auth/register', async (request, reply) => {
    const { npi, publicKey, firstName, lastName } = request.body as { npi: string; publicKey: string; firstName?: string; lastName?: string };
    const result = await authService.register({ npi, publicKey, firstName, lastName });
    return reply.code(201).send(result);
  });

  app.post('/auth/login', async (request, reply) => {
    const { npi, signature } = request.body as { npi: string; signature: string };
    const result = await authService.login({ npi, signature });
    return reply.send(result);
  });

  app.post('/auth/login-simple', async (request, reply) => {
    const { npi } = request.body as { npi: string };
    const result = await authService.loginSimple(npi);
    return reply.send(result);
  });

  app.post('/auth/keycloak', async (request, reply) => {
    const { token } = request.body as { token: string };
    const result = await authService.loginWithKeycloak(token);
    return reply.send(result);
  });

  app.get('/auth/session', async (request, reply) => {
    const authHeader = request.headers.authorization?.replace('Bearer ', '');
    if (!authHeader) return reply.code(401).send({ error: 'No token' });
    const session = await authService.validateSession(authHeader);
    return reply.send(session);
  });

  app.post('/auth/rotate-key', { preHandler: authMiddleware }, async (request, reply) => {
    const { newPublicKey } = request.body as { newPublicKey: string };
    const userId = request.user!.sub;
    const result = await authService.rotateKey({ userId, newPublicKey });
    return reply.send(result);
  });

  app.get('/auth/roles', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const roles = await authService.getUserRoles(userId);
    return reply.send({ roles });
  });

  app.put('/auth/profile', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.sub;
    const { firstName, lastName } = request.body as { firstName?: string; lastName?: string };
    const result = await authService.updateProfile({ userId, firstName, lastName });
    return reply.send(result);
  });
}
