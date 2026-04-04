import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cupo_request_model.dart';
import 'notification_service.dart';

class CupoService {
  final _db = FirebaseFirestore.instance;

  Future<String> requestSeat({
    required String routeId,
    required String passengerId,
    required String passengerName,
    required String driverId,
    required String message,
    required String origin,
    required String destination,
    required String time,
  }) async {
    try {
      final existing = await _db
          .collection('cupo_requests')
          .where('routeId', isEqualTo: routeId)
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        return 'Ya tienes una solicitud pendiente para esta ruta.';
      }

      final routeDoc = await _db.collection('routes').doc(routeId).get();
      if (!routeDoc.exists) return 'La ruta no existe.';
      final seats = (routeDoc.data()?['availableSeats'] ?? 0) as int;
      if (seats <= 0) return 'Ya no hay cupos disponibles.';

      final request = CupoRequestModel(
        id:            '',
        routeId:       routeId,
        passengerId:   passengerId,
        passengerName: passengerName,
        driverId:      driverId,
        message:       message,
        status:        'pending',
        origin:        origin,
        destination:   destination,
        time:          time,
        createdAt:     DateTime.now(),
      );
      final requestRef = await _db.collection('cupo_requests').add(request.toMap());

      await NotificationService().saveNotification(
        toUserId: driverId,
        title:    'Solicitud de cupo recibida',
        body:     '$passengerName solicitó un cupo en la ruta $origin → $destination · $time',
        type:     'cupo_request',
        extra: {
          'requestId':     requestRef.id,
          'routeId':       routeId,
          'passengerId':   passengerId,
          'passengerName': passengerName,
          'origin':        origin,
          'destination':   destination,
          'time':          time,
        },
      );

      return 'ok';
    } catch (e) {
      return 'Error al enviar la solicitud: $e';
    }
  }

  Future<void> respondToRequest({
    required String requestId,
    required String routeId,
    required String passengerId,
    required String passengerName,
    required String origin,
    required String destination,
    required bool accepted,
  }) async {
    try {
      final batch = _db.batch();
      final requestRef = _db.collection('cupo_requests').doc(requestId);
      final routeRef   = _db.collection('routes').doc(routeId);

      batch.update(requestRef, {'status': accepted ? 'accepted' : 'rejected'});

      if (accepted) {
        batch.update(routeRef, {
          'availableSeats': FieldValue.increment(-1),
        });
      }

      await batch.commit();

      if (accepted) {
        final updatedRoute = await routeRef.get();
        final seatsLeft = (updatedRoute.data()?['availableSeats'] ?? 0) as int;

        if (seatsLeft <= 0) {
          await routeRef.update({'status': 'Llena'});

          final pendingRequests = await _db
              .collection('cupo_requests')
              .where('routeId', isEqualTo: routeId)
              .where('status', isEqualTo: 'pending')
              .get();

          for (final doc in pendingRequests.docs) {
            final data = doc.data();
            await doc.reference.update({'status': 'rejected'});
            await NotificationService().saveNotification(
              toUserId: data['passengerId'] ?? '',
              title:    'Ruta sin cupos disponibles',
              body:     'Lo sentimos, la ruta $origin → $destination se llenó antes de que tu solicitud fuera procesada.',
              type:     'cupo_rejected',
              extra: {
                'routeId':     routeId,
                'origin':      origin,
                'destination': destination,
              },
            );
          }
        }
      }

      await NotificationService().saveNotification(
        toUserId: passengerId,
        title:    accepted ? '¡Cupo aceptado!' : 'Solicitud rechazada',
        body:     accepted
            ? 'Tu solicitud en la ruta $origin → $destination fue aceptada. ¡Buen viaje!'
            : 'Tu solicitud en la ruta $origin → $destination fue rechazada por el conductor.',
        type:  accepted ? 'cupo_accepted' : 'cupo_rejected',
        extra: {
          'routeId':     routeId,
          'origin':      origin,
          'destination': destination,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> hasPendingOrAcceptedRequest(String passengerId, String routeId) async {
    final query = await _db
        .collection('cupo_requests')
        .where('passengerId', isEqualTo: passengerId)
        .where('routeId', isEqualTo: routeId)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();
    return query.docs.isNotEmpty;
  }

  Stream<QuerySnapshot> pendingRequestsStream(String driverId) {
    return _db
        .collection('cupo_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}