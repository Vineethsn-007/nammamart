// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBHmhWOQVQlwfzs8-m8-Y3pReK__Z3UHEI',
    appId: '1:786487056540:web:7014c472b0015c0b5bb559',
    messagingSenderId: '786487056540',
    projectId: 'nammastore123',
    authDomain: 'nammastore123.firebaseapp.com',
    databaseURL:
        'https://nammastore123-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'nammastore123.firebasestorage.app',
    measurementId: 'G-GH6BZM6CKD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQgBLTXOij_3FFTh15io-SPTpbKE0K2pE',
    appId: '1:786487056540:android:7109ff4cac39d3145bb559',
    messagingSenderId: '786487056540',
    projectId: 'nammastore123',
    databaseURL:
        'https://nammastore123-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'nammastore123.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCtbL5jKBdUMdaHiio9cEpnQfB0DGBVNLY',
    appId: '1:786487056540:ios:05640a94692ebdcc5bb559',
    messagingSenderId: '786487056540',
    projectId: 'nammastore123',
    databaseURL:
        'https://nammastore123-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'nammastore123.firebasestorage.app',
    iosBundleId: 'com.example.nammaMart',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCtbL5jKBdUMdaHiio9cEpnQfB0DGBVNLY',
    appId: '1:786487056540:ios:05640a94692ebdcc5bb559',
    messagingSenderId: '786487056540',
    projectId: 'nammastore123',
    databaseURL:
        'https://nammastore123-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'nammastore123.firebasestorage.app',
    iosBundleId: 'com.example.nammaMart',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBHmhWOQVQlwfzs8-m8-Y3pReK__Z3UHEI',
    appId: '1:786487056540:web:742aa3d65afceb2a5bb559',
    messagingSenderId: '786487056540',
    projectId: 'nammastore123',
    authDomain: 'nammastore123.firebaseapp.com',
    databaseURL:
        'https://nammastore123-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'nammastore123.firebasestorage.app',
    measurementId: 'G-YW0GTYKLMQ',
  );
}
