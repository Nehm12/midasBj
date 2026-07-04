import { FastifyReply, FastifyRequest } from 'fastify';
import jwt from 'jsonwebtoken';
import config from '../../config/index.js';
import prisma from '../db/client.js';

export interface AuthPayload {
  sub: string;
  did: string;
  npi: string;
}

export async function authMiddleware(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return reply.code(401).send({ error: 'Missing or invalid token' });
  }
  try {
    const token = header.replace('Bearer ', '');
    const payload = jwt.verify(token, config.JWT_SECRET) as AuthPayload;
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      return reply.code(401).send({ error: 'User not found' });
    }
    (request as any).user = payload;
  } catch {
    return reply.code(401).send({ error: 'Invalid token' });
  }
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
