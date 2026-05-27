import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/moderation_panel_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'screens/profile_screen.dart';
import 'screens/home_rutas_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/mis_chats_screen.dart';
import 'screens/chat_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init(); // ← inicializa FCM
  runApp(const UniConnectApp());
}

class UniConnectApp extends StatefulWidget {
  const UniConnectApp({super.key});

  @override
  State<UniConnectApp> createState() => _UniConnectAppState();
}

class _UniConnectAppState extends State<UniConnectApp> with WidgetsBindingObserver {
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mark as online when app starts
    _updateUserPresence(true);
    // Process initial message after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().processInitialMessage(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _updateUserPresence(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _updateUserPresence(false);
        break;
      case AppLifecycleState.hidden:
        _updateUserPresence(false);
        break;
    }
  }

  Future<void> _updateUserPresence(bool isOnline) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _chatService.updatePresence(uid, isOnline);
      }
    } catch (e) {
      // Ignorar errores de presencia para no bloquear la UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'UniConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/admin/moderation': (context) => const ModerationPanelScreen(),
        '/email-verification': (context) => const EmailVerificationScreen(email: ''),
        '/perfil': (context) => const ProfileScreen(showBottomNav: false),
        '/mis-rutas': (context) => const HomeRutasScreen(),
        '/solicitudes-cupo': (context) => const NotificationsScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
        '/chats': (context) => const MisChatsScreen(),
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ChatScreen(
            chatId: args['chatId'],
            otherUserName: args['otherUserName'],
            otherUserId: args['otherUserId'] ?? '',
            routeInfo: args['routeInfo'],
          );
        },
      },
    );
  }
}