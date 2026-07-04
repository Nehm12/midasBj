/**
 * Extension du type FastifyRequest pour inclure les données d'authentification.
 */
import 'fastify';

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      sub: string;
      did: string;
      npi: string;
    };
  }
}
