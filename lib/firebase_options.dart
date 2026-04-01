import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyoaaYi_fgV5llNFMoVjMRi1wKaDZeyEs',
    appId: '1:26604708677:web:1bce1d9edd405c2e13942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    authDomain: 'uniconnect-uceva.firebaseapp.com',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
    measurementId: 'G-8PEM2VJ4J1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3JdajygGlYcXt486KU-PhJpExKoDpdf0',
    appId: '1:26604708677:android:4091d02b0cee8ff113942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3JdajygGlYcXt486KU-PhJpExKoDpdf0',
    appId: '1:26604708677:ios:4091d02b0cee8ff113942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
    iosBundleId: 'com.uceva.uniconnectApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD3JdajygGlYcXt486KU-PhJpExKoDpdf0',
    appId: '1:26604708677:ios:4091d02b0cee8ff113942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
    iosBundleId: 'com.uceva.uniconnectApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAyoaaYi_fgV5llNFMoVjMRi1wKaDZeyEs',
    appId: '1:26604708677:web:1bce1d9edd405c2e13942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    authDomain: 'uniconnect-uceva.firebaseapp.com',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
    measurementId: 'G-8PEM2VJ4J1',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAyoaaYi_fgV5llNFMoVjMRi1wKaDZeyEs',
    appId: '1:26604708677:web:1bce1d9edd405c2e13942c',
    messagingSenderId: '26604708677',
    projectId: 'uniconnect-uceva',
    authDomain: 'uniconnect-uceva.firebaseapp.com',
    storageBucket: 'uniconnect-uceva.firebasestorage.app',
    measurementId: 'G-8PEM2VJ4J1',
  );
}