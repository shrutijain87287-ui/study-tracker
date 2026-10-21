import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/screens/onboarding_screen.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService User Name Tests', () {
    test('User name saving and loading', () async {
      expect(await StorageService.loadUserName(), isNull);
      await StorageService.saveUserName('Shruti');
      expect(await StorageService.loadUserName(), 'Shruti');

      await StorageService.clearAllData();
      expect(await StorageService.loadUserName(), isNull);
    });
  });

  group('OnboardingScreen UI & Flow Tests', () {
    testWidgets('Renders Step 1 with Name, Plan, and 6 Categories',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: OnboardingScreen(
            onPlanCreated: (plan, [user]) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header & Welcome
      expect(find.text('Study Tracker'), findsOneWidget);
      expect(find.text('Welcome to Study Tracker 👋'), findsOneWidget);
      expect(find.text('First, tell us your name'), findsOneWidget);
      expect(find.text('What are you preparing for?'), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);

      // Check all 6 Category titles
      expect(find.text('College / University'), findsOneWidget);
      expect(find.text('Competitive Exam'), findsOneWidget);
      expect(find.text('Professional Exam'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Certification'), findsOneWidget);
      expect(find.text('Self-Study'), findsOneWidget);

      // Check Next Step button exists
      expect(find.text('Next Step'), findsOneWidget);
    });

    testWidgets('Validation: cannot proceed with empty name or plan',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: OnboardingScreen(
            onPlanCreated: (plan, [user]) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear the user name to test validation
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      // Tap Next Step with empty name
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Error message should be visible
      expect(
          find.text(
              'Please enter your name to personalize your study tracker.'),
          findsOneWidget);
    });

    testWidgets('Full navigation: Step 1 -> Step 2 -> Step 3 -> Launch Tracker',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      StudyPlan? resultPlan;
      String? resultName;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: OnboardingScreen(
            onPlanCreated: (plan, [user]) async {
              resultPlan = plan;
              resultName = user;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Enter user name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Shruti');
      await tester.pumpAndSettle();

      // 2. Select "Professional Exam" category
      await tester.tap(find.text('Professional Exam'));
      await tester.pumpAndSettle();

      // 3. Click Next Step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 should display Category-specific targets
      expect(find.text('Professional Exam Targets 🎯'), findsOneWidget);
      expect(find.text('Qualification & Level'), findsOneWidget);

      // 4. Click Next Step from Step 2 to Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3 should display Initial Subjects
      expect(find.text('Initial Subjects & Courses 📚'), findsOneWidget);
      expect(find.text('Launch Tracker'), findsOneWidget);

      // 5. Click Launch Tracker
      await tester.tap(find.text('Launch Tracker'));
      await tester.pumpAndSettle();

      expect(resultName, 'Shruti');
      expect(resultPlan, isNotNull);
      expect(resultPlan!.category, 'Professional Exam');
      expect(resultPlan!.subjects.isNotEmpty, true);
    });
  });
}
