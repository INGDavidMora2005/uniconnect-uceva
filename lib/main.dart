import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/moderation_panel_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/notification_service.dart';
import 'screens/profile_screen.dart';
import 'screens/home_rutas_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/mis_chats_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/crypto_test_screen.dart';

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

class _UniConnectAppState extends State<UniConnectApp> {
  @override
  void initState() {
    super.initState();
    // Process initial message after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().processInitialMessage(context);
    });
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
        // UU-42 B-08: ruta de debug solo disponible en kDebugMode
        ...kDebugMode
            ? <String, WidgetBuilder>{
                '/crypto-test': (context) => const CryptoTestScreen(),
              }
            : <String, WidgetBuilder>{},
      },
    );
  }
}