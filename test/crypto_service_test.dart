import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:uniconnect_dev/services/crypto_service.dart';
import 'package:uniconnect_dev/services/key_service.dart';

void main() {
  group('CryptoService', () {
    late CryptoService crypto;

    setUpAll(() async {
      final secureRandom = FortunaRandom();
      final seeds = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
      final keyParams = RSAKeyGeneratorParameters(
        BigInt.parse('65537'),
        2048,
        64,
      );
      final params = ParametersWithRandom(keyParams, secureRandom);
      final keyGenerator = RSAKeyGenerator();
      keyGenerator.init(params);
      final keyPair = keyGenerator.generateKeyPair();
      final publicKey = keyPair.publicKey as RSAPublicKey;
      final privateKey = keyPair.privateKey as RSAPrivateKey;
      final pair = AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        publicKey,
        privateKey,
      );
      final keyService = KeyService();
      keyService.injectKeysForTesting(pair);
      crypto = CryptoService.withKeyService(keyService);
    });

    test('encryptData retorna los 3 campos requeridos', () async {
      final result = await crypto.encryptData('texto de prueba');
      expect(result.containsKey('encryptedData'), true);
      expect(result.containsKey('iv'), true);
      expect(result.containsKey('encryptedKey'), true);
      expect(result['encryptedData']!.isNotEmpty, true);
      expect(result['iv']!.isNotEmpty, true);
      expect(result['encryptedKey']!.isNotEmpty, true);
    });

    test(
      'decryptData(encryptData(texto)) devuelve el texto original — texto corto',
      () async {
        const plaintext = 'hola mundo';
        final encrypted = await crypto.encryptData(plaintext);
        final decrypted = await crypto.decryptData(encrypted);
        expect(decrypted, plaintext);
      },
    );

    test('round-trip con texto largo (500+ caracteres)', () async {
      final plaintext = 'a' * 500;
      final encrypted = await crypto.encryptData(plaintext);
      final decrypted = await crypto.decryptData(encrypted);
      expect(decrypted, plaintext);
    });

    test('round-trip con caracteres especiales (ñ, tildes, emojis)', () async {
      const plaintext = 'Contraseña con tildes: áéíóú ñ y emoji 🔐';
      final encrypted = await crypto.encryptData(plaintext);
      final decrypted = await crypto.decryptData(encrypted);
      expect(decrypted, plaintext);
    });

    test('IV es único en cada cifrado del mismo texto', () async {
      const text = 'test';
      final ivs = <String>[];
      final encryptedDatas = <String>[];
      for (int i = 0; i < 10; i++) {
        final result = await crypto.encryptData(text);
        ivs.add(result['iv']!);
        encryptedDatas.add(result['encryptedData']!);
      }
      expect(ivs.toSet().length, 10);
      expect(encryptedDatas.toSet().length, 10);
    });

    test('CryptoService() mantiene patrón singleton', () {
      final a = CryptoService();
      final b = CryptoService();
      expect(identical(a, b), true);
    });

    test('encryptWithAES / decryptWithAES round-trip', () {
      final Key key = crypto.generateSessionKey();
      const plaintext = 'sesion aes test';
      final ciphertext = crypto.encryptWithAES(plaintext, key);
      final decrypted = crypto.decryptWithAES(ciphertext, key);
      expect(decrypted, plaintext);
      final str1 = crypto.keyToString(key);
      final key2 = crypto.keyFromString(str1);
      final str2 = crypto.keyToString(key2);
      expect(str2, str1);
    });

    test('encryptData con texto vacío no lanza excepción', () async {
      expect(() async => await crypto.encryptData(''), returnsNormally);
    });

    test('EncryptedPayload serialización round-trip', () {
      final payload = EncryptedPayload(
        ciphertext: 'ct',
        iv: 'ivv',
        encryptedKey: 'ek',
      );
      final json = payload.toJson();
      final fromJson = EncryptedPayload.fromJson(json);
      expect(fromJson.ciphertext, 'ct');
      expect(fromJson.iv, 'ivv');
      expect(fromJson.encryptedKey, 'ek');
      final map = payload.toMap();
      final fromMap = EncryptedPayload.fromMap(map);
      expect(fromMap.ciphertext, 'ct');
      expect(fromMap.iv, 'ivv');
      expect(fromMap.encryptedKey, 'ek');
    });
  });
}
