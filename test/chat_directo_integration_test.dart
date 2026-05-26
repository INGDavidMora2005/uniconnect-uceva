import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uniconnect_dev/services/chat_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ChatService chatService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    chatService = ChatService.withFirestore(fakeFirestore);
  });

  group('ChatService - Direct Chat Tests', () {
    test('getOrCreateDirectChat crea documento en direct_chats con campos correctos', () async {
      await fakeFirestore.collection('users').doc('user_a').set({
        'fullName': 'Usuario A',
        'email': 'user_a@test.com',
      });
      await fakeFirestore.collection('users').doc('user_b').set({
        'fullName': 'Usuario B',
        'email': 'user_b@test.com',
      });

      final chatId = await chatService.getOrCreateDirectChat(
        currentUserId: 'user_a',
        currentUserName: 'Usuario A',
        otherUserId: 'user_b',
        otherUserName: 'Usuario B',
      );

      expect(chatId, 'user_a_user_b');

      final chatDoc = await fakeFirestore.collection('direct_chats').doc(chatId).get();
      expect(chatDoc.exists, true);
      expect(chatDoc.data()?['user1Id'], 'user_a');
      expect(chatDoc.data()?['user2Id'], 'user_b');
      expect(chatDoc.data()?['user1Name'], 'Usuario A');
      expect(chatDoc.data()?['user2Name'], 'Usuario B');
      expect(chatDoc.data()?['adminVisible'], true);
    });

    test('getOrCreateDirectChat es idempotente con los mismos usuarios', () async {
      await fakeFirestore.collection('users').doc('user_a').set({'fullName': 'Usuario A'});
      await fakeFirestore.collection('users').doc('user_b').set({'fullName': 'Usuario B'});

      final chatId1 = await chatService.getOrCreateDirectChat(
        currentUserId: 'user_a',
        currentUserName: 'Usuario A',
        otherUserId: 'user_b',
        otherUserName: 'Usuario B',
      );

      final chatId2 = await chatService.getOrCreateDirectChat(
        currentUserId: 'user_a',
        currentUserName: 'Usuario A',
        otherUserId: 'user_b',
        otherUserName: 'Usuario B',
      );

      expect(chatId1, chatId2);

      final snapshot = await fakeFirestore.collection('direct_chats').get();
      expect(snapshot.docs.length, 1);
    });

    test('sendMessage guarda mensaje en subcolección messages con campos correctos', () async {
      final chatId = 'user_a_user_b';
      await fakeFirestore.collection('direct_chats').doc(chatId).set({
        'user1Id': 'user_a',
        'user2Id': 'user_b',
        'user1Name': 'Usuario A',
        'user2Name': 'Usuario B',
        'adminVisible': true,
      });

      final result = await chatService.sendMessage(
        chatId: chatId,
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Hola, ¿cómo estás?',
        collectionName: 'direct_chats',
      );

      expect(result, 'ok');

      final messages = await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .get();

      expect(messages.docs.length, 1);
      final msgData = messages.docs.first.data();
      expect(msgData['senderId'], 'user_a');
      expect(msgData['text'], 'Hola, ¿cómo estás?');
      expect(msgData['status'], 'sent');
    });

    test('sendMessage rechaza texto vacío', () async {
      final chatId = 'user_a_user_b';
      await fakeFirestore.collection('direct_chats').doc(chatId).set({
        'user1Id': 'user_a',
        'user2Id': 'user_b',
        'adminVisible': true,
      });

      final result = await chatService.sendMessage(
        chatId: chatId,
        senderId: 'user_a',
        receiverId: 'user_b',
        text: '   ',
        collectionName: 'direct_chats',
      );

      expect(result, 'error:vacio');
    });

    test('sendMessage rechaza texto de más de 500 caracteres', () async {
      final chatId = 'user_a_user_b';
      await fakeFirestore.collection('direct_chats').doc(chatId).set({
        'user1Id': 'user_a',
        'user2Id': 'user_b',
        'adminVisible': true,
      });

      final longText = 'a' * 501;
      final result = await chatService.sendMessage(
        chatId: chatId,
        senderId: 'user_a',
        receiverId: 'user_b',
        text: longText,
        collectionName: 'direct_chats',
      );

      expect(result, 'error:muy_largo');
    });

    test('markMessagesAsRead actualiza status solo en mensajes del otro usuario', () async {
      final chatId = 'user_a_user_b';
      await fakeFirestore.collection('direct_chats').doc(chatId).set({
        'user1Id': 'user_a',
        'user2Id': 'user_b',
        'adminVisible': true,
      });

      await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg1')
          .set({'senderId': 'user_a', 'text': 'Mensaje mío', 'status': 'sent'});
      await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg2')
          .set({'senderId': 'user_b', 'text': 'Mensaje del otro', 'status': 'sent'});
      await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg3')
          .set({'senderId': 'user_b', 'text': 'Otro mensaje', 'status': 'sent'});

      await chatService.markMessagesAsRead(
        chatId: chatId,
        currentUserId: 'user_a',
        collectionName: 'direct_chats',
      );

      final msg1 = await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg1')
          .get();
      expect(msg1.data()?['status'], 'sent');

      final msg2 = await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg2')
          .get();
      expect(msg2.data()?['status'], 'read');

      final msg3 = await fakeFirestore
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc('msg3')
          .get();
      expect(msg3.data()?['status'], 'read');
    });

    test('deleteForUser agrega uid al campo deletedFor', () async {
      final chatId = 'user_a_user_b';
      await fakeFirestore.collection('direct_chats').doc(chatId).set({
        'user1Id': 'user_a',
        'user2Id': 'user_b',
        'adminVisible': true,
      });

      expect(chatId, isNotNull);

      final result = await chatService.deleteForUser(
        chatId,
        'user_a',
        collectionName: 'direct_chats',
      );

      expect(result, 'ok');

      final chatDoc = await fakeFirestore.collection('direct_chats').doc(chatId).get();
      final deletedFor = chatDoc.data()?['deletedFor'] as List<dynamic>;
      expect(deletedFor.contains('user_a'), true);
    });
  });
}