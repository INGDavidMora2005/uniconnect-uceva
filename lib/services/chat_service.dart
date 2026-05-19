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
    required String receiverId,
    required String text,
    String collectionName = 'chats',
  }) async {
    try {
      if (text.trim().isEmpty) {
        return 'error:vacio';
      }
      if (text.length > 500) {
        return 'error:muy_largo';
      }

      // Verificar que el chat no esté cerrado
      final chatDoc = await _db.collection(collectionName).doc(chatId).get();
      if (!chatDoc.exists) {
        return 'error:chat_no_existe';
      }
      // Solo verificar isClosed si es un chat de ruta
      if (collectionName == 'chats') {
        final chat = ChatModel.fromFirestore(chatDoc);
        if (chat.isClosed) {
          return 'error:chat_cerrado';
        }
      }

      // Guardar mensaje en la subcolección messages
      final messageRef = _db
          .collection(collectionName)
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

await messageRef.set({
         ...message.toMap(),
         'receiverId': receiverId,
       });

       // Actualizar el documento padre con el último mensaje
       await _db.collection(collectionName).doc(chatId).update({
         'lastMessage': text,
         'lastMessageAt': FieldValue.serverTimestamp(),
       });

       return 'ok';
    } catch (e) {
      return 'error:$e';
    }
  }

  // ─────────────────────────────────────────────
  // 3. Marcar mensajes como recibidos
  // ─────────────────────────────────────────────
  Future<void> markMessagesAsReceived({
    required String chatId,
    required String currentUserId,
    String collectionName = 'chats',
  }) async {
    try {
      final undelivered = await _db
          .collection(collectionName)
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('status', isEqualTo: 'sent')
          .get();

      if (undelivered.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in undelivered.docs) {
        batch.update(doc.reference, {'status': 'received'});
      }
      await batch.commit();
    } catch (e) {
      // Ignorar para no bloquear la UI
    }
  }

  // ─────────────────────────────────────────────
  // 4. Marcar mensajes como leídos
  // ─────────────────────────────────────────────
  Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUserId,
    String collectionName = 'chats',
  }) async {
    try {
      final unreadMessages = await _db
          .collection(collectionName)
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
  // 5. Stream de mensajes de un chat
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> messagesStream(
    String chatId, {
    String collectionName = 'chats',
  }) {
    return _db
        .collection(collectionName)
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // 6. Streams de chats del usuario
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
  // 7. Cerrar chat
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

  // ─────────────────────────────────────────────
  // 10. Eliminar chat para el usuario actual (soft delete)
  // ─────────────────────────────────────────────
  Future<String> deleteForUser(String chatId, String uid, {String collectionName = 'chats'}) async {
    try {
      await _db.collection(collectionName).doc(chatId).update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
      return 'ok';
    } catch (e) {
      return 'Error al eliminar chat: $e';
    }
  }

  // ─────────────────────────────────────────────
  // 8. Obtener o crear un chat directo entre dos usuarios
  // ─────────────────────────────────────────────
  Future<String> getOrCreateDirectChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    try {
      // IDs ordenados alfabéticamente para generar un chatId único
      final ids = [currentUserId, otherUserId]..sort();
      final chatId = ids.join('_');

      // Verificar si el chat directo ya existe
      final chatDoc =
          await _db.collection('direct_chats').doc(chatId).get();
      if (chatDoc.exists) {
        return chatId;
      }

      // Determinar user1 y user2 por orden alfabético de IDs
      final user1Id = ids[0];
      final user2Id = ids[1];
      final user1Name =
          user1Id == currentUserId ? currentUserName : otherUserName;
      final user2Name =
          user2Id == currentUserId ? currentUserName : otherUserName;

      await _db.collection('direct_chats').doc(chatId).set({
        'user1Id':       user1Id,
        'user2Id':       user2Id,
        'user1Name':     user1Name,
        'user2Name':     user2Name,
        'createdAt':     FieldValue.serverTimestamp(),
        'lastMessage':   null,
        'lastMessageAt': null,
        'adminVisible':  true,
      });
      return chatId;
    } catch (e) {
      return 'error:$e';
    }
  }

  // ─────────────────────────────────────────────
  // 9. Streams de chats directos del usuario
  // ─────────────────────────────────────────────

  /// Chats directos donde el usuario es user1
  Stream<QuerySnapshot> user1DirectChatsStream(String userId) {
    return _db
        .collection('direct_chats')
        .where('user1Id', isEqualTo: userId)
        .snapshots();
  }

  /// Chats directos donde el usuario es user2
  Stream<QuerySnapshot> user2DirectChatsStream(String userId) {
    return _db
        .collection('direct_chats')
        .where('user2Id', isEqualTo: userId)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // PRESENCIA EN TIEMPO REAL
  // ─────────────────────────────────────────────

  /// Actualiza presencia del usuario actual
  Future<void> updatePresence(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Stream para escuchar presencia de otro usuario
  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data() ?? {};
      return {
        'isOnline': data['isOnline'] ?? false,
        'lastSeen': data['lastSeen'],
      };
    });
  }
}