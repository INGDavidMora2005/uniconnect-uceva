import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Pedir permisos
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Configurar notificaciones locales (para cuando la app está en primer plano)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Canal Android
    const channel = AndroidNotificationChannel(
      'uniconnect_channel',
      'UniConnect',
      description: 'Notificaciones de UniConnect',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Guardar token FCM en Firestore
    await _saveToken();

    // Escuchar mensajes en primer plano
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _local.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'uniconnect_channel',
              'UniConnect',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Guarda en Firestore la notificación para que el destinatario la vea
  Future<void> saveNotification({
    required String toUserId,
    required String title,
    required String body,
    required String type, // 'cupo_request', 'cupo_accepted', 'cupo_rejected'
    Map<String, dynamic> extra = const {},
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .add({
      'toUserId':  toUserId,
      'title':     title,
      'body':      body,
      'type':      type,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }
}