/**
 * Module d'administration — Routes protégées pour la console APDP.
 *
 * POST /admin/login          → Connexion admin (mot de passe)
 * GET  /admin/session        → Vérifier la session admin
 * GET  /admin/logs           → Journal des événements serveur (filtrable)
 * GET  /admin/logs/stats     → Statistiques des logs
 * DELETE /admin/logs         → Vider le journal
 * GET  /admin/dashboard      → Données agrégées pour le tableau de bord
 */
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import config from '../../config/index.js';
import prisma from '../../infrastructure/db/client.js';
import { logCollector } from '../../infrastructure/logs/collector.js';
import { auditService } from '../audit/audit.service.js';

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'midas-admin-2024';
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_TOKEN_SECRET = config.JWT_SECRET + ':admin';
const ADMIN_TOKEN_EXPIRY = '12h';

function adminMiddleware(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return reply.code(401).send({ error: 'Token manquant' });
  }
  const token = header.replace('Bearer ', '');
  try {
    const payload = jwt.verify(token, ADMIN_TOKEN_SECRET) as { role: string };
    if (payload.role !== 'admin') {
      return reply.code(403).send({ error: 'Accès réservé aux administrateurs' });
    }
    (request as any).adminUser = payload;
  } catch {
    return reply.code(401).send({ error: 'Token invalide ou expiré' });
  }
}

