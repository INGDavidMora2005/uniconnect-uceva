import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Función top-level para generar par de claves RSA en isolate separado
/// Se ejecuta en hilo separado para no bloquear la UI
/// ref: Stallings cap 9 - RSA Key Generation
Map<String, String> _generateRSAKeyPairIsolate(int keySize) {
  final secureRandom = _createSecureRandomIsolate();
  final keyParams = RSAKeyGeneratorParameters(
    BigInt.parse('65537'),
    keySize,
    64,
  );

  final params = ParametersWithRandom(keyParams, secureRandom);
  final keyGenerator = RSAKeyGenerator();
  keyGenerator.init(params);

  final keyPair = keyGenerator.generateKeyPair();
  final publicKey = keyPair.publicKey as RSAPublicKey;
  final privateKey = keyPair.privateKey as RSAPrivateKey;

  final modBytes = publicKey.modulus!.toRadixString(16);
  final expBytes = publicKey.exponent!.toRadixString(16);
  final publicKeyStr = base64.encode(utf8.encode('$modBytes:$expBytes'));

  final pBytes = privateKey.p!.toRadixString(16);
  final qBytes = privateKey.q!.toRadixString(16);
  final dBytes = privateKey.privateExponent!.toRadixString(16);
  final nBytes = privateKey.modulus!.toRadixString(16);
  final privateKeyStr = base64.encode(
    utf8.encode('$pBytes:$qBytes:$dBytes:$nBytes'),
  );

  return {'publicKey': publicKeyStr, 'privateKey': privateKeyStr};
}

SecureRandom _createSecureRandomIsolate() {
  final random = Random.secure();
  final secureRandom = FortunaRandom();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}

/// Servicio de gestión de claves RSA-2048
/// Implementación basada en Stallings - Cryptography and Network Security
/// Capítulos 9 y 10 sobre cifrado de clave pública RSA
class KeyService {
  static final KeyService _instance = KeyService._internal();
  factory KeyService() => _instance;
  KeyService._internal();

  static const String _publicKeyKey = 'rsa_public_key';
  static const String _privateKeyKey = 'rsa_private_key';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _cachedKeyPair;

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
  /// Usa compute() para ejecutar en isolate separado
  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
  generateNewKeys() async {
    debugPrint('[KeyService] Generando par RSA-2048 en isolate separado...');
    final stopwatch = Stopwatch()..start();

    final result = await compute(_generateRSAKeyPairIsolate, 2048);

    stopwatch.stop();
    debugPrint(
      '[KeyService] Par RSA-2048 generado en ${stopwatch.elapsedMilliseconds} ms',
    );

    final publicKeyStr = result['publicKey']!;
    final privateKeyStr = result['privateKey']!;

    await _secureStorage.write(key: _publicKeyKey, value: publicKeyStr);
    await _secureStorage.write(key: _privateKeyKey, value: privateKeyStr);

    final publicKey = _parsePublicKey(publicKeyStr);
    final privateKey = _parsePrivateKey(privateKeyStr);
    _cachedKeyPair = AsymmetricKeyPair(publicKey, privateKey);
    return _cachedKeyPair!;
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

  /// Decodifica string a clave pública RSA
  RSAPublicKey _parsePublicKey(String encoded) {
    final decoded = utf8.decode(base64.decode(encoded));
    final parts = decoded.split(':');
    final modulus = BigInt.parse(parts[0], radix: 16);
    final exponent = BigInt.parse(parts[1], radix: 16);
    return RSAPublicKey(modulus, exponent);
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
