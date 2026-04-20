import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';
import 'key_service.dart';

/// Servicio de cifrado híbrido RSA-2048 + AES-256-CBC
/// Implementación basada en Stallings - Cryptography and Network Security
/// Capítulos 6-8 (AES) y 9-10 (RSA)
/// Patrón de cifrado híbrido: datos con AES, clave AES con RSA
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final KeyService _keyService = KeyService();

  /// Cifra datos sensibles usando AES-256-CBC
  /// AES: Advanced Encryption Standard - cifrado simétrico de bloque
  /// ref: Stallings cap 6 - Block Ciphers and the Data Encryption Standard
  /// ref: Stallings cap 7 - Advanced Encryption Standard
  ///
  /// Returns: {encryptedData: Base64, iv: Base64, encryptedKey: Base64}
  Future<Map<String, String>> encryptData(String plaintext) async {
    final aesKey = _generateAESKey();
    final iv = IV.fromSecureRandom(16);

    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final publicKey = await _keyService.getPublicKey();
    final encryptedAesKey = _rsaEncrypt(aesKey.bytes, publicKey);

    return {
      'encryptedData': encrypted.base64,
      'iv': iv.base64,
      'encryptedKey': base64.encode(encryptedAesKey),
    };
  }

  /// Descifra datos cifrados con el patrón híbrido
  /// ref: Stallings cap 9 - RSA para descifrado de clave
  Future<String> decryptData(Map<String, String> payload) async {
    final encryptedData = payload['encryptedData']!;
    final iv = IV.fromBase64(payload['iv']!);
    final encryptedKey = base64.decode(payload['encryptedKey']!);

    final privateKey = await _keyService.getPrivateKey();
    final aesKeyBytes = _rsaDecrypt(encryptedKey, privateKey);
    final aesKey = Key(Uint8List.fromList(aesKeyBytes));

    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted.fromBase64(encryptedData), iv: iv);
  }

  /// Cifra solo con AES-256-CBC (para datos que no requieren clave RSA)
  /// Útil para cifrado local de datos sensibles
  String encryptWithAES(String plaintext, Key aesKey) {
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Descifra solo con AES-256-CBC
  String decryptWithAES(String ciphertext, Key aesKey) {
    final parts = ciphertext.split(':');
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Genera una clave AES-256 aleatoria
  /// AES-256 usa clave de 256 bits = 32 bytes
  /// ref: Stallings cap 7 - AES Key Expansion
  Key _generateAESKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return Key(Uint8List.fromList(bytes));
  }

  /// Cifra datos con RSA-2048
  /// RSA: Cifrado de clave pública - cifrado asimétrico
  /// ref: Stallings cap 9 - The RSA Public-Key Cryptosystem
  ///
  /// Limitación: RSA solo puede cifrar datos menores que el módulo RSA
  Uint8List _rsaEncrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final input = Uint8List.fromList(data);
    final output = cipher.process(input);
    return output;
  }

  /// Descifra datos con RSA-2048
  Uint8List _rsaDecrypt(Uint8List data, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final input = Uint8List.fromList(data);
    final output = cipher.process(input);
    return output;
  }

  /// Genera clave AES aleatoria para uso externo
  Key generateSessionKey() => _generateAESKey();

  /// Convierte clave AES a string para almacenamiento
  String keyToString(Key key) => base64.encode(key.bytes);

  /// Convierte string a clave AES
  Key keyFromString(String encoded) {
    return Key(Uint8List.fromList(base64.decode(encoded)));
  }

  /// Cifra contraseña para transmisión segura
  /// Patrón híbrido completo:
  /// 1. Generar clave AES aleatoria por sesión
  /// 2. Cifrar contraseña con AES-256-CBC
  /// 3. Cifrar clave AES con RSA-2048 pública
  /// ref: Stallings cap 10 - Key Management and Distribution
  Future<EncryptedPayload> encryptPassword(String password) async {
    final encryptedData = await encryptData(password);
    return EncryptedPayload(
      ciphertext: encryptedData['encryptedData']!,
      iv: encryptedData['iv']!,
      encryptedKey: encryptedData['encryptedKey']!,
    );
  }

  /// Descifra contraseña recibida
  Future<String> decryptPassword(EncryptedPayload payload) async {
    return decryptData({
      'encryptedData': payload.ciphertext,
      'iv': payload.iv,
      'encryptedKey': payload.encryptedKey,
    });
  }
}

/// Clase para almacenar payload cifrado
class EncryptedPayload {
  final String ciphertext;
  final String iv;
  final String encryptedKey;

  EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    required this.encryptedKey,
  });

  Map<String, String> toMap() => {
    'encryptedData': ciphertext,
    'iv': iv,
    'encryptedKey': encryptedKey,
  };

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedPayload(
      ciphertext: map['encryptedData'] ?? map['ciphertext'],
      iv: map['iv'],
      encryptedKey: map['encryptedKey'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory EncryptedPayload.fromJson(String json) {
    return EncryptedPayload.fromMap(jsonDecode(json));
  }
}
