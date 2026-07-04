import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import config from './config/index.js';
import { apiRoutes } from './api/routes/index.js';
import { startMqttBroker } from './infrastructure/mqtt/broker.js';

async function main() {
  const app = Fastify({ logger: { level: config.LOG_LEVEL } });

  await app.register(cors, { origin: true });
  await app.register(helmet);
  await app.register(rateLimit, { max: 100, timeWindow: '1 minute' });
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
  await app.register(apiRoutes, { prefix: '/api/v1' });

  await startMqttBroker(app);

  app.setErrorHandler((error, _request, reply) => {
    app.log.error(error);
    reply.status(error.statusCode ?? 500).send({
      error: error.message ?? 'Internal Server Error',
      statusCode: error.statusCode ?? 500,
    });
  });

  try {
    await app.listen({ port: config.PORT, host: config.HOST });
    app.log.info(`MIDAS-Bénin backend running on port ${config.PORT}`);
  } catch (err) {
    app.log.fatal(err);
    process.exit(1);
  }
}

main();
