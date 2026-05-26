import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect_dev/services/location_service.dart';

void main() {
  group('LocationService', () {
    test('is singleton', () {
      final instance1 = LocationService();
      final instance2 = LocationService();
      expect(identical(instance1, instance2), true);
    });

    // Prueba básica: verificar que el servicio se instancia sin errores
    test('can be instantiated', () {
      expect(LocationService(), isNotNull);
    });
  });
}
