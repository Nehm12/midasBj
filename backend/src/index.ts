/**
 * Point d'entrée du serveur MIDAS-Bénin.
 *
 * Initialise Fastify avec les plugins de sécurité (CORS, Helmet, rate-limit),
 * documente l'API avec Swagger, monte toutes les routes sous /api/v1,
 * démarre le broker MQTT pour l'IoT, puis écoute sur le port configuré.
 */
import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import fastifyStatic from '@fastify/static';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import config from './config/index.js';
import { apiRoutes } from './api/routes/index.js';
import { startMqttBroker } from './infrastructure/mqtt/broker.js';
import { registerWebSocketRoutes } from './infrastructure/ws/alerts.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  const app = Fastify({ logger: { level: config.LOG_LEVEL } });

  // --- Plugins de sécurité et utilitaires ---
  await app.register(cors, { origin: true });
  await app.register(helmet);
  await app.register(rateLimit, { max: 100, timeWindow: '1 minute' });

  // --- WebSocket pour alertes temps réel ---
  await app.register(fastifyWebsocket);
  await registerWebSocketRoutes(app);

  // --- Documentation Swagger disponible sur /docs ---
  await app.register(swagger, {
    openapi: {
      info: {
        title: 'MIDAS-Bénin API',
        description: 'Master Identity and Data Access System',
        version: '0.1.0',
      },
      servers: [{ url: `http://localhost:${config.PORT}` }],
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  // --- Console APDP (interface web d'administration) ---
  await app.register(fastifyStatic, {
    root: join(__dirname, '..', 'web'),
    prefix: '/console/',
    index: ['index.html'],
    decorateReply: true,
  });

  // --- GET API Console ---
  app.get('/console', async (_req, reply) => reply.redirect('/console/'));

  // --- Health check racine (pour Render / load balancers) ---
  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));
  app.get('/', async () => ({ status: 'ok', service: 'midas-benin-backend' }));

  // --- Enregistrement de toutes les routes métier ---
  await app.register(apiRoutes, { prefix: '/api/v1' });

  // --- Broker MQTT pour la communication avec les appareils IoT ---
  await startMqttBroker(app);

  // --- Gestion centralisée des erreurs ---
  app.setErrorHandler((error, _request, reply) => {
    app.log.error(error);

    const prismaCode = (error as any).code;
    if (prismaCode === 'P2025') {
      return reply.status(404).send({ error: 'Ressource non trouvée', statusCode: 404 });
    }
    if (prismaCode === 'P2002') {
      return reply.status(409).send({ error: 'Cette ressource existe déjà', statusCode: 409 });
    }

    reply.status(error.statusCode ?? 500).send({
      error: error.message ?? 'Internal Server Error',
      statusCode: error.statusCode ?? 500,
    });
  });

  // --- Démarrage du serveur HTTP ---
  try {
    await app.listen({ port: config.PORT, host: config.HOST });
    app.log.info(`MIDAS-Bénin backend running on port ${config.PORT}`);
  } catch (err) {
    app.log.fatal(err);
    process.exit(1);
  }
}

main();
