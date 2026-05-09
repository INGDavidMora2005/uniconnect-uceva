import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/cupo_request_model.dart';

class ChatService {
  // Singleton
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // 1. Obtener o crear un chat
  // ─────────────────────────────────────────────
  Future<String> getOrCreateChat({
    required String routeId,
    required String passengerId,
    required String driverId,
    required String passengerName,
    required String driverName,
    required String origin,
    required String destination,
  }) async {
    try {
      final chatId = '${routeId}_$passengerId';

      // Verificar que exista un cupo aceptado para esta ruta y pasajero
      final cupoQuery = await _db
          .collection('cupo_requests')
          .where('routeId', isEqualTo: routeId)
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (cupoQuery.docs.isEmpty) {
        return 'error:sin_cupo';
      }

      // Verificar si el chat ya existe
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        return chatId;
      }

      // Crear el documento del chat
      final chat = ChatModel(
        id:            chatId,
        routeId:       routeId,
        driverId:      driverId,
        passengerId:   passengerId,
        passengerName: passengerName,
        driverName:    driverName,
        origin:        origin,
        destination:   destination,
        isClosed:      false,
        createdAt:     DateTime.now(),
        adminVisible:  true,
      );

      await _db.collection('chats').doc(chatId).set(chat.toMap());
      return chatId;
    } catch (e) {
      return 'error:$e';
    }
  }

  // ─────────────────────────────────────────────
  // 2. Enviar mensaje
  // ─────────────────────────────────────────────
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) {
        return 'error:vacio';
      }
      if (text.length > 500) {
        return 'error:muy_largo';
      }

      // Verificar que el chat no esté cerrado
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        return 'error:chat_no_existe';
      }
      final chat = ChatModel.fromFirestore(chatDoc);
      if (chat.isClosed) {
        return 'error:chat_cerrado';
      }

      // Guardar mensaje en la subcolección messages
      final messageRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final message = MessageModel(
        id:        messageRef.id,
        senderId:  senderId,
        text:      text,
        sentAt:    DateTime.now(),
        status:    'sent',
      );

      await messageRef.set(message.toMap());
      return 'ok';
    } catch (e) {
      return 'error:$e';
    }
  }

  // ─────────────────────────────────────────────
  // 3. Marcar mensajes como leídos
  // ─────────────────────────────────────────────
  Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    try {
      // Query: mensajes donde senderId != currentUserId AND status != 'read'
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('status', isNotEqualTo: 'read')
          .get();

      if (unreadMessages.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      // Ignorar errores de lectura para no bloquear la UI
    }
  }

  // ─────────────────────────────────────────────
  // 4. Stream de mensajes de un chat
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // 5. Streams de chats del usuario
  // NOTA: rxdart no está disponible, por lo que se exponen dos streams
  // separados. La pantalla los combina en el UI.
  // ─────────────────────────────────────────────

  /// Chats donde el usuario es el conductor
  Stream<QuerySnapshot> driverChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('driverId', isEqualTo: userId)
        .snapshots();
  }

  /// Chats donde el usuario es el pasajero
  Stream<QuerySnapshot> passengerChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('passengerId', isEqualTo: userId)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // 6. Cerrar chat
  // ─────────────────────────────────────────────
  Future<void> closeChat(String chatId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .update({
            'isClosed':     true,
            'closedAt':     FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // Manejar error
    }
  }
}