export async function adminRoutes(app: FastifyInstance) {

  // ── Connexion admin ──
  app.post('/admin/login', async (request, reply) => {
    const { username, password } = request.body as { username: string; password: string };

    logCollector.info('admin', 'Tentative de connexion admin', { username });

    if (username !== ADMIN_USER || password !== ADMIN_PASSWORD) {
      logCollector.warn('auth', 'Échec de connexion admin', { username, ip: request.ip });
      return reply.code(401).send({ error: 'Identifiants incorrects' });
    }

    const token = jwt.sign(
      { role: 'admin', user: username, loginAt: Date.now() },
      ADMIN_TOKEN_SECRET,
      { expiresIn: ADMIN_TOKEN_EXPIRY },
    );

    logCollector.info('auth', 'Connexion admin réussie', { username });
    return reply.send({ token, user: username, expiresIn: ADMIN_TOKEN_EXPIRY });
  });

  // ── Vérifier session admin ──
  app.get('/admin/session', { preHandler: adminMiddleware }, async (request, reply) => {
    const admin = (request as any).adminUser;
    return reply.send({ authenticated: true, user: admin.user, loginAt: admin.loginAt });
  });

  // ── Dashboard agrégé ──
  app.get('/admin/dashboard', { preHandler: adminMiddleware }, async (_request, reply) => {
    try {
      const [auditSearch, violations, entityTypes, logStats, users, consents, iotDevices] = await Promise.all([
        prisma.auditEvent.count().catch(() => 0),
        prisma.auditEvent.findMany({
          where: {
            OR: [
              { action: { contains: 'DENIED' } },
              { action: { contains: 'FAILED' } },
              { action: { contains: 'BREACH' } },
              { action: { contains: 'UNAUTHORIZED' } },
            ],
          },
          select: { id: true },
        }).then(r => r.length).catch(() => 0),
        prisma.auditEvent.groupBy({ by: ['entityType'], _count: { id: true } }).catch(() => []),
        logCollector.getStats(),
        prisma.user.count().catch(() => 0),
        prisma.consent.count().catch(() => 0),
        prisma.ioTDevice.count().catch(() => 0),
      ]);

      const recentEvents = await prisma.auditEvent.findMany({
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: { user: { select: { npi: true, did: true } } },
      }).catch(() => []);

      return reply.send({
        stats: {
          totalAuditEvents: auditSearch,
          totalViolations: violations,
          totalUsers: users,
          totalConsents: consents,
          totalIotDevices: iotDevices,
          entityTypes: entityTypes.map((t: any) => ({ type: t.entityType, count: t._count.id })),
          chainStatus: violations > 0 ? 'alteree' : 'integre',
        },
        logs: logStats,
        recentEvents,
      });
    } catch (err: any) {
      logCollector.error('admin', 'Erreur chargement dashboard', { error: err.message });
      return reply.code(500).send({ error: 'Erreur chargement dashboard' });
    }
  });

  // ── Logs ──
  app.get('/admin/logs', { preHandler: adminMiddleware }, async (request, reply) => {
    const { level, category, from, to, search, limit, offset } = request.query as {
      level?: string; category?: string; from?: string; to?: string;
      search?: string; limit?: string; offset?: string;
    };

    const result = logCollector.getLogs({
      level,
      category,
      from: from ? parseInt(from) : undefined,
      to: to ? parseInt(to) : undefined,
      search,
      limit: limit ? parseInt(limit) : 100,
      offset: offset ? parseInt(offset) : undefined,
    });

    return reply.send(result);
  });

  app.get('/admin/logs/stats', { preHandler: adminMiddleware }, async (_request, reply) => {
    return reply.send(logCollector.getStats());
  });

  app.delete('/admin/logs', { preHandler: adminMiddleware }, async (_request, reply) => {
    logCollector.clear();
    logCollector.info('admin', 'Journal des logs vidé');
    return reply.send({ success: true, message: 'Logs vidé' });
  });

  // ── Routes avancées ──
  app.get('/admin/audit/search', { preHandler: adminMiddleware }, async (request, reply) => {
    const { entityType, action, actorDID, from, to, limit, offset, entityId } = request.query as {
      entityType?: string; action?: string; actorDID?: string; entityId?: string;
      from?: string; to?: string; limit?: string; offset?: string;
    };

    const searchParams: Record<string, unknown> = {
      entityType, action, actorDID, from, to,
      limit: limit ? parseInt(limit) : 100,
      offset: offset ? parseInt(offset) : undefined,
    };

    const result = await (auditService as any).searchEvents(searchParams);

    return reply.send(result);
  });

  app.get('/admin/audit/trail/:entityId', { preHandler: adminMiddleware }, async (request, reply) => {
    const { entityId } = request.params as { entityId: string };
    const trail = await auditService.getTrail(entityId);
    return reply.send(trail);
  });

  app.get('/admin/audit/violations', { preHandler: adminMiddleware }, async (_request, reply) => {
    const violations = await auditService.getViolations();
    return reply.send(violations);
  });

  app.get('/admin/audit/entity-types', { preHandler: adminMiddleware }, async (_request, reply) => {
    const types = await auditService.getEntityTypes();
    return reply.send(types);
  });

  app.post('/admin/audit/verify', { preHandler: adminMiddleware }, async (request, reply) => {
    const { entityId } = request.body as { entityId: string };
    const result = await auditService.verifyChain(entityId);
    return reply.send(result);
  });

  app.get('/admin/audit/export/:entityId', { preHandler: adminMiddleware }, async (request, reply) => {
    const { entityId } = request.params as { entityId: string };
    const proof = await auditService.exportAuditProof(entityId);
    return reply.send(proof);
  });

  app.get('/admin/users', { preHandler: adminMiddleware }, async (_request, reply) => {
    const users = await prisma.user.findMany({
      select: { id: true, npi: true, did: true, publicKey: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    return reply.send(users);
  });

  app.get('/admin/consents', { preHandler: adminMiddleware }, async (_request, reply) => {
    const consents = await prisma.consent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return reply.send(consents);
  });

  app.get('/admin/iot-data', { preHandler: adminMiddleware }, async (_request, reply) => {
    const data = await prisma.ioTData.findMany({
      orderBy: { receivedAt: 'desc' },
      take: 200,
    });
    return reply.send(data);
  });

  app.get('/admin/processing-registers', { preHandler: adminMiddleware }, async (_request, reply) => {
    const registers = await prisma.processingRegister.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return reply.send(registers);
  });
}
