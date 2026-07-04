import prisma from '../../infrastructure/db/client.js';
import config from '../../config/index.js';
import jwt from 'jsonwebtoken';
import { ed25519Crypto } from '../../infrastructure/crypto/ed25519.js';

export const authService = {
  async register({ npi, publicKey }: { npi: string; publicKey: string }) {
    const did = `did:midas:benin:${npi}`;
    const user = await prisma.user.create({
      data: { npi, did, publicKey },
    });
    return { did, id: user.id };
  },

  async login({ npi, signature }: { npi: string; signature: string }) {
    const user = await prisma.user.findUniqueOrThrow({ where: { npi } });
    const isValid = ed25519Crypto.verify(user.publicKey, npi, signature);
    if (!isValid) {
      throw new Error('Invalid signature');
    }
    const token = jwt.sign(
      { sub: user.id, did: user.did, npi: user.npi },
      config.JWT_SECRET,
      { expiresIn: '24h' },
    );
    return { token, did: user.did };
  },

  async validateSession(token: string) {
    const payload = jwt.verify(token, config.JWT_SECRET) as jwt.JwtPayload;
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: payload.sub },
    });
    return { id: user.id, did: user.did, npi: user.npi };
  },
};
