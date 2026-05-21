// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:mockito/mockito.dart';

import 'package:uniconnect_dev/services/auth_service.dart';
import 'package:uniconnect_dev/services/crypto_service.dart';

import 'auth_service_test_helpers.dart';
import 'auth_service_test_helpers.mocks.dart';

void registerFlowTests() {
  group('Flujo de registro', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeDb;
    late MockCryptoService mockCrypto;
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      fakeDb = FakeFirebaseFirestore();
      mockCrypto = MockCryptoService();
      mockStorage = MockFlutterSecureStorage();
      resetAuthServiceDependencies(
        auth: mockAuth,
        db: fakeDb,
        cryptoService: mockCrypto,
        secureStorage: mockStorage,
      );
    });

    const fullName = 'Nombre Completo';
    const studentCode = '2020115001';
    const email = 'estudiante@uceva.edu.co';
    const password = 'Test1234!';
    const role = 'Estudiante';
    const faculty = 'Ingeniería';
    const phone = '3001234567';

    String computeHash(String input) => sha256.convert(utf8.encode(input)).toString();

    test('rechaza email con dominio externo', () async {
      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: 'otro@gmail.com',
        password: password,
        role: role,
        faculty: faculty,
        phone: phone,
      );
      expect(result, 'Solo se permiten correos @uceva.edu.co.');
    });

    test('rechaza teléfono con menos de 10 dígitos', () async {
      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: '123456789',
      );
      expect(result, 'Ingresa un número válido de 10 dígitos (ej: 3001234567)');
    });

    test('rechaza teléfono con más de 10 dígitos', () async {
      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: '12345678901',
      );
      expect(result, 'Ingresa un número válido de 10 dígitos (ej: 3001234567)');
    });

    test('rechaza teléfono con letras', () async {
      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: '30012a4567',
      );
      expect(result, 'Ingresa un número válido de 10 dígitos (ej: 3001234567)');
    });

    test('rechaza teléfono ya registrado en Firestore', () async {
      final hashedPhone = computeHash(phone);
      await fakeDb.collection('users').doc('dup-phone').set({
        'hashedPhone': hashedPhone,
      });

      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: phone,
      );
      expect(result, 'Este número ya está registrado en otra cuenta.');
    });

    test('rechaza código estudiantil ya registrado', () async {
      final hashedCode = computeHash(studentCode);
      await fakeDb.collection('users').doc('dup-code').set({
        'hashedStudentCode': hashedCode,
      });

      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: phone,
      );
      expect(result, 'Este código estudiantil ya está registrado.');
    });

    test('registro exitoso retorna verification_email_sent', () async {
      final mockUser = MockUser(
        uid: 'test-uid-001',
        email: email,
        isEmailVerified: false,
      );
      mockAuth = MockFirebaseAuth(
        mockUser: mockUser,
        verifyEmailAutomatically: false,
      );
      resetAuthServiceDependencies(
        auth: mockAuth,
        db: fakeDb,
        cryptoService: mockCrypto,
        secureStorage: mockStorage,
      );

      when(mockCrypto.encryptPassword(any)).thenAnswer(
        (_) async => EncryptedPayload(
          ciphertext: 'dummy-ciphertext',
          iv: 'dummy-iv',
          encryptedKey: 'dummy-key',
        ),
      );
      when(mockCrypto.encryptData(any)).thenAnswer(
        (_) async => {
          'encryptedData': 'dummy-data',
          'iv': 'dummy-iv',
          'encryptedKey': 'dummy-key',
        },
      );
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: phone,
      );
      expect(result, 'verification_email_sent');
    });

    test('email ya registrado en Firebase Auth', () async {
      whenCalling(
        Invocation.method(#createUserWithEmailAndPassword, null),
      ).on(mockAuth).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        ),
      );

      when(mockCrypto.encryptPassword(any)).thenAnswer(
        (_) async => EncryptedPayload(
          ciphertext: 'c',
          iv: 'i',
          encryptedKey: 'k',
        ),
      );
      when(mockCrypto.encryptData(any)).thenAnswer(
        (_) async => {
          'encryptedData': 'c',
          'iv': 'i',
          'encryptedKey': 'k',
        },
      );
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      final result = await AuthService().register(
        fullName: fullName,
        studentCode: studentCode,
        email: email,
        password: password,
        role: role,
        faculty: faculty,
        phone: phone,
      );
      expect(result, 'Este correo ya está registrado.');
    });
  });
}

void main() {
  registerFlowTests();
}
