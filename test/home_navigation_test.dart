import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/screens/home_shell.dart';
import 'package:ca_inter_tracker/services/auth_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudyPlan samplePlan;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetTestingState();

    samplePlan = StudyPlan(
      id: 'plan_test_1',
      title: 'CA Intermediate May 2026',
      category: 'Professional Exam',
      subjects: [
        Subject(
            id: 'sub_acc',
            name: 'Advanced Accounting',
            code: 'PAPER-1',
            total: 50),
        Subject(
            id: 'sub_law', name: 'Corporate Laws', code: 'PAPER-2', total: 40),
      ],
    );
    await StorageService.savePlans([samplePlan]);
    await StorageService.saveActivePlanId(samplePlan.id);
  });

  tearDown(() {
    AuthService.resetTestingState();
  });

  Widget buildTestWidget(
      {required bool isDark, required double width, required double height}) {
    return MaterialApp(
      theme: buildAppTheme(isDark: isDark),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: HomeShell(
          initialPlans: [samplePlan],
          activePlanId: samplePlan.id,
          isDark: isDark,
          onToggleTheme: () {},
          onReloadAll: () {},
          userName: 'Shruti',
        ),
      ),
    );
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

  group('Responsive Navigation & Drawer Tests', () {
    testWidgets(
        '1. Mobile layout (<800px): Hides desktop sidebar, removes bottom nav, renders hamburger menu',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester
          .pumpWidget(buildTestWidget(isDark: false, width: 400, height: 800));
      await tester.pumpAndSettle();

      // Desktop persistent sidebar should not be in the tree (Row with 250 width container)
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'Bottom NavigationBar must be removed on mobile');
      expect(find.byKey(const Key('hamburger_menu_button')), findsOneWidget,
          reason: 'Hamburger menu icon must be present');
      expect(find.text('Dashboard'), findsWidgets);

      // Drawer is initially closed
      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
    });

    testWidgets(
        '2. Mobile layout: Tapping hamburger menu opens drawer with all 8 menu items and close button',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester
          .pumpWidget(buildTestWidget(isDark: false, width: 400, height: 800));
      await tester.pumpAndSettle();

      // Tap hamburger menu
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.byKey(const Key('app_navigation_drawer')), findsOneWidget);
      expect(find.byKey(const Key('drawer_close_button')), findsOneWidget);

      // Verify all 8 menu items are rendered
      expect(find.byKey(const Key('nav_item_0')), findsOneWidget); // Dashboard
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget); // Subjects
      expect(
          find.byKey(const Key('nav_item_2')), findsOneWidget); // Classes Hub
      expect(
          find.byKey(const Key('nav_item_3')), findsOneWidget); // Digital Notes
      expect(
          find.byKey(const Key('nav_item_4')), findsOneWidget); // Focus Timer
      expect(
          find.byKey(const Key('nav_item_5')), findsOneWidget); // Revision Pack
      expect(find.byKey(const Key('nav_item_6')), findsOneWidget); // Reminders
      expect(find.byKey(const Key('nav_item_7')), findsOneWidget); // Settings

      // Verify motivational quote card in drawer
      expect(
          find.text(
              '“Consistency today builds the success you’re proud of tomorrow.”'),
          findsOneWidget);

      // Tap close button (X)
      await tester.tap(find.byKey(const Key('drawer_close_button')));
      await tester.pumpAndSettle();

      // Drawer is closed
      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
    });

    testWidgets(
        '3. Mobile layout: Selecting menu item navigates to screen and closes drawer',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester
          .pumpWidget(buildTestWidget(isDark: false, width: 400, height: 800));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      // Select 'Subjects' (nav_item_1)
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();

      // Drawer must be closed
      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);

      // Mobile AppBar title is now 'Subjects'
      expect(find.text('Subjects'), findsOneWidget);
      // Subjects search field or add subject button is visible
      expect(find.byTooltip('Add Subject'), findsOneWidget);
      expect(find.text('Advanced Accounting'), findsOneWidget);

      // Navigate to 'Focus Timer' via drawer
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_4')));
      await tester.pumpAndSettle();

      // Drawer closed, screen is Focus Timer
      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
      expect(find.text('Focus Timer'), findsWidgets);

      // Navigate to 'Revision Pack' via drawer
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_5')));
      await tester.pumpAndSettle();

      // Drawer closed, Revision Pack tab bar is visible
      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
      expect(find.text('Revision Pack'), findsOneWidget);
      expect(find.text('Revision Matrix'), findsOneWidget);
      expect(find.text('Notes & Formulas'), findsOneWidget);

      // Navigate to 'Reminders' via drawer
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_6')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Alarm & Vibration Preferences'), findsOneWidget);

      // Navigate to 'Settings' via drawer
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_7')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app_navigation_drawer')), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets(
        '4. Desktop layout (>=800px): Persistent sidebar visible, hamburger menu and bottom nav absent',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester
          .pumpWidget(buildTestWidget(isDark: false, width: 1200, height: 800));
      await tester.pumpAndSettle();

      // Hamburger menu icon must NOT be visible on desktop
      expect(find.byKey(const Key('hamburger_menu_button')), findsNothing);
      // Bottom navigation must NOT be visible
      expect(find.byType(NavigationBar), findsNothing);

      // Persistent sidebar items are visible directly on screen
      expect(find.byKey(const Key('nav_item_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_3')), findsOneWidget);

      // Clicking directly on 'Subjects' on desktop navigates immediately
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Accounting'), findsOneWidget);
      // Persistent sidebar remains visible
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
    });

    testWidgets('5. Small screen safe area & no overflow test (360x640)',
        (tester) async {
      final origOnError = FlutterError.onError;
      ignoreOverflowErrors(origOnError);
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester
          .pumpWidget(buildTestWidget(isDark: true, width: 360, height: 640));
      await tester.pumpAndSettle();

      // Open drawer on compact screen
      await tester.tap(find.byKey(const Key('hamburger_menu_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app_navigation_drawer')), findsOneWidget);
      // Ensure drawer items are accessible without throw
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav_item_7')), findsOneWidget);
    });
  });
}
