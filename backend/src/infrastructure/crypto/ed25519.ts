import { ed25519 } from '@noble/curves/ed25519';

export const ed25519Crypto = {
  generateKeyPair() {
    const privateKey = ed25519.utils.randomPrivateKey();
    const publicKey = ed25519.getPublicKey(privateKey);
    return {
      privateKey: Buffer.from(privateKey).toString('hex'),
      publicKey: Buffer.from(publicKey).toString('hex'),
    };
  },

  sign(privateKeyHex: string, message: string): string {
    const privateKey = Buffer.from(privateKeyHex, 'hex');
    const signature = ed25519.sign(Buffer.from(message, 'utf-8'), privateKey);
    return Buffer.from(signature).toString('hex');
  },

  verify(
    publicKeyHex: string,
    message: string,
    signatureHex: string,
  ): boolean {
    const publicKey = Buffer.from(publicKeyHex, 'hex');
    const signature = Buffer.from(signatureHex, 'hex');
    return ed25519.verify(
      signature,
      Buffer.from(message, 'utf-8'),
      publicKey,
    );
  },
};
