/**
 * Regroupement de toutes les routes API.
 *
 * Enregistre chaque module (auth, wallet, consent, iot, audit,
 * processing-register) sous le préfixe /api/v1 défini dans index.ts.
 */
import { FastifyInstance } from 'fastify';
import { authRoutes } from '../../modules/auth/auth.routes.js';
import { walletRoutes } from '../../modules/wallet/wallet.routes.js';
import { consentRoutes } from '../../modules/consent/consent.routes.js';
import { iotRoutes } from '../../modules/iot/iot.routes.js';
import { auditRoutes } from '../../modules/audit/audit.routes.js';
import { processingRegisterRoutes } from '../../modules/processing-register/processing-register.routes.js';
import { adminRoutes } from '../../modules/admin/admin.routes.js';

export async function apiRoutes(app: FastifyInstance) {
  await app.register(authRoutes);
  await app.register(walletRoutes);
  await app.register(consentRoutes);
  await app.register(iotRoutes);
  await app.register(auditRoutes);
  await app.register(processingRegisterRoutes);
  await app.register(adminRoutes);

  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));
}
