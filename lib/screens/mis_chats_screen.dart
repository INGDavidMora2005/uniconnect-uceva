import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

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

  // Texto de búsqueda para filtrar chats
  String _searchQuery = '';

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
    if (driverDocs != null) {
      final driverIds = driverDocs.map((d) => d.id).toSet();
      _chatsMap.removeWhere((id, _) =>
          _chatsMap[id] != null && !driverIds.contains(id));
      for (final doc in driverDocs) {
        _chatsMap[doc.id] = doc;
      }
    }
    if (passengerDocs != null) {
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
    final otherUserName = chat.driverId == _uid
        ? chat.passengerName
        : chat.driverName;
    final otherUserId = chat.driverId == _uid
        ? chat.passengerId
        : chat.driverId;
    final routeInfo = '${chat.origin} → ${chat.destination}';

    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'chatId': chat.id,
        'otherUserName': otherUserName,
        'otherUserId': otherUserId,
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
        title: StreamBuilder<List<QueryDocumentSnapshot>>(
          stream: _combinedController.stream,
          builder: (context, snapshot) {
            final count = snapshot.hasData
                ? snapshot.data!.where((doc) {
                    final chat = ChatModel.fromFirestore(doc);
                    return !chat.isClosed;
                  }).length
                : 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$count chats activos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar chats...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textPlaceholder,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
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

                // Filtrar chats por nombre del otro usuario
                final filteredChats = _searchQuery.isEmpty
                    ? chats
                    : chats.where((chatDoc) {
                        final chat = ChatModel.fromFirestore(chatDoc);
                        final otherName = chat.driverId == _uid
                            ? chat.passengerName
                            : chat.driverName;
                        return otherName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                      }).toList();

                if (filteredChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: AppColors.accentGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aún no tienes chats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aquí aparecerán tus chats de rutas',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chatDoc = filteredChats[index];
                    final chat = ChatModel.fromFirestore(chatDoc);

                    final otherName = chat.driverId == _uid
                        ? chat.passengerName
                        : chat.driverName;
                    final routeInfo =
                        '${chat.origin} → ${chat.destination}';

                    return Column(
                      children: [
                        _ChatTile(
                          otherUserName: otherName,
                          routeInfo: routeInfo,
                          isClosed: chat.isClosed,
                          createdAt: chat.createdAt,
                          onTap: () => _navigateToChat(context, chat),
                        ),
                        if (index < filteredChats.length - 1)
                          const Divider(
                            height: 1,
                            indent: 80,
                            color: AppColors.borderDefault,
                          ),
                      ],
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
  final DateTime createdAt;
  final VoidCallback onTap;

  const _ChatTile({
    required this.otherUserName,
    required this.routeInfo,
    required this.isClosed,
    required this.createdAt,
    required this.onTap,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isClosed ? null : onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Avatar con iniciales
              CircleAvatar(
                radius: 26,
                backgroundColor: isClosed
                    ? AppColors.textLight
                    : AppColors.accentGreen,
                child: Text(
                  otherUserName.isNotEmpty
                      ? otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isClosed
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      routeInfo,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge de cerrado o flecha
              if (isClosed)
                Text(
                  'Cerrado',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}