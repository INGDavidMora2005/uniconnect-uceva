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

void authServiceExtraTests() {
  group('AuthService - Cobertura adicional (métodos con 0% previo)', () {
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

    group('forgotPassword()', () {
      test('Email vacío → retorna mensaje obligatorio', () async {
        final result = await AuthService().forgotPassword('');
        expect(result, 'El correo es obligatorio.');
      });

      test('Email con dominio externo → retorna mensaje de dominio', () async {
        final result = await AuthService().forgotPassword('otro@gmail.com');
        expect(result, 'Solo se permiten emails @uceva.edu.co.');
      });

      test('Email válido exitoso → retorna éxito (MockFirebaseAuth permite sendPasswordResetEmail por defecto)', () async {
        final result = await AuthService().forgotPassword('estudiante@uceva.edu.co');
        expect(result, 'Email de recuperación enviado. Revisa tu bandeja de entrada.');
      });

      test('Email no encontrado (user-not-found) → retorna mensaje apropiado', () async {
        whenCalling(
          Invocation.method(#sendPasswordResetEmail, null),
        ).on(mockAuth).thenThrow(
          FirebaseAuthException(code: 'user-not-found'),
        );

        final result = await AuthService().forgotPassword('noexiste@uceva.edu.co');
        expect(result, 'Usuario no encontrado.');
      });
    });

    group('logout()', () {
      test('Sin sesión activa → completa sin error', () async {
        // mockAuth por defecto no tiene usuario
        await AuthService().logout();
        // Si no lanza, el test pasa
      });

      test('Con sesión activa → actualiza fcmToken y signOut completa sin error', () async {
        final mockUser = MockUser(
          uid: 'uid-logout-test',
          email: 'estudiante@uceva.edu.co',
        );
        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        resetAuthServiceDependencies(
          auth: mockAuth,
          db: fakeDb,
          cryptoService: mockCrypto,
          secureStorage: mockStorage,
        );

        await fakeDb.collection('users').doc('uid-logout-test').set({
          'fullName': 'Test User',
          'email': 'estudiante@uceva.edu.co',
          'fcmToken': 'old-token',
        });

        await AuthService().logout();
      });
    });

    group('sendVerificationEmail()', () {
      test('Sin sesión activa → retorna mensaje de no sesión', () async {
        final result = await AuthService().sendVerificationEmail();
        expect(result, 'No hay sesión activa.');
      });

      test('Con sesión activa y envío exitoso → retorna "sent"', () async {
        final mockUser = MockUser(
          uid: 'uid-verify-ok',
          email: 'estudiante@uceva.edu.co',
          isEmailVerified: false,
        );
        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        resetAuthServiceDependencies(
          auth: mockAuth,
          db: fakeDb,
          cryptoService: mockCrypto,
          secureStorage: mockStorage,
        );

        final result = await AuthService().sendVerificationEmail();
        expect(result, 'sent');
      });

      test('Error too-many-requests → retorna código específico', () async {
        final mockUser = MockUser(
          uid: 'uid-verify-rate',
          email: 'estudiante@uceva.edu.co',
        );
        whenCalling(
          Invocation.method(#sendEmailVerification, null),
        ).on(mockUser).thenThrow(
          FirebaseAuthException(code: 'too-many-requests'),
        );

        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        resetAuthServiceDependencies(
          auth: mockAuth,
          db: fakeDb,
          cryptoService: mockCrypto,
          secureStorage: mockStorage,
        );

        final result = await AuthService().sendVerificationEmail();
        expect(result, 'too_many_requests');
      });
    });

    group('getUserData()', () {
      test('Sin sesión activa → retorna null', () async {
        final result = await AuthService().getUserData();
        expect(result, isNull);
      });

      test('Con sesión activa pero sin documento en Firestore → retorna null', () async {
        final mockUser = MockUser(
          uid: 'uid-sin-doc',
          email: 'estudiante@uceva.edu.co',
        );
        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        resetAuthServiceDependencies(
          auth: mockAuth,
          db: fakeDb,
          cryptoService: mockCrypto,
          secureStorage: mockStorage,
        );

        final result = await AuthService().getUserData();
        expect(result, isNull);
      });

      test('Con sesión activa y documento completo → retorna UserModel no nulo', () async {
        const uid = 'uid-con-datos';
        final mockUser = MockUser(
          uid: uid,
          email: 'estudiante@uceva.edu.co',
        );
        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        resetAuthServiceDependencies(
          auth: mockAuth,
          db: fakeDb,
          cryptoService: mockCrypto,
          secureStorage: mockStorage,
        );

        await fakeDb.collection('users').doc(uid).set({
          'fullName': 'Estudiante Prueba',
          'email': 'estudiante@uceva.edu.co',
          'studentCode': '2020115001',
          'role': 'Estudiante',
          'faculty': 'Ingeniería',
          'phone': '3001234567',
          'description': 'Perfil de prueba',
          'profileImageUrl': null,
          'rating': 4.5,
          'tripsCompleted': 12,
          'bazarPurchases': 3,
          'suspended': false,
        });

        final result = await AuthService().getUserData();
        expect(result, isNotNull);
        expect(result!.id, uid);
        expect(result.fullName, 'Estudiante Prueba');
        expect(result.studentCode, '2020115001');
        expect(result.email, 'estudiante@uceva.edu.co');
      });
    });

    group('register() - ramas faltantes de FirebaseAuthException', () {
      const fullName = 'Nombre Completo';
      const studentCode = '2020115001';
      const email = 'estudiante@uceva.edu.co';
      const password = 'Test1234!';
      const role = 'Estudiante';
      const faculty = 'Ingeniería';
      const phone = '3001234567';

      test('Contraseña débil (weak-password) → retorna mensaje específico', () async {
        whenCalling(
          Invocation.method(#createUserWithEmailAndPassword, null),
        ).on(mockAuth).thenThrow(
          FirebaseAuthException(code: 'weak-password'),
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
        expect(result, 'La contraseña es demasiado débil.');
      });

      test('Email inválido según Firebase (invalid-email) → retorna mensaje', () async {
        whenCalling(
          Invocation.method(#createUserWithEmailAndPassword, null),
        ).on(mockAuth).thenThrow(
          FirebaseAuthException(code: 'invalid-email'),
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
        expect(result, 'El correo no es válido.');
      });
    });
  });
}

void main() {
  authServiceExtraTests();
}
