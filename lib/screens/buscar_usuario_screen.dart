import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class BuscarUsuarioScreen extends StatefulWidget {
  const BuscarUsuarioScreen({super.key});

  @override
  State<BuscarUsuarioScreen> createState() => _BuscarUsuarioScreenState();
}

class _BuscarUsuarioScreenState extends State<BuscarUsuarioScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  List<UserModel> _results = [];
  bool _isLoading = false;
  String _currentUserId = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['fullName'] ?? data['name'] ?? '';
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(50)
          .get();

      final filtered = snapshot.docs
          .map((doc) => UserModel.fromMap({'id': doc.id, ...doc.data()}))
          .where((user) {
            final lowerQuery = query.toLowerCase();
            return user.id != _currentUserId &&
                (user.fullName.toLowerCase().contains(lowerQuery) ||
                    user.phone.toLowerCase().contains(lowerQuery));
          })
          .toList();

      setState(() {
        _results = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(UserModel user) async {
    if (_currentUserName.isEmpty) return;

    final chatId = await _chatService.getOrCreateDirectChat(
      currentUserId: _currentUserId,
      currentUserName: _currentUserName,
      otherUserId: user.id,
      otherUserName: user.fullName,
    );

    if (!mounted) return;

    if (chatId.startsWith('error:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear chat: $chatId')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: user.fullName,
          otherUserId: user.id,
          routeInfo: 'Chat directo',
          isDirectChat: true,
          collectionName: 'direct_chats',
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
        title: const Text(
          'Buscar usuario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o teléfono...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMedium),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron usuarios',
                          style: TextStyle(color: AppColors.textMedium, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            onTap: () => _startChat(user),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accentGreen,
                              child: Text(
                                user.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              user.fullName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              user.phone.isNotEmpty ? user.phone : user.email,
                              style: const TextStyle(
                                color: AppColors.textMedium,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}