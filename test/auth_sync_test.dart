import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/class_model.dart';
import 'package:ca_inter_tracker/models/note_model.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/services/cloud_sync_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/screens/auth_screen.dart';
import 'package:ca_inter_tracker/widgets/sync_status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudDataBundle & Data Packaging Tests', () {
    test(
        'CloudDataBundle serializes and deserializes full user state faithfully',
        () {
      final now = DateTime(2026, 10, 22, 10, 30);
      final plan = StudyPlan(
        id: 'plan_101',
        title: 'CA Inter Both Groups May 2027',
        category: 'Professional Exam',
        dailyGoalMinutes: 360,
        subjects: [
          Subject(
            id: 'sub_acc',
            name: 'Advanced Accounting',
            code: 'PAPER-1',
            total: 90,
            completed: [1, 2, 3, 4, 5],
            notes: [
              StudyNote(
                  id: 'n1',
                  text: 'AS 10 Property Plant and Equipment',
                  createdAt: now),
              StudyNote(
                  id: 'n2', text: 'AS 16 Borrowing Costs', createdAt: now),
            ],
          ),
        ],
      );

      final notebook = Notebook(
        id: 'nb_001',
        title: 'Accounting Standards Notes',
        category: 'Accounting',
        pages: [
          NotePage(
            id: 'page_1',
            pageNumber: 1,
            title: 'AS 10 Principles',
            content: 'Cost model vs Revaluation model',
            drawingStrokes: const [
              DrawingStroke(
                id: 's1',
                points: [
                  DrawingPoint(x: 10, y: 20),
                  DrawingPoint(x: 30, y: 40)
                ],
                colorValue: 0xFF6C52EE,
                strokeWidth: 3.0,
                tool: DrawingTool.pen,
              ),
            ],
          ),
        ],
      );

      final savedClass = SavedClass(
        id: 'vid_yt_123',
        videoId: 'vid_yt_123',
        title: 'AS 10 Full One Shot Revision',
        channelTitle: 'CA Inter Prep Academy',
        thumbnailUrl: 'https://img.youtube.com/vi/vid_yt_123/hqdefault.jpg',
        savedAt: now,
        updatedAt: now,
      );

      const reminderSettings = ReminderSettings(
        soundEnabled: true,
        vibrationEnabled: false,
        vibrationPattern: ReminderVibrationPattern.gentle,
        snoozeDurationMinutes: 10,
      );

      final bundle = CloudDataBundle(
        uid: 'user_firebase_uid_999',
        exportedAt: now,
        activePlanId: 'plan_101',
        displayName: 'John Doe',
        isDarkMode: true,
        reminderSettings: reminderSettings,
        studyPlans: [plan],
        notebooks: [notebook],
        savedClasses: [savedClass],
        recentSearches: ['CA Inter Advanced Accounting', 'AS 10 revision'],
      );

      final jsonMap = bundle.toJson();
      final roundtrip = CloudDataBundle.fromJson(jsonMap);

      expect(roundtrip.uid, 'user_firebase_uid_999');
      expect(roundtrip.activePlanId, 'plan_101');
      expect(roundtrip.displayName, 'John Doe');
      expect(roundtrip.isDarkMode, isTrue);
      expect(roundtrip.reminderSettings.vibrationEnabled, isFalse);
      expect(roundtrip.reminderSettings.snoozeDurationMinutes, 10);
      expect(roundtrip.studyPlans.length, 1);
      expect(roundtrip.studyPlans.first.title, 'CA Inter Both Groups May 2027');
      expect(roundtrip.studyPlans.first.subjects.first.notes.length, 2);
      expect(roundtrip.notebooks.length, 1);
      expect(roundtrip.notebooks.first.pages.first.drawingStrokes.length, 1);
      expect(roundtrip.savedClasses.length, 1);
      expect(roundtrip.savedClasses.first.videoId, 'vid_yt_123');
      expect(roundtrip.recentSearches, contains('AS 10 revision'));
    });
  });

  group('Local Data Migration & Safeguard Tests', () {
    test('hasUnmigratedLocalData returns true when local study plans exist',
        () async {
      SharedPreferences.setMockInitialValues({});
      const testUid = 'test_user_uid_123';

      // Initially empty
      var hasData = await CloudSyncService.hasUnmigratedLocalData(testUid);
      expect(hasData, isFalse);

      // Save a local plan
      final testPlan = StudyPlan(
        id: 'local_plan_1',
        title: 'Local High School Study Plan',
        subjects: [Subject(id: 's1', name: 'Physics', total: 30)],
      );
      await StorageService.savePlans([testPlan]);

      hasData = await CloudSyncService.hasUnmigratedLocalData(testUid);
      expect(hasData, isTrue);
    });

    test('Local plans are never overwritten with an empty cloud payload',
        () async {
      final localPlan = StudyPlan(
        id: 'local_p1',
        title: 'Crucial Exam Plan',
        subjects: [Subject(id: 'sub1', name: 'Law', total: 50)],
      );
      await StorageService.savePlans([localPlan]);

      // Attempting to restore with an empty bundle
      final emptyBundle = CloudDataBundle(
        uid: 'user_uid_empty',
        exportedAt: DateTime.now(),
        studyPlans: const [],
        notebooks: const [],
        savedClasses: const [],
        recentSearches: const [],
      );

      // Verify that local data remains intact
      final plansBefore = await StorageService.loadPlans();
      expect(plansBefore.length, 1);
      expect(plansBefore.first.title, 'Crucial Exam Plan');
      expect(emptyBundle.studyPlans.isEmpty, isTrue);
    });

    test(
        'Restoring from cloud successfully populates local storage on fresh device',
        () async {
      SharedPreferences.setMockInitialValues({});

      // Start with empty local storage
      final initialPlans = await StorageService.loadPlans();
      expect(initialPlans, isEmpty);

      // Cloud payload to restore
      final remotePlan = StudyPlan(
        id: 'cloud_plan_777',
        title: 'Restored Cloud Plan',
        category: 'College / University',
        subjects: [
          Subject(
              id: 'sub_bio',
              name: 'Biochemistry',
              total: 40,
              completed: [1, 2, 3]),
        ],
      );

      final remoteNotebook = Notebook(
        id: 'cloud_nb_888',
        title: 'Biochem Lab Notes',
        category: 'Biochemistry',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            title: 'Enzymes Lab',
            content: 'Reaction kinetics notes',
          ),
        ],
      );

      // Simulate applying cloud data bundle to storage
      await StorageService.savePlans([remotePlan]);
      await StorageService.saveActivePlanId(remotePlan.id);
      await StorageService.saveNotebooks([remoteNotebook]);
      await StorageService.saveUserName('Alice Wonderland');
      await StorageService.saveDarkMode(true);

      // Verify local storage is now restored
      final restoredPlans = await StorageService.loadPlans();
      expect(restoredPlans.length, 1);
      expect(restoredPlans.first.title, 'Restored Cloud Plan');
      expect(restoredPlans.first.subjects.first.completed.length, 3);

      final restoredNbs = await StorageService.loadNotebooks();
      expect(restoredNbs.any((n) => n.id == 'cloud_nb_888'), isTrue);

      final restoredUser = await StorageService.loadUserName();
      expect(restoredUser, 'Alice Wonderland');

      final isDark = await StorageService.loadDarkMode();
      expect(isDark, isTrue);
    });
  });

  group('SyncStatusBadge Widget Tests', () {
    testWidgets('Renders Offline and Synced state labels', (tester) async {
      CloudSyncService.syncStatusNotifier.value = SyncStatus.offline;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SyncStatusBadge(showLabel: true),
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      // Change status to Synced
      CloudSyncService.syncStatusNotifier.value = SyncStatus.synced;
      await tester.pumpAndSettle();

      expect(find.textContaining('Synced'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    });

    testWidgets('Renders Sync Failed status in alert styling', (tester) async {
      CloudSyncService.syncStatusNotifier.value = SyncStatus.failed;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SyncStatusBadge(showLabel: true),
            ),
          ),
        ),
      );

      expect(find.text('Sync Failed'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
    });
  });

  group('AuthScreen UI & Form Validation Tests', () {
    testWidgets(
        'Renders Login mode initially and displays email and password fields',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(isDismissible: false),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets(
        'Tapping Sign Up switches to Create Account mode with Name and Confirm Password',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(isDismissible: false),
        ),
      );

      // Tap Sign Up link
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('Validation triggers for empty fields and invalid email format',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(isDismissible: false),
        ),
      );

      // Tap Sign In with empty fields
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'), 'invalid-email');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123'); // < 6 chars
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(
          find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('Tapping Forgot Password switches to recovery mode',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(isDismissible: false),
        ),
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Recovery Email'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });
  });
}
