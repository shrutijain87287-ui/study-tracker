// File generated for Study Tracker Firebase integration.
// Replace the placeholder values with your Firebase Project credentials from the Firebase Console,
// or provide them via --dart-define / environment variables.

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
        return ios;
      default:
        return web;
    }
  }

  // Web configuration (GitHub Pages / Web builds)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY',
        defaultValue: 'AIzaSyCcMURj1hrVHLgFn1B2nDFR4Xeu5e5et68'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID',
        defaultValue: '1:713947693149:web:0e6e15e7992aabf6b5cdb4'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '713947693149'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID',
        defaultValue: 'study-tracker-3c731'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
        defaultValue: 'study-tracker-3c731.firebaseapp.com'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'study-tracker-3c731.firebasestorage.app'),
    measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID',
        defaultValue: 'G-WDM0G1F1H6'),
  );

  // Android configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY',
        defaultValue: 'AIzaSyDemoPlaceholderAndroidApiKeyStudyTracker'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID',
        defaultValue: '1:123456789012:android:abcdef1234567890'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '123456789012'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID',
        defaultValue: 'study-tracker-app'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'study-tracker-app.appspot.com'),
  );

  // iOS configuration (optional fallback)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY',
        defaultValue: 'AIzaSyDemoPlaceholderIosApiKeyStudyTracker'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID',
        defaultValue: '1:123456789012:ios:abcdef1234567890'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '123456789012'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID',
        defaultValue: 'study-tracker-app'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'study-tracker-app.appspot.com'),
    iosBundleId: 'com.example.caInterTracker',
  );
}
