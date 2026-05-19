import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

/// Pantalla de conversación entre dos usuarios.
/// Soporta chat de rutas (isDirectChat=false) y chat directo (isDirectChat=true).
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final String routeInfo;
  final bool isDirectChat;
  final String collectionName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    required this.routeInfo,
    this.isDirectChat = false,
    this.collectionName = 'chats',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();

  // UID del usuario actual
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // Nombre del otro usuario (se actualiza en tiempo real)
  String _otherUserName = '';

  StreamSubscription? _nameSub;

  @override
  void initState() {
    super.initState();
    _otherUserName = widget.otherUserName;
    _markAsRead();
    // Solo escuchar si otherUserId no está vacío
    if (widget.otherUserId.isNotEmpty) {
      _nameSub = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        final name = data?['fullName'] as String? ??
            data?['name'] as String? ??
            data?['displayName'] as String? ??
            widget.otherUserName;
        if (mounted) setState(() => _otherUserName = name);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _nameSub?.cancel();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      await _chatService.markMessagesAsReceived(
        chatId: widget.chatId,
        currentUserId: _currentUserId,
        collectionName: widget.collectionName,
      );
      await _chatService.markMessagesAsRead(
        chatId: widget.chatId,
        currentUserId: _currentUserId,
        collectionName: widget.collectionName,
      );
    } catch (e) {
      // Ignorar errores para no bloquear la UI
    }
  }

  /// Scroll automático al último mensaje después de renderizar
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Enviar mensaje de texto
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final result = await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUserId,
      receiverId: widget.otherUserId,
      text: text,
      collectionName: widget.collectionName,
    );

    if (result == 'ok') {
      _messageController.clear();
      _scrollToBottom();
    } else if (result == 'error:chat_cerrado') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este chat está cerrado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else if (result != 'error:vacio' && result != 'error:muy_largo') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $result'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Construir ícono de estado del mensaje
  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'read':
        return Icon(Icons.done_all,
            size: 16, color: AppColors.accentGreen);
      case 'received':
        return Icon(Icons.done_all,
            size: 16, color: AppColors.textLight);
      case 'sent':
        return Icon(Icons.done,
            size: 16, color: AppColors.textLight);
      default:
        return Icon(Icons.done, size: 16, color: AppColors.textLight);
    }
  }

  /// Formatear hora en HH:mm
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otherUserName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            StreamBuilder<Map<String, dynamic>>(
              stream: _chatService.presenceStream(widget.otherUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    widget.routeInfo,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  );
                }
                final data = snapshot.data!;
                final isOnline = data['isOnline'] as bool? ?? false;
                final lastSeen = data['lastSeen'];
                
                String statusText;
                Color statusColor;
                if (isOnline) {
                  statusText = 'En línea';
                  statusColor = AppColors.accentGreen;
                } else if (lastSeen != null) {
                  final lastSeenDate = (lastSeen as Timestamp).toDate();
                  statusText = 'Última vez: ${lastSeenDate.hour.toString().padLeft(2, '0')}:${lastSeenDate.minute.toString().padLeft(2, '0')}';
                  statusColor = AppColors.textLight;
                } else {
                  statusText = 'Desconectado';
                  statusColor = AppColors.textLight;
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.routeInfo,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Stream para detectar si el chat está cerrado ──────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection(widget.collectionName)
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, chatSnapshot) {
              final isClosed =
                  chatSnapshot.hasData &&
                  (chatSnapshot.data!.data() as Map<String, dynamic>?)
                      ?['isClosed'] == true;

              return Expanded(
                child: Stack(
                  children: [
                    // ── Mensajes ──────────────────────────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: _chatService.messagesStream(
                        widget.chatId,
                        collectionName: widget.collectionName,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final messages = snapshot.data!.docs;

                        // Scroll al último mensaje cuando se reciben nuevos
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = MessageModel.fromFirestore(
                              messages[index],
                            );
                            final isMine =
                                msg.senderId == _currentUserId;

                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: 8),
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment:
                                    isMine
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                children: [
                                  // Nombre del remitente (solo para mensajes ajenos)
                                  if (!isMine)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                              bottom: 4, left: 4),
                                      child: Text(
                                        _otherUserName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMedium,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    constraints:
                                        BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.7),
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? AppColors.accentGreen
                                          : AppColors.backgroundWhite,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: isMine
                                          ? null
                                          : Border.all(
                                              color: AppColors
                                                  .borderDefault,
                                            ),
                                      boxShadow: isMine
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.04),
                                                blurRadius: 4,
                                                offset: const Offset(
                                                    0, 1),
                                              ),
                                            ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.text,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isMine
                                                ? Colors.white
                                                : AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTime(msg.sentAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMine
                                                    ? Colors.white70
                                                    : AppColors
                                                        .textLight,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            _buildStatusIcon(msg.status),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // ── Banner de chat cerrado ──────────────────────
                    if (isClosed)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8),
                          color: Colors.red.shade400,
                          child: const Center(
                            child: Text(
                              'Chat cerrado',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Input de mensaje ──────────────────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection(widget.collectionName)
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, chatSnapshot) {
              final isClosed =
                  chatSnapshot.hasData &&
                  (chatSnapshot.data!.data() as Map<String, dynamic>?)
                      ?['isClosed'] == true;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite,
                  border: Border(
                    top: BorderSide(
                        color: AppColors.borderDefault),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !isClosed,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: isClosed
                              ? 'Chat cerrado'
                              : 'Escribe un mensaje...',
                          hintStyle: TextStyle(
                            color: AppColors.textPlaceholder,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: AppColors.borderDefault),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: AppColors.borderDefault),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: AppColors.accentGreen,
                                width: 1.5),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: AppColors.borderDefault),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(isClosed),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Botón de enviar
  Widget _buildSendButton(bool isClosed) {
    final length = _messageController.text.length;
    final canSend = length > 0 && length <= 500 && !isClosed;

    return Container(
      decoration: BoxDecoration(
        color: canSend
            ? AppColors.primaryGreen
            : AppColors.borderDefault,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.send, size: 20, color: Colors.white),
        onPressed: canSend ? _sendMessage : null,
        tooltip: 'Enviar mensaje',
      ),
    );
  }
}