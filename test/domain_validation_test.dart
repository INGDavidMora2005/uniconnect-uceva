import 'package:flutter_test/flutter_test.dart';

import 'package:uniconnect_dev/services/auth_service.dart';
import 'auth_service_test_helpers.dart';

void domainValidationTests() {
  group('Validación de dominio @uceva.edu.co', () {
    setUp(() {
      resetAuthServiceDependencies();
    });

    test('acepta estudiante@uceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudiante@uceva.edu.co',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, isNot(equals('Solo se permiten correos @uceva.edu.co.')));
    });

    test('acepta juan.perez@uceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'juan.perez@uceva.edu.co',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, isNot(equals('Solo se permiten correos @uceva.edu.co.')));
    });

    test('acepta estudiante123@uceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudiante123@uceva.edu.co',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, isNot(equals('Solo se permiten correos @uceva.edu.co.')));
    });

    test('acepta admin.00@uceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'admin.00@uceva.edu.co',
        password: 'pass123',
        role: 'admin',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, isNot(equals('Solo se permiten correos @uceva.edu.co.')));
    });

    test('rechaza estudiante@gmail.com', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudiante@gmail.com',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });

    test('rechaza estudiante@uceva.edu.com', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudiante@uceva.edu.com',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });

    test('rechaza estudiante@uceva.edu', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudiante@uceva.edu',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });

    test('rechaza @uceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: '@uceva.edu.co',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });

    test('rechaza string vacío', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: '',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });

    test('rechaza estudianteuceva.edu.co', () async {
      final result = await AuthService().register(
        fullName: 'Test User',
        studentCode: '123',
        email: 'estudianteuceva.edu.co',
        password: 'pass123',
        role: 'student',
        faculty: 'Ing',
        phone: '000',
      );
      expect(result, equals('Solo se permiten correos @uceva.edu.co.'));
    });
  });
}

void main() {
  domainValidationTests();
}
