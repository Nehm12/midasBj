/**
 * Script d'amorçage de la base de données.
 *
 * Crée des données de démonstration :
 * - Alice et Bob (citoyens avec leurs paires de clés Ed25519)
 * - Un VerifiableCredential de type NpiCredential pour Alice
 * - Un appareil IoT (ESP32) en attente d'appairage
 */
import prisma from './infrastructure/db/client.js';
import { ed25519Crypto } from './infrastructure/crypto/ed25519.js';

async function seed() {
  // --- Génération des clés Ed25519 pour les utilisateurs de démo ---
  const aliceKeys = ed25519Crypto.generateKeyPair();
  const bobKeys = ed25519Crypto.generateKeyPair();

  // --- Création des utilisateurs ---
  const alice = await prisma.user.create({
    data: {
      npi: 'NPIBENIN202400001',
      did: 'did:midas:benin:NPIBENIN202400001',
      publicKey: aliceKeys.publicKey,
    },
  });

  const bob = await prisma.user.create({
    data: {
      npi: 'NPIBENIN202400002',
      did: 'did:midas:benin:NPIBENIN202400002',
      publicKey: bobKeys.publicKey,
    },
  });

  // --- Création d'un credential vérifiable (NPI) émis par l'ANIP ---
  const vc = await prisma.verifiableCredential.create({
    data: {
      userId: alice.id,
      type: 'NpiCredential',
      issuer: 'did:midas:benin:anip',
      credential: {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        type: ['VerifiableCredential', 'NpiCredential'],
        credentialSubject: { id: alice.did, npi: alice.npi },
      },
      signature: ed25519Crypto.sign(aliceKeys.privateKey, alice.did),
    },
  });

  // --- Création d'un appareil IoT (simulation ESP32) ---
  const device = await prisma.ioTDevice.create({
    data: {
      deviceId: 'ESP32-S3-A1B2C3',
      publicKey: ed25519Crypto.generateKeyPair().publicKey,
      attestation: { manufacturer: 'Espressif', model: 'ESP32-S3', tpm: true },
      status: 'PENDING',
    },
  });

  console.log({ alice: alice.id, bob: bob.id, vc: vc.id, device: device.id });
  console.log('Alice private key:', aliceKeys.privateKey);
  console.log('Alice public key:', aliceKeys.publicKey);

  await prisma.$disconnect();
}

seed().catch(console.error);
