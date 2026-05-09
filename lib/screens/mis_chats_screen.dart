import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Pantalla que lista todos los chats del usuario actual, tanto como
/// conductor como pasajero. Combina dos streams separados porque
/// rxdart no está disponible como dependencia.
class MisChatsScreen extends StatefulWidget {
  const MisChatsScreen({super.key});

  @override
  State<MisChatsScreen> createState() => _MisChatsScreenState();
}

class _MisChatsScreenState extends State<MisChatsScreen> {
  final _chatService = ChatService();

  // UID del usuario autenticado
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // Almacén local de chats combinados
  final Map<String, QueryDocumentSnapshot> _chatsMap = {};
  final StreamController<List<QueryDocumentSnapshot>>
      _combinedController =
      StreamController<List<QueryDocumentSnapshot>>.broadcast();

  StreamSubscription? _driverSub;
  StreamSubscription? _passengerSub;

  @override
  void initState() {
    super.initState();
    _listenToChats();
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _passengerSub?.cancel();
    _combinedController.close();
    super.dispose();
  }

  /// Escucha los dos streams por separado y los combina en uno solo
  void _listenToChats() {
    // Stream de chats donde el usuario es conductor
    _driverSub =
        _chatService.driverChatsStream(_uid).listen(
      (snapshot) {
        _updateChats(driverDocs: snapshot.docs);
      },
      onError: (error) {
        // Log error pero no romper la UI
        debugPrint('Error en driverChatsStream: $error');
      },
    );

    // Stream de chats donde el usuario es pasajero
    _passengerSub =
        _chatService.passengerChatsStream(_uid).listen(
      (snapshot) {
        _updateChats(passengerDocs: snapshot.docs);
      },
      onError: (error) {
        debugPrint('Error en passengerChatsStream: $error');
      },
    );
  }

  /// Actualiza el mapa local de chats y emite la lista combinada
  void _updateChats({
    List<QueryDocumentSnapshot>? driverDocs,
    List<QueryDocumentSnapshot>? passengerDocs,
  }) {
    // Remover chats que ya no existen en la nueva emisión
    // (identificados por los que ya no aparecen)
    if (driverDocs != null) {
      final driverIds = driverDocs.map((d) => d.id).toSet();
      _chatsMap.removeWhere((id, _) =>
          _chatsMap[id] != null && !driverIds.contains(id));
      for (final doc in driverDocs) {
        _chatsMap[doc.id] = doc;
      }
    }
    if (passengerDocs != null) {
      final passengerIds =
          passengerDocs.map((d) => d.id).toSet();
      // No remover chats que vinieron del driver stream
      // Solo actualizar/add
      for (final doc in passengerDocs) {
        _chatsMap[doc.id] = doc;
      }
    }

    // Ordenar por fecha de creación, más reciente primero
    final sorted = _chatsMap.values.toList();
    sorted.sort((a, b) {
      final aCreated =
          (a.data() as Map<String, dynamic>)['createdAt'];
      final bCreated =
          (b.data() as Map<String, dynamic>)['createdAt'];
      if (aCreated is Timestamp && bCreated is Timestamp) {
        return bCreated.compareTo(aCreated);
      }
      return 0;
    });

    if (!_combinedController.isClosed) {
      _combinedController.add(sorted);
    }
  }

  /// Navegar a la pantalla de chat
  void _navigateToChat(BuildContext context, ChatModel chat) {
    // Determinar el nombre del otro usuario y la info de la ruta
    final otherUserName = chat.driverId == _uid
        ? chat.passengerName
        : chat.driverName;
    final routeInfo = '${chat.origin} → ${chat.destination}';

    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'chatId': chat.id,
        'otherUserName': otherUserName,
        'routeInfo': routeInfo,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Mis chats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: _uid.isEmpty
          ? const Center(
              child: Text('Usuario no autenticado'),
            )
          : StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _combinedController.stream,
              builder: (context, combinedSnapshot) {
                if (!combinedSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final chats = combinedSnapshot.data!;

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes chats activos',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chatDoc = chats[index];
                    final chat = ChatModel.fromFirestore(chatDoc);

                    // Determinar el nombre del otro participante
                    final otherName = chat.driverId == _uid
                        ? chat.passengerName
                        : chat.driverName;
                    final routeInfo =
                        '${chat.origin} → ${chat.destination}';

                    return _ChatTile(
                      otherUserName: otherName,
                      routeInfo: routeInfo,
                      isClosed: chat.isClosed,
                      onTap: () => _navigateToChat(context, chat),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Widget auxiliar que muestra un ítem de chat en la lista.
class _ChatTile extends StatelessWidget {
  final String otherUserName;
  final String routeInfo;
  final bool isClosed;
  final VoidCallback onTap;

  const _ChatTile({
    required this.otherUserName,
    required this.routeInfo,
    required this.isClosed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isClosed ? null : onTap,
      leading: CircleAvatar(
        backgroundColor: isClosed
            ? AppColors.textLight
            : AppColors.accentGreen,
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 24,
        ),
      ),
      title: Text(
        otherUserName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: isClosed
              ? AppColors.textLight
              : AppColors.textDark,
        ),
      ),
      subtitle: Text(
        routeInfo,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMedium,
        ),
      ),
      trailing: isClosed
          ? const Icon(
              Icons.lock_outline,
              size: 20,
              color: AppColors.textLight,
            )
          : const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textLight,
            ),
    );
  }
}