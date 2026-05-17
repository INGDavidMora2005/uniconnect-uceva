import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/route_service.dart';
import '../lib/models/route_model.dart';

FakeFirebaseFirestore? _fakeFirestore;
late RouteService routeService;

RouteModel buildFakeRoute() {
  return RouteModel(
    id: 'test-route-id',
    origin: 'Cúcuta',
    destination: 'Ocaña',
    date: '2026-12-01',
    time: '07:00',
    price: 5000.0,
    availableSeats: 3,
    totalSeats: 4,
    driverName: 'Conductor Test',
    driverInitials: 'CT',
    driverRating: 4.5,
    meetingPoint: 'Terminal de Pasajeros',
    status: RouteStatus.activa,
  );
}

void main() {
  setUp(() {
    _fakeFirestore = FakeFirebaseFirestore();
    routeService = RouteService();
    routeService.setDatabase(_fakeFirestore!);
  });

  group('RouteService', () {
    test('is singleton', () {
      final instance1 = RouteService();
      final instance2 = RouteService();
      expect(identical(instance1, instance2), true);
    });
  });
}