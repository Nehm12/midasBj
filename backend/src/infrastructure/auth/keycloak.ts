/**
 * Service d'intégration Keycloak (OIDC / SSO).
 *
 * Fonctionnalités :
 * - Validation des tokens OIDC émis par Keycloak
 * - Synchronisation des utilisateurs MIDAS ↔ Keycloak
 * - Gestion des rôles (citizen, iot_operator, apdp_inspector)
 * - Admin API pour créer/mettre à jour des utilisateurs Keycloak
 */
import config from '../../config/index.js';
import prisma from '../db/client.js';

interface KeycloakTokenPayload {
  sub: string;
  preferred_username?: string;
  email?: string;
  given_name?: string;
  family_name?: string;
  realm_access?: { roles: string[] };
  npi?: string;
}

interface KeycloakUserRepresentation {
  id?: string;
  username: string;
  enabled: boolean;
  email?: string;
  firstName?: string;
  lastName?: string;
  attributes?: Record<string, string[]>;
  realmRoles?: string[];
  credentials?: { type: string; value: string; temporary?: boolean }[];
}

const KEYCLOAK_BASE = `${config.KEYCLOAK_URL}/admin/realms/${config.KEYCLOAK_REALM}`;

async function getAdminToken(): Promise<string> {
  const res = await fetch(`${config.KEYCLOAK_URL}/realms/master/protocol/openid-connect/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: 'admin-cli',
      username: 'admin',
      password: 'admin',
      grant_type: 'password',
    }),
  });
  if (!res.ok) throw new Error(`Keycloak admin auth failed: ${res.statusText}`);
  const data = (await res.json()) as { access_token: string };
  return data.access_token;
}

async function adminFetch(path: string, options: RequestInit = {}) {
  const token = await getAdminToken();
  const res = await fetch(`${KEYCLOAK_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Keycloak API error ${res.status}: ${text}`);
  }
  return res;
}

export const keycloakService = {

  async validateToken(token: string): Promise<KeycloakTokenPayload> {
    const res = await fetch(
      `${config.KEYCLOAK_URL}/realms/${config.KEYCLOAK_REALM}/protocol/openid-connect/userinfo`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (!res.ok) throw new Error('Invalid Keycloak token');
    const payload = (await res.json()) as KeycloakTokenPayload;
    return payload;
  },

  async createUser(userData: KeycloakUserRepresentation): Promise<string> {
    const res = await adminFetch('/users', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
    const location = res.headers.get('location');
    if (!location) throw new Error('No location header in Keycloak response');
    const id = location.split('/').pop()!;
    if (userData.realmRoles && userData.realmRoles.length > 0) {
      const roles = await this.getRoles();
      const roleIds = roles
        .filter((r) => userData.realmRoles!.includes(r.name))
        .map((r) => ({ id: r.id, name: r.name }));
      await adminFetch(`/users/${id}/role-mappings/realm`, {
        method: 'POST',
        body: JSON.stringify(roleIds),
      });
    }
    return id;
  },

  async getRoles(): Promise<{ id: string; name: string }[]> {
    const res = await adminFetch('/roles');
    return res.json() as Promise<{ id: string; name: string }[]>;
  },

  async getUserById(userId: string): Promise<KeycloakUserRepresentation | null> {
    try {
      const res = await adminFetch(`/users/${userId}`);
      return res.json() as Promise<KeycloakUserRepresentation>;
    } catch {
      return null;
    }
  },

  async syncUserToMidas(keycloakUser: KeycloakTokenPayload, npi?: string) {
    const resolvedNpi = npi ?? keycloakUser.npi ?? keycloakUser.preferred_username;
    if (!resolvedNpi) throw new Error('Cannot resolve NPI from Keycloak token');

    const existing = await prisma.user.findUnique({ where: { npi: resolvedNpi } });
    if (existing) {
      await prisma.user.update({
        where: { npi: resolvedNpi },
        data: { keycloakId: keycloakUser.sub },
      });
      return existing;
    }

    const did = `did:midas:benin:${resolvedNpi}`;
    const user = await prisma.user.create({
      data: {
        npi: resolvedNpi,
        did,
        publicKey: '',
        keycloakId: keycloakUser.sub,
      },
    });
    return user;
  },

  async loginWithKeycloak(token: string) {
    const payload = await this.validateToken(token);
    const user = await this.syncUserToMidas(payload);
    const roles = payload.realm_access?.roles ?? [];
    return {
      id: user.id,
      did: user.did,
      npi: user.npi,
      keycloakId: user.keycloakId,
      roles,
    };
  },

  async createKeycloakUserForMidasUser(userId: string) {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const kcId = await this.createUser({
      username: user.npi,
      enabled: true,
      attributes: { npi: [user.npi], did: [user.did] },
      realmRoles: ['citizen'],
      credentials: [{ type: 'password', value: 'midas-' + user.npi.toLowerCase(), temporary: true }],
    });
    await prisma.user.update({
      where: { id: userId },
      data: { keycloakId: kcId },
    });
    return kcId;
  },

  async getUserRoles(userId: string): Promise<string[]> {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.keycloakId) return ['citizen'];
    try {
      const res = await adminFetch(`/users/${user.keycloakId}/role-mappings/realm/composite`);
      const roles = (await res.json()) as { name: string }[];
      return roles.map((r) => r.name);
    } catch {
      return ['citizen'];
    }
  },
};

export type { KeycloakTokenPayload, KeycloakUserRepresentation };
