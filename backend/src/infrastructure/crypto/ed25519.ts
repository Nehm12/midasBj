/**
 * Fonctions cryptographiques Ed25519.
 *
 * Wrapper autour de la bibliothèque @noble/curves qui fournit :
 * - generateKeyPair() : génère une clé privée aléatoire et dérive la clé publique
 * - sign(privKeyHex, message) : signe un message avec la clé privée
 * - verify(pubKeyHex, message, sigHex) : vérifie une signature avec la clé publique
 *
 * Les clés et signatures sont encodées en hexadécimal pour le transport JSON.
 */
import { ed25519 } from '@noble/curves/ed25519';

export const ed25519Crypto = {
  /**
   * Génère une paire de clés Ed25519.
   * La clé privée est générée aléatoirement de façon sécurisée.
   */
  generateKeyPair() {
    const privateKey = ed25519.utils.randomPrivateKey();
    const publicKey = ed25519.getPublicKey(privateKey);
    return {
      privateKey: Buffer.from(privateKey).toString('hex'),
      publicKey: Buffer.from(publicKey).toString('hex'),
    };
  },

  /**
   * Signe un message avec la clé privée.
   * Retourne la signature en hexadécimal.
   */
  sign(privateKeyHex: string, message: string): string {
    const privateKey = Buffer.from(privateKeyHex, 'hex');
    const signature = ed25519.sign(Buffer.from(message, 'utf-8'), privateKey);
    return Buffer.from(signature).toString('hex');
  },

  /**
   * Vérifie qu'une signature correspond bien au message et à la clé publique.
   * Gère les clés en hex ou base64 (compatibilité anciens comptes).
   */
  verify(
    publicKeyHex: string,
    message: string,
    signatureHex: string,
  ): boolean {
    let publicKeyBuf = Buffer.from(publicKeyHex, 'hex');
    if (publicKeyBuf.length !== 32) {
      publicKeyBuf = Buffer.from(publicKeyHex, 'base64');
    }
    let signatureBuf = Buffer.from(signatureHex, 'hex');
    if (signatureBuf.length !== 64) {
      signatureBuf = Buffer.from(signatureHex, 'base64');
    }
    return ed25519.verify(
      signatureBuf,
      Buffer.from(message, 'utf-8'),
      publicKeyBuf,
    );
  },
};
