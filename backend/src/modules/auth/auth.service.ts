/**
 * Service d'authentification.
 *
 * Fonctionnalités :
 * - Enrôlement NPI + clé publique Ed25519
 * - Connexion par signature Ed25519
 * - Connexion simplifiée (NPI seulement, pour développement/test)
 * - Connexion via Keycloak OIDC
 * - Rotation de clé publique
 * - Synchronisation des comptes Keycloak
 */
import prisma from '../../infrastructure/db/client.js';
import config from '../../config/index.js';
import jwt from 'jsonwebtoken';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';
import { keycloakService } from '../../infrastructure/auth/keycloak.js';

export const authService = {

  async register({ npi, publicKey, firstName, lastName }: { npi: string; publicKey: string; firstName?: string; lastName?: string }) {
    const did = `did:midas:benin:${npi}`;
    const existing = await prisma.user.findUnique({ where: { npi } });
    if (existing) {
      const err = new Error('Ce NPI est déjà enregistré. Connectez-vous plutôt.');
      (err as any).statusCode = 409;
      throw err;
    }
    const user = await prisma.user.create({
      data: { npi, did, publicKey, firstName: firstName ?? null, lastName: lastName ?? null },
    });
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { did, id: user.id, token, firstName: user.firstName, lastName: user.lastName };
  },

  async login({ npi, signature }: { npi: string; signature: string }) {
    const user = await prisma.user.findUnique({ where: { npi } });
    if (!user) {
      const err = new Error('Utilisateur non trouvé. Enrôlez-vous d\'abord.');
      (err as any).statusCode = 401;
      throw err;
    }
    let isValid = false;
    try {
      isValid = ed25519Crypto.verify(user.publicKey, npi, signature);
    } catch (_) {
      isValid = false;
    }
    if (!isValid) {
      const err = new Error('Signature invalide ou clé non reconnue.');
      (err as any).statusCode = 401;
      throw err;
    }
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did, id: user.id, firstName: user.firstName, lastName: user.lastName };
  },

  async loginSimple(npi: string) {
    const user = await prisma.user.findUnique({ where: { npi } });
    if (!user) {
      const err = new Error('Utilisateur non trouvé. Enrôlez-vous d\'abord.');
      (err as any).statusCode = 401;
      throw err;
    }
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did, id: user.id, firstName: user.firstName, lastName: user.lastName };
  },

  async loginWithKeycloak(keycloakToken: string) {
    return keycloakService.loginWithKeycloak(keycloakToken);
  },

  async validateSession(token: string) {
    const payload = jwt.verify(token, config.JWT_SECRET) as jwt.JwtPayload;
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user) {
      const err = new Error('Session invalide. Utilisateur introuvable.');
      (err as any).statusCode = 401;
      throw err;
    }
    return { id: user.id, did: user.did, npi: user.npi, roles: payload.roles ?? ['citizen'], firstName: user.firstName, lastName: user.lastName };
  },

  async rotateKey({ userId, newPublicKey }: { userId: string; newPublicKey: string }) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      const err = new Error('Utilisateur introuvable.');
      (err as any).statusCode = 404;
      throw err;
    }
    await prisma.user.update({
      where: { id: userId },
      data: { publicKey: newPublicKey },
    });
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did, oldKey: 'rotated', newKey: newPublicKey };
  },

  async getUserRoles(userId: string): Promise<string[]> {
    return keycloakService.getUserRoles(userId);
  },

  async updateProfile({ userId, firstName, lastName }: { userId: string; firstName?: string; lastName?: string }) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      const err = new Error('Utilisateur introuvable.');
      (err as any).statusCode = 404;
      throw err;
    }
    await prisma.user.update({
      where: { id: userId },
      data: { firstName: firstName ?? user.firstName, lastName: lastName ?? user.lastName },
    });
    return { id: user.id, npi: user.npi, did: user.did, firstName: firstName ?? user.firstName, lastName: lastName ?? user.lastName };
  },
};
