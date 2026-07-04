import 'fastify';
import { AuthPayload } from './middleware.js';

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthPayload;
  }
}
