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

    group('publishRoute', () {
      test('publica una ruta y retorna mensaje de éxito', () async {
        final result = await routeService.publishRoute(buildFakeRoute());
        expect(result, 'Ruta publicada exitosamente.');
      });

      test('el documento queda guardado en la colección routes', () async {
        await routeService.publishRoute(buildFakeRoute());
        final snapshot = await _fakeFirestore!.collection('routes').get();
        expect(snapshot.docs.length, 1);
      });

      test('los campos del documento coinciden con el modelo', () async {
        final route = buildFakeRoute();
        await routeService.publishRoute(route);
        final snapshot = await _fakeFirestore!.collection('routes').get();
        final data = snapshot.docs.first.data();
        expect(data['origin'], route.origin);
        expect(data['destination'], route.destination);
        expect(data['price'], route.price);
      });

      test('publicar dos rutas distintas crea dos documentos', () async {
        final route1 = buildFakeRoute();
        final route2 = route1.copyWith(
          origin: 'Ocaña',
          destination: 'Cúcuta',
        );
        await routeService.publishRoute(route1);
        await routeService.publishRoute(route2);
        final snapshot = await _fakeFirestore!.collection('routes').get();
        expect(snapshot.docs.length, 2);
      });
    });
  });
}