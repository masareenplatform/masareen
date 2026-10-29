// Generated Firebase options for MASAREEN (project: masareen-82196).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAgCmPETwZAShNm-9CBmTLJ5Owp-sfyz2M',
    appId: '1:818887213250:web:e13e73f6342f53a299bb5b',
    messagingSenderId: '818887213250',
    projectId: 'masareen-82196',
    authDomain: 'masareen-82196.firebaseapp.com',
    storageBucket: 'masareen-82196.firebasestorage.app',
    measurementId: 'G-MY5CSBRFR7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAUVZHB8528XBbNQjTiCx_tybWkDMK4a-s',
    appId: '1:818887213250:android:67c026bc807b213f99bb5b',
    messagingSenderId: '818887213250',
    projectId: 'masareen-82196',
    storageBucket: 'masareen-82196.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcO8i7e8Dpkiujv20AIbhsSrA_JTpgJMI',
    appId: '1:818887213250:ios:ce1f13897266c68999bb5b',
    messagingSenderId: '818887213250',
    projectId: 'masareen-82196',
    storageBucket: 'masareen-82196.firebasestorage.app',
    iosBundleId: 'com.masaren.app',
  );
}
