import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  String? _uid;
  bool _loading = true;
  final Map<String, bool> _settings = {
    'cupo_request': true,
    'cupo_accepted': true,
    'new_message': true,
    'new_rating': true,
    'cupo_cancelado': true,
  };

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _loadSettings();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSettings() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final notificationSettings = data['notificationSettings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _settings['cupo_request'] = notificationSettings['cupo_request'] ?? true;
          _settings['cupo_accepted'] = notificationSettings['cupo_accepted'] ?? true;
          _settings['new_message'] = notificationSettings['new_message'] ?? true;
          _settings['new_rating'] = notificationSettings['new_rating'] ?? true;
          _settings['cupo_cancelado'] = notificationSettings['cupo_cancelado'] ?? true;
        });
      }
    } catch (e) {
      // If there's an error, we keep the default values (all true)
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (_uid == null) return;
    try {
      // Update the specific field in the notificationSettings map
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
            'notificationSettings.$key': value,
          });
    } catch (e) {
      // Ignore errors for now, but in a real app we might show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: const Text(
          'Ajustes de notificaciones',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGreen),
            )
          : ListView(
              children: [
                _buildSwitchListTile(
                  'Solicitudes de cupo',
                  'cupo_request',
                  'Recibe notificaciones cuando alguien solicita un cupo en tu ruta',
                ),
                _buildSwitchListTile(
                  'Respuestas de cupo',
                  'cupo_accepted',
                  'Recibe notificaciones cuando aceptan o rechazan tu solicitud de cupo',
                ),
                _buildSwitchListTile(
                  'Mensajes de chat',
                  'new_message',
                  'Recibe notificaciones cuando recibes un nuevo mensaje',
                ),
                _buildSwitchListTile(
                  'Calificaciones',
                  'new_rating',
                  'Recibe notificaciones cuando recibes una nueva calificación',
                ),
                _buildSwitchListTile(
                  'Cancelaciones de reserva',
                  'cupo_cancelado',
                  'Recibe notificaciones cuando un pasajero cancela su reserva en tu ruta',
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchListTile(String title, String key, String subtitle) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textLight,
        ),
      ),
      value: _settings[key] ?? true,
      onChanged: (value) {
        setState(() {
          _settings[key] = value;
        });
        _updateSetting(key, value);
      },
      activeThumbColor: AppColors.accentGreen,
      activeTrackColor: AppColors.lightGreen,
    );
  }
}