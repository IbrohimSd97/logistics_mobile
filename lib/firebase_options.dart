// Firebase sozlamalari (`flutterfire configure` chiqaradigan fayl bilan bir xil).
// Manba: android/app/google-services.json va ios/Runner/GoogleService-Info.plist,
// Firebase loyihasi `alix-uz`. Bu kalitlar maxfiy emas — ular ilova ichida
// ochiq turadi va Firebase tomonda paket nomi/bundle ID bilan cheklangan.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUtn8aRIX0QxSqbvTkwcYlwNIKVYAM5v8',
    appId: '1:1030849501248:android:e63247e2b4e3d82ac0a7a5',
    messagingSenderId: '1030849501248',
    projectId: 'alix-uz',
    storageBucket: 'alix-uz.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9pMnY5y5qC1EJPHo_JPk6fVU31w5EK-w',
    appId: '1:1030849501248:ios:aedd972883a5030cc0a7a5',
    messagingSenderId: '1030849501248',
    projectId: 'alix-uz',
    storageBucket: 'alix-uz.firebasestorage.app',
    iosBundleId: 'uz.alix.app',
  );
}
