/**
 * Middleware d'authentification.
 *
 * Supporte deux modes :
 * 1. JWT classique (signé avec le secret local) - pour l'app mobile
 * 2. Keycloak OIDC (token validé auprès de Keycloak) - pour le SSO
 *
 * Le payload décodé est attaché à request.user avec les rôles.
 */
import { FastifyReply, FastifyRequest } from 'fastify';
import jwt from 'jsonwebtoken';
import config from '../../config/index.js';
import prisma from '../db/client.js';
import { keycloakService } from './keycloak.js';

export interface AuthPayload {
  sub: string;
  did: string;
  npi: string;
  roles: string[];
  provider: 'jwt' | 'keycloak';
}

export async function authMiddleware(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return reply.code(401).send({ error: 'Missing or invalid token' });
  }

  const token = header.replace('Bearer ', '');

  try {
    const payload = jwt.verify(token, config.JWT_SECRET) as jwt.JwtPayload & { roles?: string[] };
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      return reply.code(401).send({ error: 'User not found' });
    }
    request.user = {
      sub: user.id,
      did: user.did,
      npi: user.npi,
      roles: payload.roles ?? ['citizen'],
      provider: 'jwt' as const,
    };
    return;
  } catch {
    // Not a local JWT, try Keycloak
  }

  try {
    const session = await keycloakService.loginWithKeycloak(token);
    request.user = {
      sub: session.id,
      did: session.did,
      npi: session.npi,
      roles: session.roles,
      provider: 'keycloak' as const,
    };
    return;
  } catch {
    return reply.code(401).send({ error: 'Invalid token' });
  }
}

export function requireRole(...roles: string[]) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    await authMiddleware(request, reply);
    if (reply.sent) return;
    const user = request.user;
    if (!user) return reply.code(401).send({ error: 'Not authenticated' });
    const hasRole = roles.some((r) => user.roles.includes(r));
    if (!hasRole) {
      return reply.code(403).send({ error: `Requires one of roles: ${roles.join(', ')}` });
    }
  };
}

export function protectRoute(
  handler: (request: FastifyRequest, reply: FastifyReply) => Promise<unknown>,
) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    await authMiddleware(request, reply);
    if (reply.sent) return;
    return handler(request, reply);
  };
}
