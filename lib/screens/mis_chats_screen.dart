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

  // Cache de últimos mensajes para evitar llamadas redundantes a Firestore
  final Map<String, String> _lastMessageCache = {};

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

  /// Escucha la URL de la foto de perfil del usuario en tiempo real
  Stream<String?> _watchProfileImageUrl(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data()?['profileImageUrl'] as String?;
    });
  }

  /// Obtiene el último mensaje de un chat
  Future<String> _getLastMessage(String chatId) async {
    if (_lastMessageCache.containsKey(chatId)) {
      return _lastMessageCache[chatId]!;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _lastMessageCache[chatId] = 'Sin mensajes aún';
        return 'Sin mensajes aún';
      }
      final text = snap.docs.first.data()['text'] as String? ??
          'Sin mensajes aún';
      _lastMessageCache[chatId] = text;
      return text;
    } catch (_) {
      _lastMessageCache[chatId] = 'Sin mensajes aún';
      return 'Sin mensajes aún';
    }
  }

  /// Escucha el nombre del otro usuario en tiempo real
  Stream<String> _watchOtherUserName(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 'Usuario';
      final data = doc.data();
      return data?['fullName'] as String? ??
          data?['name'] as String? ??
          data?['displayName'] as String? ??
          'Usuario';
    });
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

  /// Muestra el bottom sheet para eliminar un chat
  void _showChatOptions(BuildContext context, ChatModel chat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Eliminar chat',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Solo se eliminará para ti'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Eliminar chat'),
                    content: const Text(
                      '¿Quieres eliminar este chat? Solo desaparecerá para ti.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _chatService.deleteForUser(
                    chatId: chat.id,
                    userId: _uid,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text(
              'Chats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _combinedController.stream,
              builder: (context, snapshot) {
                final count = snapshot.hasData
                    ? snapshot.data!.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedFor =
                            (data['deletedFor'] as List<dynamic>?) ?? [];
                        if (deletedFor.contains(_uid)) return false;
                        final chat = ChatModel.fromFirestore(doc);
                        return !chat.isClosed;
                      }).length
                    : 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _uid.isEmpty
          ? const Center(
              child: Text('Usuario no autenticado'),
            )
          : Column(
              children: [
                // ── Buscador ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                          color: AppColors.accentGreen,
                          size: 22,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // ── Lista de chats ──
                Expanded(
                  child: StreamBuilder<List<QueryDocumentSnapshot>>(
                    stream: _combinedController.stream,
                    builder: (context, combinedSnapshot) {
                      if (!combinedSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      // Filtrar chats donde el _uid no esté en deletedFor
                      final allDocs = combinedSnapshot.data!;
                      final activeDocs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedFor =
                            (data['deletedFor'] as List<dynamic>?) ?? [];
                        return !deletedFor.contains(_uid);
                      }).toList();

                      // Filtrar chats por nombre del otro usuario
                      final filteredChats = _searchQuery.isEmpty
                          ? activeDocs
                          : activeDocs.where((chatDoc) {
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
                                Icons.forum_outlined,
                                size: 72,
                                color: AppColors.accentGreen,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin chats activos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cuando reserves un cupo aparecerá aquí tu chat',
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

                          final otherUserId = chat.driverId == _uid
                              ? chat.passengerId
                              : chat.driverId;
                          final routeInfo =
                              '${chat.origin} → ${chat.destination}';

                          return Column(
                            children: [
                              StreamBuilder<String>(
                                stream: _watchOtherUserName(otherUserId),
                                builder: (context, nameSnap) {
                                  final realName = nameSnap.data ??
                                      (chat.driverId == _uid
                                          ? chat.passengerName
                                          : chat.driverName);
                                  return StreamBuilder<String?>(
                                    stream:
                                        _watchProfileImageUrl(otherUserId),
                                    builder: (context, imgSnap) {
                                      return FutureBuilder<String>(
                                        future: _getLastMessage(chat.id),
                                        builder: (context, msgSnap) {
                                          return StreamBuilder<
                                              DocumentSnapshot>(
                                            stream: FirebaseFirestore
                                                .instance
                                                .collection('chats')
                                                .doc(chat.id)
                                                .snapshots(),
                                            builder: (context,
                                                chatSnap) {
                                              final isClosedRealTime =
                                                  chatSnap.hasData
                                                      ? ((chatSnap.data!
                                                                  .data()
                                                              as Map<
                                                                      String,
                                                                      dynamic>?)
                                                                  ?[
                                                              'isClosed'] ??
                                                          false)
                                                      : chat.isClosed;
                                              return _ChatTile(
                                                otherUserName: realName,
                                                profileImageUrl:
                                                    imgSnap.data,
                                                lastMessage:
                                                    msgSnap.data ??
                                                        'Sin mensajes aún',
                                                routeInfo: routeInfo,
                                                isClosed: isClosedRealTime,
                                                createdAt: chat.createdAt,
                                                onTap: () =>
                                                    _navigateToChat(
                                                        context, chat),
                                                onLongPress: () =>
                                                    _showChatOptions(
                                                        context, chat),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              if (index < filteredChats.length - 1)
                                const Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 70,
                                  color: Color(0xFFE8E8E8),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Widget auxiliar que muestra un ítem de chat en la lista.
class _ChatTile extends StatelessWidget {
  final String otherUserName;
  final String? profileImageUrl;
  final String lastMessage;
  final String routeInfo;
  final bool isClosed;
  final DateTime createdAt;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChatTile({
    required this.otherUserName,
    this.profileImageUrl,
    required this.lastMessage,
    required this.routeInfo,
    required this.isClosed,
    required this.createdAt,
    required this.onTap,
    this.onLongPress,
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
      onLongPress: isClosed ? null : onLongPress,
      splashColor: AppColors.accentGreen.withValues(alpha: 0.08),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar circular con gradiente verde y foto de perfil
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.accentGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.transparent,
                  backgroundImage: profileImageUrl != null &&
                          profileImageUrl!.isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: profileImageUrl == null || profileImageUrl!.isEmpty
                      ? Text(
                          otherUserName.isNotEmpty
                              ? otherUserName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: nombre + hora
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: isClosed
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Fila inferior: último mensaje + badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMedium,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge de Activo o Cerrado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClosed
                                ? Colors.grey.shade400
                                : AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isClosed ? 'Cerrado' : 'Activo',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}