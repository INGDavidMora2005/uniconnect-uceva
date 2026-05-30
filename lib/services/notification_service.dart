import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId   = 'uniconnect_channel';
  static const _channelName = 'UniConnect';

  // Global key for navigation
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    // ✅ En v18 se instancia directamente, sin resolvePlatformSpecificImplementation
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notificaciones de UniConnect',
        importance: Importance.high,
      ),
    );

    await _saveToken();

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      
      // Check if the notification category is enabled
      final type = message.data['type'] ?? '';
      final isEnabled = await isCategoryEnabled(type);
      if (!isEnabled) return;
      
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    // Handle notification when app is opened from terminated/background state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final data = message.data;
        if (data.isNotEmpty) {
          // We'll handle navigation in main.dart where we have access to navigatorKey
          // Store the message for later processing
          _initialMessage = message;
        }
      }
    });

    // Handle notification when app is in background and opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      if (data.isNotEmpty) {
        // Navigate using the navigatorKey
        handleNotificationTap(data, navigatorKey.currentState?.overlay?.context);
      }
    });

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
      debugPrint('Token refrescado y guardado: $newToken');
    });
  }

  // Store initial message for later processing
  RemoteMessage? _initialMessage;

  /// Handles notification tap and navigates to appropriate screen
  Future<void> handleNotificationTap(Map<String, dynamic> data, BuildContext? context) async {
    if (context == null) return;
    
    final String type = data['type'] ?? '';
    
    switch (type) {
      case 'cupo_request':
        navigatorKey.currentState?.pushNamed('/solicitudes-cupo');
        break;
      case 'cupo_cancelado':
        navigatorKey.currentState?.pushNamed('/solicitudes-cupo');
        break;
      case 'cupo_accepted':
      case 'cupo_rejected':
        navigatorKey.currentState?.pushNamed('/mis-rutas');
        break;
      case 'new_message':
        final String chatId = data['chatId'] ?? '';
        if (chatId.isNotEmpty) {
          navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
        }
        break;
      case 'new_rating':
        navigatorKey.currentState?.pushNamed('/perfil');
        break;
      default:
        // Do nothing for unknown types
        break;
    }
  }

  /// Process initial message (when app opened from terminated state)
  Future<void> processInitialMessage(BuildContext context) async {
    if (_initialMessage != null) {
      final data = _initialMessage!.data;
      if (data.isNotEmpty) {
        handleNotificationTap(data, context);
      }
      _initialMessage = null;
    }
  }

  Future<bool> isCategoryEnabled(String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true; // Default to enabled if no user
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final notificationSettings = data['notificationSettings'] as Map<String, dynamic>? ?? {};
        return notificationSettings[type] ?? true; // Return the setting or default to true
      }
      return true; // Default to enabled if no document
    } catch (e) {
      return true; // Default to enabled on error
    }
  }

  Future<void> _saveToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('UID: $uid');
      if (uid == null) {
        debugPrint('No UID found, skipping token save');
        return;
      }
      final token = await _fcm.getToken();
      debugPrint('FCM Token: $token');
      if (token == null) {
        debugPrint('No FCM token found');
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('Token guardado correctamente');
    } catch (e) {
      debugPrint('Error en _saveToken: $e');
    }
  }

  /// Public method to save token for current user (can be called after login)
  Future<void> saveTokenForCurrentUser() async {
    await _saveToken();
  }

  Future<void> saveNotification({
    required String toUserId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId':  toUserId,
      'title':     title,
      'body':      body,
      'type':      type,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}