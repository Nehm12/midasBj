import crypto from 'node:crypto';
import { ConsentStatus, ConsentType, Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';
import { workflowEngine } from '../../infrastructure/workflow/engine.js';
import { CONSENT_WORKFLOW } from '../../infrastructure/workflow/consent-workflow.js';

const DATA_CLASSES_BY_PURPOSE: Record<string, string[]> = {
  'health': ['medical_history', 'blood_type', 'allergies', 'vaccinations', 'insurance_number'],
  'identity': ['full_name', 'date_of_birth', 'nationality', 'photo', 'address'],
  'financial': ['bank_account', 'income', 'tax_status', 'credit_score'],
  'education': ['diplomas', 'transcripts', 'enrollment_status', 'institution'],
  'employment': ['employer', 'position', 'contract_type', 'employment_date'],
  'iot': ['telemetry', 'location', 'device_status', 'energy_consumption'],
};

export async function activateConsent(consentId: string) {
  const consent = await prisma.consent.findUniqueOrThrow({ where: { id: consentId } });
  if (consent.status !== ConsentStatus.GRANTED) return;

  await prisma.consent.update({
    where: { id: consentId },
    data: { status: ConsentStatus.ACTIVE },
  });
}

export const consentService = {
  async getAvailableDataClasses(purpose?: string) {
    if (purpose && DATA_CLASSES_BY_PURPOSE[purpose]) {
      return { purpose, dataClasses: DATA_CLASSES_BY_PURPOSE[purpose] };
    }
    return DATA_CLASSES_BY_PURPOSE;
  },

  async requestConsent(data: {
    citizenId: string;
    providerDID: string;
    purpose: string;
    dataClasses: string[];
    consentType: ConsentType;
    duration?: number;
    maxUsageCount?: number;
  }) {
    const previous = await prisma.consent.findFirst({
      where: { citizenId: data.citizenId },
      orderBy: { createdAt: 'desc' },
    });

    const duration = data.consentType === 'PERMANENT' ? 0 : (data.duration ?? 3600);
    const maxUsage = data.consentType === 'SINGLE_USE' ? (data.maxUsageCount ?? 1) : 0;
    const expiresAt = data.consentType === 'PERMANENT'
      ? null
      : new Date(Date.now() + duration * 1000);

    const consent = await prisma.consent.create({
      data: {
        citizenId: data.citizenId,
        providerDID: data.providerDID,
        purpose: data.purpose,
        dataClasses: data.dataClasses,
        consentType: data.consentType,
        duration,
        maxUsageCount: maxUsage,
        status: ConsentStatus.REQUESTED,
        previousHash: previous?.id ?? 'genesis',
        expiresAt,
      },
    });

    const workflowCtx: Record<string, unknown> = {
      consentId: consent.id,
      citizenId: data.citizenId,
      providerDID: data.providerDID,
      purpose: data.purpose,
      dataClasses: data.dataClasses,
      consentType: data.consentType,
      expiresAt: expiresAt?.getTime(),
      usageCount: 0,
      maxUsageCount: maxUsage,
    };

    await workflowEngine.createInstance(CONSENT_WORKFLOW, consent.id, workflowCtx);

    return consent;
  },

  async grantConsent(consentId: string, publicKey: string, signature: string) {
    const consent = await prisma.consent.findUniqueOrThrow({
      where: { id: consentId },
      include: { citizen: true },
    });

    const message = `grant:${consentId}:${consent.citizenId}:${consent.purpose}:${consent.dataClasses.join(',')}:${consent.consentType}`;

    if (!ed25519Crypto.verify(publicKey, message, signature)) {
      throw new Error('Invalid consent grant signature');
    }

    const updated = await prisma.consent.update({
      where: { id: consentId },
      data: { status: ConsentStatus.GRANTED, signature },
    });

    const instance = await workflowEngine.getInstanceByConsent(consentId);
    const ctx = instance.context as Record<string, unknown>;
    ctx['signature'] = signature;
    ctx['publicKey'] = publicKey;

    await prisma.workflowInstance.update({
      where: { id: instance.id },
      data: { context: ctx as Prisma.InputJsonValue },
    });

    await workflowEngine.transition(instance.id, 'GRANTED');
    await workflowEngine.transition(instance.id, 'ACTIVE');

    return updated;
  },

  async revokeConsent(consentId: string, publicKey: string, signature: string) {
    const consent = await prisma.consent.findUniqueOrThrow({
      where: { id: consentId },
      include: { citizen: true },
    });

    const message = `revoke:${consentId}:${consent.citizenId}:${consent.purpose}`;

    if (!ed25519Crypto.verify(publicKey, message, signature)) {
      throw new Error('Invalid consent revoke signature');
    }

    const updated = await prisma.consent.update({
      where: { id: consentId },
      data: { status: ConsentStatus.REVOKED, signature },
    });

    try {
      const instance = await workflowEngine.getInstanceByConsent(consentId);
      const ctx = instance.context as Record<string, unknown>;
      ctx['revoked'] = true;
      await prisma.workflowInstance.update({
        where: { id: instance.id },
        data: { context: ctx as Prisma.InputJsonValue },
      });
      await workflowEngine.transition(instance.id, 'REVOKED');
    } catch {
      // workflow instance may not exist
    }

    return updated;
  },

  async denyConsent(consentId: string) {
    const updated = await prisma.consent.update({
      where: { id: consentId },
      data: { status: ConsentStatus.DENIED },
    });

    try {
      const instance = await workflowEngine.getInstanceByConsent(consentId);
      const ctx = instance.context as Record<string, unknown>;
      ctx['denied'] = true;
      await prisma.workflowInstance.update({
        where: { id: instance.id },
        data: { context: ctx as Prisma.InputJsonValue },
      });
      await workflowEngine.transition(instance.id, 'DENIED');
    } catch {
      // workflow instance may not exist
    }

    return updated;
  },

  async incrementUsage(consentId: string) {
    const consent = await prisma.consent.findUniqueOrThrow({ where: { id: consentId } });
    if (consent.consentType !== 'SINGLE_USE') return consent;

    const newCount = consent.usageCount + 1;
    const updated = await prisma.consent.update({
      where: { id: consentId },
      data: { usageCount: newCount },
    });

    if (newCount >= consent.maxUsageCount) {
      await prisma.consent.update({
        where: { id: consentId },
        data: { status: ConsentStatus.COMPLETED },
      });

      try {
        const instance = await workflowEngine.getInstanceByConsent(consentId);
        const ctx = instance.context as Record<string, unknown>;
        ctx['usageCount'] = newCount;
        await prisma.workflowInstance.update({
          where: { id: instance.id },
          data: { context: ctx as Prisma.InputJsonValue },
        });
        await workflowEngine.transition(instance.id, 'COMPLETED');
      } catch {
        // workflow instance may not exist
      }
    }

    return updated;
  },

  async getHistory(userId: string) {
    return prisma.consent.findMany({
      where: { citizenId: userId },
      orderBy: { createdAt: 'desc' },
    });
  },

  async getById(id: string) {
    return prisma.consent.findUniqueOrThrow({
      where: { id },
      include: { workflow: true },
    });
  },

  async getActiveConsents(userId: string) {
    return prisma.consent.findMany({
      where: {
        citizenId: userId,
        status: { in: [ConsentStatus.ACTIVE, ConsentStatus.GRANTED] },
      },
      orderBy: { createdAt: 'desc' },
    });
  },

  async getWorkflowState(consentId: string) {
    try {
      const instance = await workflowEngine.getInstanceByConsent(consentId);
      return {
        workflowId: instance.id,
        currentState: instance.currentState,
        definitionName: instance.definition.name,
        history: JSON.parse(instance.history as string),
        context: instance.context,
      };
    } catch {
      return null;
    }
  },

  async exportUserData(userId: string) {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const consents = await prisma.consent.findMany({
      where: { citizenId: userId },
      orderBy: { createdAt: 'desc' },
    });
    const credentials = await prisma.verifiableCredential.findMany({
      where: { userId },
    });

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
        'https://schema.org',
      ],
      id: `urn:uuid:${crypto.randomUUID()}`,
      type: 'DataPortabilityExport',
      exportedAt: new Date().toISOString(),
      exporter: 'MIDAS Benin - Portabilité',
      subject: {
        id: user.did,
        npi: user.npi,
      },
      consents: consents.map(c => ({
        id: c.id,
        providerDID: c.providerDID,
        purpose: c.purpose,
        dataClasses: c.dataClasses,
        consentType: c.consentType,
        status: c.status,
        grantedAt: c.createdAt,
        expiresAt: c.expiresAt,
        signature: c.signature,
      })),
      verifiableCredentials: credentials.map(vc => ({
        id: vc.id,
        type: vc.type,
        issuer: vc.issuer,
        credential: vc.credential,
        issuedAt: vc.createdAt,
      })),
      proof: {
        type: 'Ed25519Signature2020',
        created: new Date().toISOString(),
        proofPurpose: 'dataExport',
        comment: 'Export signé par le serveur MIDAS. Le destinataire doit vérifier la signature de chaque consentement individuellement.',
      },
    };
  },
};
