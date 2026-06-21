import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by adding the Firebase web options and '
        'running `flutterfire configure` again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by adding the Firebase iOS options and '
          'running `flutterfire configure` again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by adding the Firebase macOS options and '
          'running `flutterfire configure` again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows - '
          'you can reconfigure this by adding the Firebase Windows options and '
          'running `flutterfire configure` again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by adding the Firebase Linux options and '
          'running `flutterfire configure` again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIWhZB8bs2dMKVYYgAqsY2hKD_GEPTvp0',
    appId: '1:784001477417:android:3091cd37b7b6d83806a538',
    messagingSenderId: '784001477417',
    projectId: 'talkative-f67bf',
    storageBucket: 'talkative-f67bf.firebasestorage.app',
  );
}
