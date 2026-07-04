import 'package:cryptography/cryptography.dart';

class CryptoService {
  final ed25519 = Ed25519();
  final x25519 = X25519();
  final chacha20 = Chacha20.poly1305Aead();

  Future<SimpleKeyPair> generateEd25519KeyPair() => ed25519.newKeyPair();

  Future<KeyPair> generateX25519KeyPair() => x25519.newKeyPair();

  Future<List<int>> signEd25519(KeyPair keyPair, List<int> message) async {
    final signature = await ed25519.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

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

  Future<List<int>> decryptChaCha20({
    required SecretKey secretKey,
    required List<int> ciphertext,
    required List<int> nonce,
    required Mac mac,
  }) async {
    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);
    return chacha20.decrypt(secretBox, secretKey: secretKey);
  }

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
