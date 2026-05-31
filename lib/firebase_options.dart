import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with [Firebase.initializeApp].
/// 
/// 💡 이 파일은 Firebase 연결 환경을 사전에 정의합니다. 
/// 사령관님이 Firebase Console 설정을 완료하시면 해당 값들이 실제 값들로 갱신됩니다.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDp0MPKIhYOykJ2_qmcf7Exbm5RRB1wxQc',
    appId: '1:944224854885:web:e2fc502732057da953378c',
    messagingSenderId: '944224854885',
    projectId: 'nikke-mimir',
    authDomain: 'nikke-mimir.firebaseapp.com',
    storageBucket: 'nikke-mimir.firebasestorage.app',
    measurementId: 'G-T198N1F1RV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'MOCK_API_KEY_FOR_ANDROID_MIMIR',
    appId: '1:123456789:android:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'nikke-mimir',
    storageBucket: 'nikke-mimir.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'MOCK_API_KEY_FOR_IOS_MIMIR',
    appId: '1:123456789:ios:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'nikke-mimir',
    storageBucket: 'nikke-mimir.appspot.com',
    iosBundleId: 'com.example.mimir',
  );
}
