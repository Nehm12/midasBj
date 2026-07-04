/**
 * Service de journal d'audit chaîné cryptographiquement.
 *
 * Chaque événement est lié au précédent par un hash SHA-256,
 * formant une chaîne de confiance. Si un événement est modifié,
 * tous les hash suivants deviennent invalides.
 *
 * Structure de la chaîne :
 *   hash = SHA256(previousHash | entityType | entityId | action | payload | timestamp)
 *
 * Le premier événement d'une entité a previousHash = "genesis".
 */
import crypto from 'node:crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';

function sha256(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

export const auditService = {
  async logEvent(data: {
    entityType: string;
    entityId: string;
    action: string;
    actorDID?: string;
    payload?: Record<string, unknown>;
  }) {
    const previous = await prisma.auditEvent.findFirst({
      where: { entityId: data.entityId },
      orderBy: { createdAt: 'desc' },
    });
    const previousHash = previous?.hash ?? 'genesis';
    const raw = `${previousHash}|${data.entityType}|${data.entityId}|${data.action}|${JSON.stringify(data.payload ?? {})}|${Date.now()}`;
    const hash = sha256(raw);
    return prisma.auditEvent.create({
      data: {
        entityType: data.entityType,
        entityId: data.entityId,
        action: data.action,
        actorDID: data.actorDID,
        payload: data.payload as Prisma.JsonObject,
        previousHash,
        hash,
        signature: `sig:${hash}`,
      },
    });
  },

  async getTrail(entityId: string) {
    return prisma.auditEvent.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });
  },

  async verifyChain(entityId: string) {
    const events = await prisma.auditEvent.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });
    if (events.length === 0) return true;
    if (events[0].previousHash !== 'genesis') return false;
    for (let i = 1; i < events.length; i++) {
      const expected = sha256(
        `${events[i - 1].hash}|${events[i].entityType}|${events[i].entityId}|${events[i].action}|${JSON.stringify(events[i].payload ?? {})}|${events[i].createdAt.getTime()}`,
      );
      if (events[i].hash !== expected) return false;
    }
    return true;
  },

  async getViolations() {
    const all = await prisma.auditEvent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    const violations = [];
    for (const event of all) {
      const chain = await this.verifyChain(event.entityId);
      if (!chain) {
        violations.push({
          eventId: event.id,
          entityId: event.entityId,
          reason: 'hash_chain_broken',
          detectedAt: new Date(),
        });
      }
    }
    return violations;
  },
};
