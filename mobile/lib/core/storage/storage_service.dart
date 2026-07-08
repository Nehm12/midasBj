/// Service de stockage sécurisé.
///
/// Utilise FlutterSecureStorage (chiffré au niveau du système Android/iOS)
/// pour stocker les clés privées et les tokens.
///
/// Méthodes :
/// - saveSecure / readSecure / deleteSecure : stockage de chaînes
/// - saveJson / readJson : stockage de données JSON
/// - saveKeyPair : stockage des clés Ed25519 (privée + publique)
/// - saveCredential / readCredential : stockage des VCs
library;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSecure(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<String?> readSecure(String key) =>
      _secure.read(key: key);

  Future<void> deleteSecure(String key) =>
      _secure.delete(key: key);

  Future<void> saveJson(String key, Map<String, dynamic> json) =>
      saveSecure(key, jsonEncode(json));

  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = await readSecure(key);
    return value != null ? jsonDecode(value) as Map<String, dynamic> : null;
  }

  Future<void> saveCredential(String id, Map<String, dynamic> credential) =>
      saveJson('vc_$id', credential);

  Future<Map<String, dynamic>?> readCredential(String id) =>
      readJson('vc_$id');

  Future<void> saveKeyPair(String id, String privateKey, String publicKey) async {
    await saveSecure('kp_${id}_priv', privateKey);
    await saveSecure('kp_${id}_pub', publicKey);
  }
}
