/**
 * Service de portefeuille DID (Decentralized Identifier).
 *
 * createWallet   → Construit un DID Document conforme W3C avec la clé publique
 * issueCredential → Émet un VerifiableCredential signé par l'émetteur
 * getCredentials  → Liste les credentials d'un utilisateur
 * resolveDID      → Résout un DID en son document
 *
 * Le DID Document suit le standard https://www.w3.org/TR/did-core/
 */
import crypto from 'node:crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';

export const walletService = {
  async createWallet(userId: string) {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const didDoc = {
      '@context': ['https://www.w3.org/ns/did/v1'],
      id: user.did,
      verificationMethod: [
        {
          id: `${user.did}#keys-1`,
          type: 'Ed25519VerificationKey2020',
          controller: user.did,
          publicKeyMultibase: user.publicKey,
        },
      ],
      authentication: [`${user.did}#keys-1`],
      service: [
        {
          id: `${user.did}#midas-agent`,
          type: 'MidasAgentService',
          serviceEndpoint: 'https://api.midas-benin.bj/wallet',
        },
      ],
    };
    return { did: user.did, didDoc };
  },

  async issueCredential({
    userId,
    type,
    issuer,
    issuerPrivateKey,
  }: {
    userId: string;
    type: string;
    issuer: string;
    issuerPrivateKey: string;
  }) {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const credential = {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      id: `urn:uuid:${crypto.randomUUID()}`,
      type: ['VerifiableCredential', type],
      issuer,
      issuanceDate: new Date().toISOString(),
      credentialSubject: {
        id: user.did,
        npi: user.npi,
      },
    };
    const signedData = JSON.stringify(credential);
    const signature = ed25519Crypto.sign(issuerPrivateKey, signedData);
    const vc = await prisma.verifiableCredential.create({
      data: {
        userId,
        type,
        issuer,
        credential: credential as unknown as Prisma.InputJsonValue,
        signature,
      },
    });
    return { ...vc, credential };
  },

  async getCredentials(userId: string) {
    return prisma.verifiableCredential.findMany({ where: { userId } });
  },

  async resolveDID(did: string) {
    const user = await prisma.user.findUniqueOrThrow({ where: { did } });
    return {
      '@context': ['https://www.w3.org/ns/did/v1'],
      id: user.did,
      verificationMethod: [
        {
          id: `${user.did}#keys-1`,
          type: 'Ed25519VerificationKey2020',
          controller: user.did,
          publicKeyMultibase: user.publicKey,
        },
      ],
    };
  },
};
