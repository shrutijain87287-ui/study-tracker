import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/main.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/screens/auth_screen.dart';
import 'package:ca_inter_tracker/screens/dashboard_screen.dart';
import 'package:ca_inter_tracker/screens/home_shell.dart';
import 'package:ca_inter_tracker/services/auth_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';

class MockFirebaseUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final bool emailVerified;

  MockFirebaseUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = true,
  });

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> sendEmailVerification(
      [ActionCodeSettings? actionCodeSettings]) async {}

  @override
  Future<void> reload() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetTestingState();
  });

  tearDown(() {
    AuthService.resetTestingState();
  });

  Future<void> pumpFrame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  void ignoreOverflowErrors(
      void Function(FlutterErrorDetails)? originalOnError) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };
  }

  group('Firebase Authentication Navigation & Flow Tests', () {
    testWidgets(
        '1. Signed-out startup renders AuthScreen and denies direct HomeShell access',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AuthService.setMockUser(null);

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
      // Close button should not be rendered when unauthenticated at root
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets(
        '2. Existing session startup renders HomeShell directly without auth flash',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final user = MockFirebaseUser(
        uid: 'user_active_123',
        email: 'alex@example.com',
        displayName: 'Alex',
      );
      AuthService.setMockUser(user);

      // Populate study plan so HomeShell is loaded
      final plan = StudyPlan(
        id: 'plan_active_1',
        title: 'CA Inter Prep',
        subjects: [Subject(id: 's1', name: 'Accounting', total: 40)],
      );
      await StorageService.savePlans([plan]);
      await StorageService.saveActivePlanId(plan.id);
      await StorageService.saveUserName('Alex');

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets(
        '3. Successful sign-in automatically navigates to dashboard without clicking X',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AuthService.setMockUser(null);

      // Pre-save study plan and mark UID migrated so migration dialog doesn't block
      final plan = StudyPlan(
        id: 'plan_signin_1',
        title: 'CA Final Law Prep',
        subjects: [Subject(id: 's1', name: 'Corporate Law', total: 30)],
      );
      await StorageService.savePlans([plan]);
      await StorageService.saveActivePlanId(plan.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('migrated_user_uids_v1', ['uid_alex_999']);

      AuthService.setMockHandlers(
        onSignIn: (email, password) async {
          return AuthResult.success(MockFirebaseUser(
            uid: 'uid_alex_999',
            email: email,
            displayName: 'Alex Law',
          ));
        },
      );

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(AuthScreen), findsOneWidget);

      // Enter login credentials
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'alex@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'secret123');

      // Tap Sign In button
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await pumpFrame(tester);

      // Verify automatic navigation to HomeShell
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets(
        '4. Successful sign-up automatically navigates to dashboard without clicking X',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AuthService.setMockUser(null);

      // Pre-save study plan and mark UID migrated
      final plan = StudyPlan(
        id: 'plan_signup_1',
        title: 'Taxation Mastery',
        subjects: [Subject(id: 's1', name: 'Direct Tax', total: 45)],
      );
      await StorageService.savePlans([plan]);
      await StorageService.saveActivePlanId(plan.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('migrated_user_uids_v1', ['uid_new_student']);

      AuthService.setMockHandlers(
        onSignUp: (email, password, displayName) async {
          return AuthResult.success(MockFirebaseUser(
            uid: 'uid_new_student',
            email: email,
            displayName: displayName ?? 'New Student',
          ));
        },
      );

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(AuthScreen), findsOneWidget);

      // Switch to Sign Up mode
      await tester.tap(find.text('Sign Up'));
      await pumpFrame(tester);

      expect(find.text('Create Account'), findsWidgets);

      // Fill in sign up form
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'New Student');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'new@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'password123');

      // Tap Create Account button
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await pumpFrame(tester);

      // Automatically transitions to HomeShell
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets(
        '5. Sign-out returns user to AuthScreen and dismisses dashboard',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final user = MockFirebaseUser(
        uid: 'user_to_sign_out',
        email: 'signout@example.com',
        displayName: 'Signout User',
      );
      AuthService.setMockUser(user);

      final plan = StudyPlan(
        id: 'plan_so_1',
        title: 'Auditing & Ethics',
        subjects: [Subject(id: 's1', name: 'SA 200 Series', total: 25)],
      );
      await StorageService.savePlans([plan]);
      await StorageService.saveActivePlanId(plan.id);

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);

      // Trigger sign out
      await AuthService.signOut();
      await pumpFrame(tester);

      // Verify user is returned to AuthScreen
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets(
        '6. Failed authentication displays error message banner and stays on AuthScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AuthService.setMockUser(null);

      AuthService.setMockHandlers(
        onSignIn: (email, password) async {
          return const AuthResult.failure(
              'Incorrect password or email. Please try again.');
        },
      );

      await tester.pumpWidget(const StudyTrackerApp());
      await pumpFrame(tester);

      expect(find.byType(AuthScreen), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'wrong@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'wrongpass');

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await pumpFrame(tester);

      // Verify error banner is visible and AuthScreen is still active
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Incorrect password or email. Please try again.'),
          findsOneWidget);
    });
  });
}
