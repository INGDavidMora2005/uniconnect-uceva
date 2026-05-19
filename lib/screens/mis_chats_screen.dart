import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import 'buscar_usuario_screen.dart';
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

  // UID del usuario autenticado — se fija en initState para evitar
  // que un getter devuelva '' si Firebase Auth aún no cargó.
  String _uid = '';

  // Almacén local de chats combinados
  final Map<String, QueryDocumentSnapshot> _chatsMap = {};
  final StreamController<List<QueryDocumentSnapshot>>
      _combinedController =
      StreamController<List<QueryDocumentSnapshot>>.broadcast();

  StreamSubscription? _driverSub;
  StreamSubscription? _passengerSub;
  StreamSubscription? _directSub;  // stream unificado de direct_chats
  StreamSubscription? _authSub;

  // Texto de búsqueda para filtrar chats
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Esperar a que Firebase Auth confirme el usuario antes de suscribirse
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _uid = currentUser.uid;
      _listenToChats();
    } else {
      // Si aún no hay usuario, esperar el primer evento de auth
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && _uid.isEmpty) {
          _uid = user.uid;
          _listenToChats();
          _authSub?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _driverSub?.cancel();
    _passengerSub?.cancel();
    _directSub?.cancel();
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

    // Stream unificado de chats directos (usa arrayContains en 'participants')
    _directSub =
        _chatService.directChatsStream(_uid).listen(
      (snapshot) {
        _updateChats(directChatsUser1Docs: snapshot.docs);
      },
      onError: (error) {
        debugPrint('Error en directChatsStream: $error');
      },
    );
  }

  /// Actualiza el mapa local de chats y emite la lista combinada
  void _updateChats({
    List<QueryDocumentSnapshot>? driverDocs,
    List<QueryDocumentSnapshot>? passengerDocs,
    List<QueryDocumentSnapshot>? directChatsUser1Docs,
  }) {
    if (driverDocs != null) {
      for (final doc in driverDocs) {
        _chatsMap[doc.id] = doc;
      }
    }
    if (passengerDocs != null) {
      for (final doc in passengerDocs) {
        _chatsMap[doc.id] = doc;
      }
    }
    if (directChatsUser1Docs != null) {
      for (final doc in directChatsUser1Docs) {
        _chatsMap[doc.id] = doc;
      }
    }

    // Ordenar por último mensaje (tipo WhatsApp), con fallback a createdAt
    final sorted = _chatsMap.values.toList();
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTs = (aData['lastMessageAt'] ?? aData['createdAt']);
      final bTs = (bData['lastMessageAt'] ?? bData['createdAt']);
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      if (aTs is Timestamp) return -1;
      if (bTs is Timestamp) return 1;
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

  /// Construye el tile de un chat según su tipo (directo o de ruta)
  Widget _buildChatTile(BuildContext context, QueryDocumentSnapshot doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>;
    final String chatId = doc.id;

    // No mostrar chats eliminados, salvo que haya mensajes nuevos posteriores a la eliminación
    final deletedFor = List<String>.from(data['deletedFor'] ?? []);
    if (deletedFor.contains(currentUid)) {
      final isDirectChat2 = data.containsKey('user1Id') && data.containsKey('user2Id');
      if (isDirectChat2) {
        final deletedAt = data['deletedAt_$currentUid'] as Timestamp?;
        final lastMessageAt = data['lastMessageAt'] as Timestamp?;
        // Si hay mensaje nuevo posterior a la eliminación, mostrar el tile
        if (deletedAt != null && lastMessageAt != null &&
            lastMessageAt.compareTo(deletedAt) > 0) {
          // continuar y mostrar el tile
        } else {
          return const SizedBox.shrink();
        }
      } else {
        return const SizedBox.shrink();
      }
    }

    // Determinar si es un chat directo o de ruta
    bool isDirectChat = data.containsKey('user1Id') && data.containsKey('user2Id');
    String otherUserId = '';
    String otherUserName = '';
    String routeInfo = '';
    String collectionName = isDirectChat ? 'direct_chats' : 'chats';

    if (isDirectChat) {

      // Chat directo: user1Id, user2Id, user1Name, user2Name
      final String user1Id = data['user1Id'] as String? ?? '';
      final String user2Id = data['user2Id'] as String? ?? '';
      final String user1Name = data['user1Name'] as String? ?? '';
      final String user2Name = data['user2Name'] as String? ?? '';

      if (user1Id == currentUid) {
        otherUserId = user2Id;
        otherUserName = user2Name;
      } else if (user2Id == currentUid) {
        otherUserId = user1Id;
        otherUserName = user1Name;
      } else {
        otherUserId = user1Id;
        otherUserName = 'Usuario desconocido';
      }

      routeInfo = 'Chat directo';
    } else {
      // Chat de ruta: driverId, passengerId, origin, destination
      final String driverId = data['driverId'] as String? ?? '';
      final String passengerId = data['passengerId'] as String? ?? '';
      final String origin = data['origin'] as String? ?? '';
      final String destination = data['destination'] as String? ?? '';

      if (driverId == currentUid) {
        otherUserId = passengerId;
      } else {
        otherUserId = driverId;
      }

      routeInfo = '$origin → $destination';
    }

// Obtener el último mensaje
    return Column(
      children: [
        StreamBuilder<String>(
          stream: _watchOtherUserName(otherUserId),
          builder: (context, nameSnap) {
            final realName = nameSnap.data ?? otherUserName;
            return StreamBuilder<String?>(
              stream: _watchProfileImageUrl(otherUserId),
              builder: (context, imgSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(chatId)
                      .snapshots(),
                  builder: (context, chatSnap) {
                    final chatData = chatSnap.hasData
                        ? (chatSnap.data!.data() as Map<String, dynamic>?)
                        : null;
                    final isClosedRealTime =
                        chatData?['isClosed'] ?? false;
                    final lastMessageFromDoc =
                        (chatData?['lastMessage'] as String?) ?? '';
                    final displayMessage = lastMessageFromDoc.isNotEmpty
                        ? lastMessageFromDoc
                        : 'Sin mensajes aún';
                    final timestamp =
                        chatData?['lastMessageAt'] as Timestamp?;
                    final time = timestamp != null
                        ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                        : '';
                      return _ChatTile(
                        otherUserName: realName,
                        profileImageUrl: imgSnap.data,
                        lastMessage: displayMessage,
                        isLastMessageEmpty: lastMessageFromDoc.isEmpty,
                        routeInfo: routeInfo,
                        isClosed: isClosedRealTime,
                        lastMessageTime: time,
                        onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserName: realName,
                              otherUserId: otherUserId,
                              routeInfo: routeInfo,
                              isDirectChat: isDirectChat,
                              collectionName: collectionName,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _showChatOptions(
                          context, chatId, otherUserId, realName, routeInfo,
                          isDirectChat, collectionName),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
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

  /// Muestra el bottom sheet para eliminar un chat
   void _showChatOptions(
     BuildContext context,
     String chatId,
     String otherUserId,
     String otherUserName,
     String routeInfo,
     bool isDirectChat,
     String collectionName,
   ) {
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
                    final result = await ChatService().deleteForUser(
                      chatId,
                      _uid,
                      collectionName: isDirectChat ? 'direct_chats' : 'chats',
                    );
                    if (result == 'ok') {
                      setState(() => _chatsMap.remove(chatId));
                    }
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
                        final isDirectChat = data.containsKey('user1Id') && data.containsKey('user2Id');
                        if (deletedFor.contains(_uid)) {
                          if (isDirectChat) {
                            final deletedAt = data['deletedAt_$_uid'] as Timestamp?;
                            final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                            if (deletedAt != null && lastMessageAt != null &&
                                lastMessageAt.compareTo(deletedAt) > 0) {
                              return true;
                            }
                          }
                          return false;
                        }
                        if (isDirectChat) {
                          final u1 = data['user1Id'] as String? ?? '';
                          final u2 = data['user2Id'] as String? ?? '';
                          if (u1 != _uid && u2 != _uid) return false;
                        }
                        return true;
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
                Expanded(
                  child: StreamBuilder<List<QueryDocumentSnapshot>>(
                    stream: _combinedController.stream,
                    builder: (context, combinedSnapshot) {
                      if (!combinedSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final allDocs = combinedSnapshot.data!;
                      final activeDocs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedFor =
                            (data['deletedFor'] as List<dynamic>?) ?? [];
                        final isDirectChat = data.containsKey('user1Id') && data.containsKey('user2Id');

                        if (deletedFor.contains(_uid)) {
                          // Si el usuario eliminó el chat, solo mostrarlo si
                          // hay mensajes nuevos posteriores a cuando lo eliminó
                          if (isDirectChat) {
                            final deletedAt = data['deletedAt_$_uid'] as Timestamp?;
                            final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                            // Si hay un mensaje posterior a la eliminación, mostrar
                            if (deletedAt != null && lastMessageAt != null &&
                                lastMessageAt.compareTo(deletedAt) > 0) {
                              return true;
                            }
                          }
                          return false;
                        }

                        // Excluir chats directos donde el usuario no es participante
                        if (isDirectChat) {
                          final user1Id = data['user1Id'] as String? ?? '';
                          final user2Id = data['user2Id'] as String? ?? '';
                          if (user1Id != _uid && user2Id != _uid) return false;
                        }
                        return true;
                      }).toList();

                      final filteredChats = _searchQuery.isEmpty
                          ? activeDocs
                          : activeDocs.where((chatDoc) {
                              final data = chatDoc.data() as Map<String, dynamic>;
                              final isDirectChat = data.containsKey('user1Id');
                              final name = isDirectChat
                                  ? (data['user1Id'] == _uid ? data['user2Name'] : data['user1Name']) as String? ?? ''
                                  : '${data['origin'] ?? ''} ${data['destination'] ?? ''}';
                              return name.toLowerCase().contains(_searchQuery.toLowerCase());
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
                                'Reserva un cupo o inicia un chat directo con otro usuario',
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildChatTile(context, chatDoc, _uid),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1D9E75),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BuscarUsuarioScreen()),
        ),
      ),
    );
  }


}

/// Widget auxiliar que muestra un ítem de chat en la lista.
class _ChatTile extends StatelessWidget {
  final String otherUserName;
  final String? profileImageUrl;
  final String lastMessage;
  final bool isLastMessageEmpty;
  final String routeInfo;
  final bool isClosed;
  final String lastMessageTime;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChatTile({
    required this.otherUserName,
    this.profileImageUrl,
    required this.lastMessage,
    this.isLastMessageEmpty = false,
    required this.routeInfo,
    required this.isClosed,
    required this.lastMessageTime,
    required this.onTap,
    this.onLongPress,
  });

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
                          lastMessageTime,
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
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isLastMessageEmpty
                                  ? AppColors.textLight
                                  : AppColors.textMedium,
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