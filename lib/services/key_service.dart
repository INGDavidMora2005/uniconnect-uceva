import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Servicio de gestión de claves RSA-2048
/// Implementación basada en Stallings - Cryptography and Network Security
/// Capítulos 9 y 10 sobre cifrado de clave pública RSA
class KeyService {
  static final KeyService _instance = KeyService._internal();
  factory KeyService() => _instance;
  KeyService._internal();

  static const String _publicKeyKey = 'rsa_public_key';
  static const String _privateKeyKey = 'rsa_private_key';
  static const int _keySize = 2048;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _cachedKeyPair;

  /// Genera un par de claves RSA-2048
  /// RSA: basado en la dificultad de factorizar números grandes
  /// ref: Stallings cap 9 - The RSA Public-Ciphertext cryptosystem
  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateKeyPair() {
    final secureRandom = _createSecureRandom();
    final keyParams = RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      _keySize,
      64,
    );

    final params = ParametersWithRandom(keyParams, secureRandom);
    final keyGenerator = RSAKeyGenerator();
    keyGenerator.init(params);

    final keyPair = keyGenerator.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      keyPair.publicKey as RSAPublicKey,
      keyPair.privateKey as RSAPrivateKey,
    );
  }

  SecureRandom _createSecureRandom() {
    final random = Random.secure();
    final secureRandom = FortunaRandom();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Carga las claves RSA del almacenamiento seguro
  /// Si no existen, las genera por primera vez
  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
  loadOrGenerateKeys() async {
    if (_cachedKeyPair != null) {
      return _cachedKeyPair!;
    }

    try {
      final publicKeyStr = await _secureStorage.read(key: _publicKeyKey);
      final privateKeyStr = await _secureStorage.read(key: _privateKeyKey);

      if (publicKeyStr != null && privateKeyStr != null) {
        final publicKey = _parsePublicKey(publicKeyStr);
        final privateKey = _parsePrivateKey(privateKeyStr);
        _cachedKeyPair = AsymmetricKeyPair(publicKey, privateKey);
        return _cachedKeyPair!;
      }
    } catch (e) {
      debugPrint('Error loading keys: $e');
    }

    return generateNewKeys();
  }

  /// Genera nuevas claves RSA y las almacena
  /// ref: Stallings - key generation para RSA
  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
  generateNewKeys() async {
    final keyPair = _generateKeyPair();

    final publicKeyStr = _encodePublicKey(keyPair.publicKey);
    final privateKeyStr = _encodePrivateKey(keyPair.privateKey);

    await _secureStorage.write(key: _publicKeyKey, value: publicKeyStr);
    await _secureStorage.write(key: _privateKeyKey, value: privateKeyStr);

    _cachedKeyPair = keyPair;
    return keyPair;
  }

  /// Obtiene la clave pública RSA para cifrar
  Future<RSAPublicKey> getPublicKey() async {
    final keyPair = await loadOrGenerateKeys();
    return keyPair.publicKey;
  }

  /// Obtiene la clave privada RSA para descifrar
  Future<RSAPrivateKey> getPrivateKey() async {
    final keyPair = await loadOrGenerateKeys();
    return keyPair.privateKey;
  }

  /// Codifica clave pública a string PEM-like
  String _encodePublicKey(RSAPublicKey key) {
    final modBytes = key.modulus!.toRadixString(16);
    final expBytes = key.exponent!.toRadixString(16);
    return base64.encode(utf8.encode('$modBytes:$expBytes'));
  }

  /// Decodifica string a clave pública RSA
  RSAPublicKey _parsePublicKey(String encoded) {
    final decoded = utf8.decode(base64.decode(encoded));
    final parts = decoded.split(':');
    final modulus = BigInt.parse(parts[0], radix: 16);
    final exponent = BigInt.parse(parts[1], radix: 16);
    return RSAPublicKey(modulus, exponent);
  }

  /// Codifica clave privada a string
  String _encodePrivateKey(RSAPrivateKey key) {
    final pBytes = key.p!.toRadixString(16);
    final qBytes = key.q!.toRadixString(16);
    final dBytes = key.privateExponent!.toRadixString(16);
    final nBytes = key.modulus!.toRadixString(16);
    return base64.encode(utf8.encode('$pBytes:$qBytes:$dBytes:$nBytes'));
  }

  /// Decodifica string a clave privada RSA
  RSAPrivateKey _parsePrivateKey(String encoded) {
    final decoded = utf8.decode(base64.decode(encoded));
    final parts = decoded.split(':');
    final p = BigInt.parse(parts[0], radix: 16);
    final q = BigInt.parse(parts[1], radix: 16);
    final d = BigInt.parse(parts[2], radix: 16);
    final n = BigInt.parse(parts[3], radix: 16);
    return RSAPrivateKey(p, q, d, n);
  }

  /// Elimina las claves almacenadas (para testing/reset)
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _publicKeyKey);
    await _secureStorage.delete(key: _privateKeyKey);
    _cachedKeyPair = null;
  }
}
