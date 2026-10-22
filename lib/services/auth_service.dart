import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  const AuthResult.success([this.user])
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null;
}

class AuthService {
  static FirebaseAuth? _auth;
  static bool _initialized = false;
  static final StreamController<User?> _fallbackAuthController =
      StreamController<User?>.broadcast();

  // Test / mock hooks
  static User? _mockUser;
  static bool _mockUserOverride = false;
  static final StreamController<User?> _mockAuthController =
      StreamController<User?>.broadcast();
  static Future<AuthResult> Function(
      String email, String password, String? displayName)? _mockSignUpHandler;
  static Future<AuthResult> Function(String email, String password)?
      _mockSignInHandler;

  @visibleForTesting
  static void setMockUser(User? user) {
    _mockUserOverride = true;
    _mockUser = user;
    _mockAuthController.add(user);
  }

  @visibleForTesting
  static void setMockHandlers({
    Future<AuthResult> Function(
            String email, String password, String? displayName)?
        onSignUp,
    Future<AuthResult> Function(String email, String password)? onSignIn,
  }) {
    _mockSignUpHandler = onSignUp;
    _mockSignInHandler = onSignIn;
  }

  @visibleForTesting
  static void resetTestingState() {
    _mockUserOverride = false;
    _mockUser = null;
    _mockSignUpHandler = null;
    _mockSignInHandler = null;
  }

  static bool get isMockMode => _mockUserOverride;

  /// Ensures Firebase and FirebaseAuth are initialized safely.
  static Future<bool> initialize() async {
    if (_mockUserOverride) return true;
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _auth = FirebaseAuth.instance;
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint(
          'AuthService initialization notice (running offline/local mode): $e');
      _initialized = false;
      return false;
    }
  }

  static bool get isConfigured => _initialized && _auth != null;

  static FirebaseAuth? get authInstance => _auth;

  /// Stream of user auth state changes.
  static Stream<User?> get authStateChanges {
    return _createAuthStateStream().asBroadcastStream();
  }

  static Stream<User?> _createAuthStateStream() async* {
    if (_mockUserOverride) {
      yield _mockUser;
      yield* _mockAuthController.stream;
      return;
    }
    if (_auth != null) {
      yield* _auth!.authStateChanges();
    } else {
      yield null;
      yield* _fallbackAuthController.stream;
    }
  }

  /// Current authenticated user, or null if unauthenticated / offline.
  static User? get currentUser {
    if (_mockUserOverride) {
      return _mockUser;
    }
    if (_auth != null) {
      return _auth!.currentUser;
    }
    return null;
  }

  static bool get isSignedIn => currentUser != null;

  static String? get currentUid => currentUser?.uid;

  static String? get currentEmail => currentUser?.email;

  static String? get displayName => currentUser?.displayName;

  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  static bool get isPlaceholderConfigured {
    final key = DefaultFirebaseOptions.currentPlatform.apiKey;
    return key.startsWith('AIzaSyDemoPlaceholder');
  }

  /// Register with email and password.
  static Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (_mockSignUpHandler != null) {
      final res = await _mockSignUpHandler!(email, password, displayName);
      if (res.isSuccess) {
        setMockUser(res.user);
      }
      return res;
    }

    if (isPlaceholderConfigured) {
      return const AuthResult.failure(
        'Firebase project credentials are not yet configured. Please paste your Web API key and project ID from Firebase Console into lib/firebase_options.dart.',
      );
    }

    final ok = await initialize();
    if (!ok || _auth == null) {
      return const AuthResult.failure(
        'Firebase Authentication is not yet configured or device is offline. Please check network and Firebase setup.',
      );
    }

    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          await credential.user!.updateDisplayName(displayName.trim());
        }
        // Send initial email verification
        try {
          await credential.user!.sendEmailVerification();
        } catch (_) {}
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure('Failed to create account: ${e.toString()}');
    }
  }

  /// Sign in with email and password.
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_mockSignInHandler != null) {
      final res = await _mockSignInHandler!(email, password);
      if (res.isSuccess) {
        setMockUser(res.user);
      }
      return res;
    }

    if (isPlaceholderConfigured) {
      return const AuthResult.failure(
        'Firebase project credentials are not yet configured. Please paste your Web API key and project ID from Firebase Console into lib/firebase_options.dart.',
      );
    }

    final ok = await initialize();
    if (!ok || _auth == null) {
      return const AuthResult.failure(
        'Firebase Authentication is not yet configured or device is offline. Please check network and Firebase setup.',
      );
    }

    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure('Failed to sign in: ${e.toString()}');
    }
  }

  /// Send password reset link to user's email.
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    if (isPlaceholderConfigured) {
      return const AuthResult.failure(
        'Firebase project credentials are not yet configured. Please paste your Web API key and project ID from Firebase Console into lib/firebase_options.dart.',
      );
    }

    final ok = await initialize();
    if (!ok || _auth == null) {
      return const AuthResult.failure(
        'Firebase Authentication is not configured or device is offline.',
      );
    }

    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
          'Failed to send password reset: ${e.toString()}');
    }
  }

  /// Resend email verification to current user.
  static Future<AuthResult> sendEmailVerification() async {
    if (_auth == null || _auth!.currentUser == null) {
      return const AuthResult.failure('No authenticated user found.');
    }

    try {
      await _auth!.currentUser!.sendEmailVerification();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
          'Failed to send verification email: ${e.toString()}');
    }
  }

  /// Reload current user's token and profile data (e.g. to update emailVerified).
  static Future<void> reloadUser() async {
    try {
      await _auth?.currentUser?.reload();
    } catch (e) {
      debugPrint('Failed to reload user: $e');
    }
  }

  /// Sign out current user.
  static Future<void> signOut() async {
    if (_mockUserOverride) {
      setMockUser(null);
      return;
    }
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('Sign out notice: $e');
    }
    _fallbackAuthController.add(null);
  }

  /// Delete current user account with Firebase Auth.
  static Future<AuthResult> deleteAccount() async {
    if (_mockUserOverride) {
      setMockUser(null);
      return const AuthResult.success();
    }
    if (_auth == null || _auth!.currentUser == null) {
      return const AuthResult.failure('No active user account found.');
    }

    try {
      await _auth!.currentUser!.delete();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const AuthResult.failure(
          'For security, please log out and log in again before deleting your account.',
        );
      }
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure('Failed to delete account: ${e.toString()}');
    }
  }

  /// Friendly human-readable Firebase error message mapper.
  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please check or sign up.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please log in.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Access is temporarily disabled. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console. Please enable it in Authentication -> Sign-in method.';
      case 'api-key-not-valid':
        return 'Firebase API key is invalid or placeholder. Please update lib/firebase_options.dart with your Web configuration from Firebase Console.';
      case 'app-not-authorized':
        return 'This app domain is not authorized. Please add your domain to Firebase Console -> Authentication -> Settings -> Authorized domains.';
      case 'permission-denied':
        return 'Access denied. Cloud Firestore security rules require an authenticated account.';
      case 'unavailable':
        return 'Firebase services are temporarily unreachable. Local data is preserved.';
      default:
        return e.message ?? 'Authentication error: ${e.code}';
    }
  }
}
