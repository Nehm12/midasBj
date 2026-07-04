import { FastifyInstance } from 'fastify';
import { authService } from './auth.service.js';

export async function authRoutes(app: FastifyInstance) {
  app.post('/auth/register', async (request, reply) => {
    const { npi, publicKey } = request.body as { npi: string; publicKey: string };
    const result = await authService.register({ npi, publicKey });
    return reply.code(201).send(result);
  });

  app.post('/auth/login', async (request, reply) => {
    const { npi, signature } = request.body as { npi: string; signature: string };
    const result = await authService.login({ npi, signature });
    return reply.send(result);
  });

  app.get('/auth/session', async (request, reply) => {
    const token = request.headers.authorization?.replace('Bearer ', '');
    if (!token) return reply.code(401).send({ error: 'No token' });
    const session = await authService.validateSession(token);
    return reply.send(session);
  });
}
