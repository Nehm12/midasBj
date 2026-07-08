/// Service cryptographique côté mobile.
///
/// Wrapper autour du package `cryptography` 2.9.0 qui fournit :
/// - Ed25519 : signature et vérification
/// - X25519 : échange de clés Diffie-Hellman
/// - ChaCha20-Poly1305 : chiffrement authentifié AEAD
///
/// Les clés sont générées avec `newKeyPair()` et extraites
/// avec `extractPublicKey()` / `extractPrivateKeyBytes()`.
library;
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final ed25519 = Ed25519();
  final x25519 = X25519();
  final chacha20 = Chacha20.poly1305Aead();

  Future<SimpleKeyPair> generateEd25519KeyPair() => ed25519.newKeyPair();

  Future<KeyPair> generateX25519KeyPair() => x25519.newKeyPair();

  /// Signe un message avec la clé privée Ed25519
  Future<List<int>> signEd25519(KeyPair keyPair, List<int> message) async {
    final signature = await ed25519.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

  /// Vérifie une signature Ed25519
  Future<bool> verifyEd25519(
    SimplePublicKey publicKey,
    List<int> message,
    List<int> signature,
  ) async {
    return ed25519.verify(
      message,
      signature: Signature(signature, publicKey: publicKey),
    );
  }

  /// Chiffre un message avec ChaCha20-Poly1305
  Future<List<int>> encryptChaCha20({
    required SecretKey secretKey,
    required List<int> plaintext,
    List<int>? nonce,
  }) async {
    final secretBox = await chacha20.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return secretBox.concatenation();
  }

  /// Déchiffre un message avec ChaCha20-Poly1305
  Future<List<int>> decryptChaCha20({
    required SecretKey secretKey,
    required List<int> ciphertext,
    required List<int> nonce,
    required Mac mac,
  }) async {
    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);
    return chacha20.decrypt(secretBox, secretKey: secretKey);
  }

  /// Échange de clé Diffie-Hellman X25519
  Future<SecretKey> x25519SharedSecret(
    KeyPair local,
    PublicKey remote,
  ) async {
    return x25519.sharedSecretKey(
      keyPair: local,
      remotePublicKey: remote,
    );
  }
}
