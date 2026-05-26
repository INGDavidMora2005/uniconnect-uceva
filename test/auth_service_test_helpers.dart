// ignore_for_file: depend_on_referenced_packages

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/annotations.dart';

import 'package:uniconnect_dev/services/auth_service.dart';
import 'package:uniconnect_dev/services/crypto_service.dart';

import 'auth_service_test_helpers.mocks.dart';

@GenerateMocks([FlutterSecureStorage, CryptoService])
void main() {}

void resetAuthServiceDependencies({
  MockFirebaseAuth? auth,
  FakeFirebaseFirestore? db,
  MockCryptoService? cryptoService,
  MockFlutterSecureStorage? secureStorage,
}) {
  final service = AuthService();
  service.setDependencies(
    auth: auth ?? MockFirebaseAuth(),
    db: db ?? FakeFirebaseFirestore(),
    cryptoService: cryptoService,
    secureStorage: secureStorage,
  );
}
