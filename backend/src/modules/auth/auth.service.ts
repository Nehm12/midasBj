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

  async register({ npi, publicKey }: { npi: string; publicKey: string }) {
    const did = `did:midas:benin:${npi}`;
    const user = await prisma.user.create({
      data: { npi, did, publicKey },
    });
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { did, id: user.id, token };
  },

  async login({ npi, signature }: { npi: string; signature: string }) {
    const user = await prisma.user.findUniqueOrThrow({ where: { npi } });
    const isValid = ed25519Crypto.verify(user.publicKey, npi, signature);
    if (!isValid) throw new Error('Invalid signature');
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did, id: user.id };
  },

  async loginSimple(npi: string) {
    const user = await prisma.user.findUniqueOrThrow({ where: { npi } });
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi, roles: ['citizen'] },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did, id: user.id };
  },

  async loginWithKeycloak(keycloakToken: string) {
    return keycloakService.loginWithKeycloak(keycloakToken);
  },

  async validateSession(token: string) {
    const payload = jwt.verify(token, config.JWT_SECRET) as jwt.JwtPayload;
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: payload.sub },
    });
    return { id: user.id, did: user.did, npi: user.npi, roles: payload.roles ?? ['citizen'] };
  },

  async rotateKey({ userId, newPublicKey }: { userId: string; newPublicKey: string }) {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
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
};
