import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/ai_bot_service.dart';

class AiBotChatScreen extends StatefulWidget {
  const AiBotChatScreen({super.key});

  @override
  State<AiBotChatScreen> createState() => _AiBotChatScreenState();
}

class _AiBotChatScreenState extends State<AiBotChatScreen> {
  String _uid = '';
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isWaiting = false;
  bool _isClearingHistory = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiBotService _botService = AiBotService();

  @override
  void initState() {
    super.initState();
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      _uid = current.uid;
      _loadHistory();
    } else {
      FirebaseAuth.instance.authStateChanges().first.then((user) {
        if (user != null && mounted) {
          setState(() => _uid = user.uid);
          _loadHistory();
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (kDebugMode) {
      debugPrint('[AiBotChatScreen] _loadHistory called. uid: $_uid');
    }

    if (_uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final history = await _botService.loadHistory(_uid);

    if (kDebugMode) {
      debugPrint('[AiBotChatScreen] Loaded ${history.length} messages from history for uid: $_uid');
    }

    if (mounted) {
      setState(() {
        _messages = history;
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isWaiting) return;

    // Capturamos snapshot del historial ANTES de agregar el nuevo mensaje del usuario
    final historySnapshot = List<Map<String, dynamic>>.from(_messages);

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isWaiting = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Guardamos el mensaje del usuario lo antes posible (incluso si el usuario sale de la pantalla)
    if (kDebugMode) {
      debugPrint('[AiBotChatScreen] Persisting user message for uid: $_uid');
    }
    try {
      await _botService.persistUserMessage(_uid, text);
    } catch (_) {}

    final response = await _botService.sendMessage(
      uid: _uid,
      userMessage: text,
      conversationHistory: historySnapshot,
    );

    if (mounted) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': response});
        _isWaiting = false;
      });
    }

    // Guardamos la respuesta del asistente
    if (kDebugMode) {
      debugPrint('[AiBotChatScreen] Persisting assistant message for uid: $_uid');
    }
    try {
      await _botService.persistAssistantMessage(_uid, response);
    } catch (_) {}

    _scrollToBottom();
  }

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

  void _showClearHistoryDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Borrar historial de UniBot'),
          content: const Text(
            'Se eliminará permanentemente todo el historial de conversaciones con UniBot.\n\nEsta acción no se puede deshacer.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: _isClearingHistory
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _clearHistory();
                    },
              child: const Text(
                'Borrar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearHistory() async {
    if (_isClearingHistory || _uid.isEmpty) return;

    setState(() => _isClearingHistory = true);

    final success = await _botService.clearHistory(_uid);

    if (!mounted) return;

    if (success) {
      setState(() {
        _messages.clear();
        _isClearingHistory = false;
      });
      if (kDebugMode) {
        debugPrint('[AiBotChatScreen] Historial de UniBot borrado exitosamente');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial borrado')),
      );
    } else {
      setState(() => _isClearingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al borrar el historial')),
      );
    }
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
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryGreen, AppColors.accentGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UniBot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Asistente IA',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            tooltip: 'Opciones',
            onSelected: (value) {
              if (value == 'clear_history') {
                _showClearHistoryDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Borrar historial'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: (_messages.isEmpty && !_isWaiting) ? 1 : _messages.length + (_isWaiting ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_messages.isEmpty && !_isWaiting) {
                        return _buildWelcomeBubble();
                      }

                      if (index < _messages.length) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        final text = msg['text'] as String? ?? '';
                        final bool isTruncated = !isUser && text.contains(AiBotService.truncatedSuffix.trim());

                        return _buildMessageBubble(
                          text,
                          isUser,
                          onContinue: isTruncated
                              ? () {
                                  _messageController.text = 'continúa la respuesta anterior';
                                  _sendMessage();
                                }
                              : null,
                        );
                      } else {
                        return _buildTypingIndicator();
                      }
                    },
                  ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildWelcomeBubble() {
    const welcomeText =
        '¡Hola! Soy UniBot 🤖 Tu asistente en UniConnect UCEVA.\n\nPuedes preguntarme:\n• ¿Hay rutas cerca de donde estoy?\n• ¿Qué productos hay en el bazar?\n• ¿Cuáles son las rutas más baratas?\n\n¿En qué te ayudo hoy?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                welcomeText,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, {VoidCallback? onContinue}) {
    final bool isTruncated = !isUser && text.contains(AiBotService.truncatedSuffix.trim());

    final String displayText = isTruncated
        ? text.replaceFirst(AiBotService.truncatedSuffix.trim(), '').trim()
        : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryGreen
                        : Colors.grey.shade100,
                    borderRadius: isUser
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                  ),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser ? Colors.white : AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onContinue != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: TextButton(
                onPressed: onContinue,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Continuar respuesta →',
                  style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ThreeDotsIndicator(),
                const SizedBox(height: 2),
                Text(
                  'Pensando...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    final canSend = _messageController.text.trim().isNotEmpty && !_isWaiting;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              enabled: !_isWaiting,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta para UniBot...',
                hintStyle: const TextStyle(color: AppColors.textPlaceholder),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppColors.accentGreen, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: canSend ? AppColors.primaryGreen : AppColors.borderDefault,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isWaiting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
              onPressed: canSend ? _sendMessage : null,
              tooltip: 'Enviar',
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDotsIndicator extends StatefulWidget {
  const _ThreeDotsIndicator();

  @override
  State<_ThreeDotsIndicator> createState() => _ThreeDotsIndicatorState();
}

class _ThreeDotsIndicatorState extends State<_ThreeDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t * 3 - i).clamp(0.0, 1.0);
            final opacity = 0.3 + (0.7 * (1 - (phase - phase.floor()).abs()));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: const Text(
                  '●',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
