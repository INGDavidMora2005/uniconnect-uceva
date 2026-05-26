// ignore_for_file: depend_on_referenced_packages

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

void loginFlowTests() {
  group('Flujo de login', () {
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

      when(mockCrypto.encryptPassword(any)).thenAnswer(
        (_) async => EncryptedPayload(
          ciphertext: 'dummy-ciphertext',
          iv: 'dummy-iv',
          encryptedKey: 'dummy-key',
        ),
      );
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});
    });

    test('Credenciales inválidas', () async {
      whenCalling(
        Invocation.method(#signInWithEmailAndPassword, null),
      ).on(mockAuth).thenThrow(
        FirebaseAuthException(code: 'invalid-credential'),
      );

      final result = await AuthService().login(
        'user@uceva.edu.co',
        'wrongpass',
      );
      expect(result, 'Correo o contraseña incorrectos.');
    });

    test('Cuenta deshabilitada', () async {
      whenCalling(
        Invocation.method(#signInWithEmailAndPassword, null),
      ).on(mockAuth).thenThrow(
        FirebaseAuthException(code: 'user-disabled'),
      );

      final result = await AuthService().login(
        'disabled@uceva.edu.co',
        'pass123',
      );
      expect(result, 'Esta cuenta ha sido deshabilitada.');
    });

    test('Email no verificado', () async {
      final mockUser = MockUser(
        uid: 'uid-noverify',
        email: 'student@uceva.edu.co',
        isEmailVerified: false,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
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
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      final result = await AuthService().login(
        'student@uceva.edu.co',
        'pass123',
      );
      expect(result, startsWith('email_not_verified:'));
    });

    test('Cuenta suspendida', () async {
      final mockUser = MockUser(
        uid: 'uid-suspended',
        email: 'susp@uceva.edu.co',
        isEmailVerified: true,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
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
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      await fakeDb.collection('users').doc('uid-suspended').set({
        'suspended': true,
      });

      final result = await AuthService().login(
        'susp@uceva.edu.co',
        'pass123',
      );
      expect(
        result,
        'Tu cuenta ha sido suspendida. Contacta al administrador para más información.',
      );
    });

    test('Login exitoso', () async {
      final mockUser = MockUser(
        uid: 'uid-ok',
        email: 'ok@uceva.edu.co',
        isEmailVerified: true,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
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
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      await fakeDb.collection('users').doc('uid-ok').set({
        'suspended': false,
      });

      final result = await AuthService().login(
        'ok@uceva.edu.co',
        'pass123',
      );
      expect(result, 'Inicio de sesión exitoso.');
    });

    test('Admin sin verificación de email', () async {
      final mockUser = MockUser(
        uid: 'uid-admin',
        email: 'admin.00@uceva.edu.co',
        isEmailVerified: false,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
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
      when(mockStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
      )).thenAnswer((_) async {});

      final result = await AuthService().login(
        'admin.00@uceva.edu.co',
        'pass123',
      );
      expect(result, 'Inicio de sesión exitoso.');
    });
  });
}

void main() {
  loginFlowTests();
}
