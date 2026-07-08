import crypto from 'node:crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';

const SERVER_SIGNING_KEY = process.env.AUDIT_SIGN_KEY || ed25519Crypto.generateKeyPair().privateKey;

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
    userId?: string;
    userSignature?: string;
    userDid?: string;
  }) {
    const previous = await prisma.auditEvent.findFirst({
      where: { entityId: data.entityId },
      orderBy: { createdAt: 'desc' },
    });

    const previousHash = previous?.hash ?? 'genesis';
    const timestamp = Date.now();
    const userPart = data.userSignature ? `|userSig:${data.userSignature}` : '';
    const raw = `${previousHash}|${data.entityType}|${data.entityId}|${data.action}|${JSON.stringify(data.payload ?? {})}|${timestamp}${userPart}`;
    const hash = sha256(raw);
    const signMessage = `audit:${hash}:${data.entityId}:${timestamp}`;
    const signature = ed25519Crypto.sign(SERVER_SIGNING_KEY, signMessage);
    const forDb = ed25519Crypto.sign(SERVER_SIGNING_KEY, hash);

    return prisma.auditEvent.create({
      data: {
        entityType: data.entityType,
        entityId: data.entityId,
        action: data.action,
        actorDID: data.actorDID,
        payload: data.payload as Prisma.InputJsonValue,
        previousHash,
        hash,
        signature: forDb,
        signKey: `<ed25519>${signature.substring(0, 16)}...`,
        userSignature: data.userSignature,
        userDid: data.userDid,
        userId: data.userId,
      },
    });
  },

  async getTrail(entityId: string) {
    return prisma.auditEvent.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });
  },

  async searchEvents(params: {
    entityType?: string;
    action?: string;
    actorDID?: string;
    from?: string;
    to?: string;
    limit?: number;
    offset?: number;
  }) {
    const where: Record<string, unknown> = {};
    if (params.entityType) where['entityType'] = params.entityType;
    if (params.action) where['action'] = params.action;
    if (params.actorDID) where['actorDID'] = params.actorDID;
    if (params.from || params.to) {
      const createdAt: Record<string, unknown> = {};
      if (params.from) createdAt['gte'] = new Date(params.from);
      if (params.to) createdAt['lte'] = new Date(params.to);
      where['createdAt'] = createdAt;
    }

    const [events, total] = await Promise.all([
      prisma.auditEvent.findMany({
        where: where as any,
        orderBy: { createdAt: 'desc' },
        take: params.limit ?? 50,
        skip: params.offset ?? 0,
        include: { user: { select: { npi: true, did: true } } },
      }),
      prisma.auditEvent.count({ where: where as any }),
    ]);
    return { events, total, limit: params.limit ?? 50, offset: params.offset ?? 0 };
  },

  async verifyChain(entityId: string) {
    const events = await prisma.auditEvent.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });
    if (events.length === 0) return { valid: true, events: [] };
    if (events[0].previousHash !== 'genesis') {
      return { valid: false, brokenAt: events[0].id, reason: 'First event previousHash is not genesis' };
    }
    for (let i = 1; i < events.length; i++) {
      const prev = events[i - 1];
      const curr = events[i];
      const userPart = curr.userSignature ? `|userSig:${curr.userSignature}` : '';
      const expected = sha256(
        `${prev.hash}|${curr.entityType}|${curr.entityId}|${curr.action}|${JSON.stringify(curr.payload ?? {})}|${curr.createdAt.getTime()}${userPart}`,
      );
      if (curr.hash !== expected) {
        return { valid: false, brokenAt: curr.id, reason: `Hash mismatch at event ${i}`, index: i };
      }
    }
    return { valid: true, eventCount: events.length, firstEvent: events[0].id, lastEvent: events[events.length - 1].id };
  },

  async getViolations() {
    const events = await prisma.auditEvent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { user: { select: { npi: true, did: true } } },
    });

    const violations = [];
    const verifiedChains = new Map<string, boolean>();

    for (const event of events) {
      if (!verifiedChains.has(event.entityId)) {
        const result = await this.verifyChain(event.entityId);
        verifiedChains.set(event.entityId, result.valid);
      }
      const chainValid = verifiedChains.get(event.entityId);

      const isSuspicious = event.action.includes('ACCESS_DENIED') ||
        event.action.includes('UNAUTHORIZED') ||
        event.action.includes('FAILED_LOGIN');

      if (!chainValid || isSuspicious) {
        violations.push({
          id: event.id,
          entityId: event.entityId,
          entityType: event.entityType,
          action: event.action,
          actorDID: event.actorDID,
          timestamp: event.createdAt,
          reason: !chainValid ? 'hash_chain_broken' : 'suspicious_activity',
          user: event.user,
        });
      }
    }
    return violations;
  },

  async exportAuditProof(entityId: string) {
    const events = await prisma.auditEvent.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });
    const chainResult = await this.verifyChain(entityId);

    return {
      '@context': ['https://www.w3.org/2018/credentials/v1', 'https://schema.org'],
      id: `urn:uuid:${crypto.randomUUID()}`,
      type: 'AuditProof',
      entityId,
      exportedAt: new Date().toISOString(),
      chainValid: chainResult.valid,
      eventCount: events.length,
      events: events.map(e => ({
        id: e.id,
        action: e.action,
        actorDID: e.actorDID,
        previousHash: e.previousHash,
        hash: e.hash,
        signature: e.signature,
        userSignature: e.userSignature,
        userDid: e.userDid,
        timestamp: e.createdAt,
      })),
      proof: {
        type: 'SHA256HashChain',
        created: new Date().toISOString(),
        proofPurpose: 'auditVerification',
        verificationMethod: 'did:midas:benin:audit-server',
        chainAnchor: events.length > 0 ? events[events.length - 1].hash : 'genesis',
      },
    };
  },

  async getEntityTypes() {
    const result = await prisma.auditEvent.groupBy({
      by: ['entityType'],
      _count: { id: true },
    });
    return result.map(r => ({ type: r.entityType, count: r._count.id }));
  },
};
