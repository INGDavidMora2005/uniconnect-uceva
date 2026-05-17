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

    group('getAvailableRoutes', () {
      test('retorna lista vacía cuando no hay rutas', () async {
        final routes = await routeService.getAvailableRoutes().first;
        expect(routes, isEmpty);
      });

      test('retorna rutas con status Activa', () async {
        await routeService.publishRoute(buildFakeRoute());
        final routes = await routeService.getAvailableRoutes().first;
        expect(routes.length, 1);
      });

      test('no retorna rutas con status Finalizada', () async {
        await routeService.publishRoute(buildFakeRoute());
        await routeService.publishRoute(buildFakeRoute().copyWith(
          status: RouteStatus.finalizada,
        ));
        final routes = await routeService.getAvailableRoutes().first;
        expect(routes.length, 1);
      });

      test('retorna múltiples rutas disponibles', () async {
        await routeService.publishRoute(buildFakeRoute());
        await routeService.publishRoute(buildFakeRoute().copyWith(
          origin: 'Ocaña',
          destination: 'Cúcuta',
        ));
        await routeService.publishRoute(buildFakeRoute().copyWith(
          origin: 'Bucaramanga',
          destination: 'Medellín',
        ));
        final routes = await routeService.getAvailableRoutes().first;
        expect(routes.length, 3);
      });
    });

    group('closeRoute', () {
      test('actualiza el status de la ruta a Finalizada', () async {
        await routeService.publishRoute(buildFakeRoute());
        final snap = await _fakeFirestore!.collection('routes').get();
        final routeId = snap.docs.first.id;
        await routeService.updateRouteStatus(routeId, RouteStatus.finalizada);
        final updatedSnap = await _fakeFirestore!.collection('routes').doc(routeId).get();
        expect(updatedSnap.data()?['status'], RouteStatus.finalizada);
      });

      test('retorna ok al cerrar una ruta existente', () async {
        await routeService.publishRoute(buildFakeRoute());
        final snap = await _fakeFirestore!.collection('routes').get();
        final routeId = snap.docs.first.id;
        final result = await routeService.updateRouteStatus(routeId, RouteStatus.finalizada);
        expect(result, 'ok');
      });

      test('una ruta cerrada no aparece en getAvailableRoutes', () async {
        await routeService.publishRoute(buildFakeRoute());
        final snap = await _fakeFirestore!.collection('routes').get();
        final routeId = snap.docs.first.id;
        await routeService.updateRouteStatus(routeId, RouteStatus.finalizada);
        final routes = await routeService.getAvailableRoutes().first;
        expect(routes, isEmpty);
      });
    });
  });
}