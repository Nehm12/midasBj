/**
 * Service de gestion des consentements.
 *
 * Chaque consentement est lié à un citoyen et un fournisseur de service.
 * Le grant et le revoke sont signés cryptographiquement par le citoyen
 * pour garantir son authenticité.
 *
 * Signature attendue :
 *   grant  : ed25519.sign(`grant:${consentId}:${citizenId}`)
 *   revoke : ed25519.sign(`revoke:${consentId}:${citizenId}`)
 */
import { ConsentStatus } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';

export const consentService = {
  async requestConsent(data: {
    citizenId: string;
    providerDID: string;
    purpose: string;
    dataClasses: string[];
    duration: number;
  }) {
    const previous = await prisma.consent.findFirst({
      where: { citizenId: data.citizenId },
      orderBy: { createdAt: 'desc' },
    });
    const consent = await prisma.consent.create({
      data: {
        citizenId: data.citizenId,
        providerDID: data.providerDID,
        purpose: data.purpose,
        dataClasses: data.dataClasses,
        duration: data.duration,
        previousHash: previous?.id ?? 'genesis',
        signature: '',
        status: ConsentStatus.REQUESTED,
        expiresAt: new Date(Date.now() + data.duration * 1000),
      },
    });
    return consent;
  },

  async grantConsent(consentId: string, publicKey: string, signature: string) {
    const consent = await prisma.consent.findUniqueOrThrow({ where: { id: consentId } });
    const message = `grant:${consentId}:${consent.citizenId}`;
    if (!ed25519Crypto.verify(publicKey, message, signature)) {
      throw new Error('Invalid consent grant signature');
    }
    return prisma.consent.update({
      where: { id: consentId },
      data: { status: ConsentStatus.GRANTED, signature },
    });
  },

  async revokeConsent(consentId: string, publicKey: string, signature: string) {
    const consent = await prisma.consent.findUniqueOrThrow({ where: { id: consentId } });
    const message = `revoke:${consentId}:${consent.citizenId}`;
    if (!ed25519Crypto.verify(publicKey, message, signature)) {
      throw new Error('Invalid consent revoke signature');
    }
    return prisma.consent.update({
      where: { id: consentId },
      data: { status: ConsentStatus.REVOKED, signature },
    });
  },

  async getHistory(userId: string) {
    return prisma.consent.findMany({
      where: { citizenId: userId },
      orderBy: { createdAt: 'desc' },
    });
  },

  async getById(id: string) {
    return prisma.consent.findUniqueOrThrow({ where: { id } });
  },
};
