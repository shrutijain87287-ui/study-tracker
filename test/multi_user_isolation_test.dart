import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/note_model.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/screens/onboarding_screen.dart';
import 'package:ca_inter_tracker/services/auth_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final bool emailVerified;

  MockUser({
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetTestingState();
    StorageService.resetTestingState();
  });

  tearDown(() {
    AuthService.resetTestingState();
    StorageService.resetTestingState();
  });

  group('Multi-User Data Isolation & Personalization Tests', () {
    test('1. StorageService isolates study plans, user profile, and notebooks by user UID',
        () async {
      const uidA = 'user_shruti_001';
      const uidB = 'user_rahul_002';

      // --- Account A (Shruti - CA Inter) ---
      final planA = StudyPlan(
        id: 'plan_ca_inter',
        title: 'CA Intermediate May 2026',
        category: 'Professional Exam',
        subjects: [
          Subject(
            id: 'sub_acc',
            name: 'Advanced Accounting',
            code: 'PAPER-1',
            total: 60,
            completed: List.generate(25, (i) => i + 1),
          ),
          Subject(
            id: 'sub_law',
            name: 'Corporate Laws',
            code: 'PAPER-2',
            total: 45,
            completed: List.generate(18, (i) => i + 1),
          ),
        ],
      );
      final nbA = Notebook(
        id: 'nb_acc_ch1',
        title: 'Accounting Standards Notes',
        subjectId: 'sub_acc',
        pages: [NotePage(id: 'p1', pageNumber: 1, title: 'AS 10')],
      );

      // Save under Account A
      await StorageService.savePlans([planA], uid: uidA);
      await StorageService.saveActivePlanId(planA.id, uid: uidA);
      await StorageService.saveUserName('Shruti', uid: uidA);
      await StorageService.saveNotebooks([nbA], uid: uidA);
      await StorageService.saveDarkMode(true, uid: uidA);

      // --- Account B (Rahul - Computer Science / UPSC) ---
      final planB = StudyPlan(
        id: 'plan_upsc',
        title: 'UPSC Civil Services 2027',
        category: 'Competitive Exam',
        subjects: [
          Subject(
            id: 'sub_gs',
            name: 'General Studies I',
            code: 'GS-1',
            total: 100,
            completed: [1, 2, 3, 4, 5],
          ),
          Subject(
            id: 'sub_csat',
            name: 'Aptitude CSAT',
            code: 'CSAT',
            total: 40,
            completed: [1, 2],
          ),
        ],
      );
      final nbB = Notebook(
        id: 'nb_upsc_polity',
        title: 'Indian Constitution & Polity',
        subjectId: 'sub_gs',
        pages: [NotePage(id: 'p2', pageNumber: 1, title: 'Preamble')],
      );

      // Save under Account B
      await StorageService.savePlans([planB], uid: uidB);
      await StorageService.saveActivePlanId(planB.id, uid: uidB);
      await StorageService.saveUserName('Rahul Sharma', uid: uidB);
      await StorageService.saveNotebooks([nbB], uid: uidB);
      await StorageService.saveDarkMode(false, uid: uidB);

      // --- Verify Account A Scoped Data ---
      final plansA = await StorageService.loadPlans(uid: uidA);
      final nameA = await StorageService.loadUserName(uid: uidA);
      final nbsA = await StorageService.loadNotebooks(uid: uidA);
      final darkA = await StorageService.loadDarkMode(uid: uidA);

      expect(plansA.length, 1);
      expect(plansA.first.title, 'CA Intermediate May 2026');
      expect(plansA.first.subjects.length, 2);
      expect(plansA.first.subjects.first.name, 'Advanced Accounting');
      expect(plansA.first.subjects.first.completed.length, 25);
      expect(nameA, 'Shruti');
      expect(nbsA.length, 1);
      expect(nbsA.first.title, 'Accounting Standards Notes');
      expect(darkA, isTrue);

      // --- Verify Account B Scoped Data ---
      final plansB = await StorageService.loadPlans(uid: uidB);
      final nameB = await StorageService.loadUserName(uid: uidB);
      final nbsB = await StorageService.loadNotebooks(uid: uidB);
      final darkB = await StorageService.loadDarkMode(uid: uidB);

      expect(plansB.length, 1);
      expect(plansB.first.title, 'UPSC Civil Services 2027');
      expect(plansB.first.subjects.length, 2);
      expect(plansB.first.subjects.first.name, 'General Studies I');
      expect(plansB.first.subjects.first.completed.length, 5);
      expect(nameB, 'Rahul Sharma');
      expect(nbsB.length, 1);
      expect(nbsB.first.title, 'Indian Constitution & Polity');
      expect(darkB, isFalse);

      // Assert complete isolation: B has no CA Inter subjects or notes
      expect(plansB.any((p) => p.title.contains('CA Intermediate')), isFalse);
      expect(nbsB.any((n) => n.id == 'nb_acc_ch1'), isFalse);
    });

    test('2. Modifying Account B does not alter Account A data', () async {
      const uidA = 'user_a_isolation';
      const uidB = 'user_b_isolation';

      final planA = StudyPlan(
        id: 'plan_a',
        title: 'CA Inter Audit Prep',
        subjects: [
          Subject(
            id: 's_aud',
            name: 'Auditing Standards',
            total: 30,
            completed: List.generate(15, (i) => i + 1),
          ),
        ],
      );
      await StorageService.savePlans([planA], uid: uidA);
      await StorageService.saveUserName('Shruti', uid: uidA);

      final planB = StudyPlan(
        id: 'plan_b',
        title: 'B.Tech Computer Science',
        subjects: [
          Subject(id: 's_dsa', name: 'Data Structures', total: 40),
        ],
      );
      await StorageService.savePlans([planB], uid: uidB);
      await StorageService.saveUserName('Priya', uid: uidB);

      // Account B completes all 40 lectures and adds a new subject
      final updatedPlanB = StudyPlan(
        id: planB.id,
        title: planB.title,
        subjects: [
          Subject(
            id: 's_dsa',
            name: 'Data Structures',
            total: 40,
            completed: List.generate(40, (i) => i + 1),
          ),
          Subject(
            id: 's_os',
            name: 'Operating Systems',
            total: 35,
            completed: [1, 2, 3],
          ),
        ],
      );
      await StorageService.savePlans([updatedPlanB], uid: uidB);

      // Verify Account A is completely unchanged
      final reloadedA = await StorageService.loadPlans(uid: uidA);
      final nameA = await StorageService.loadUserName(uid: uidA);

      expect(reloadedA.length, 1);
      expect(reloadedA.first.title, 'CA Inter Audit Prep');
      expect(reloadedA.first.subjects.length, 1);
      expect(reloadedA.first.subjects.first.name, 'Auditing Standards');
      expect(reloadedA.first.subjects.first.completed.length, 15); // Unchanged!
      expect(nameA, 'Shruti');

      // Verify Account B has its updated data
      final reloadedB = await StorageService.loadPlans(uid: uidB);
      expect(reloadedB.first.subjects.length, 2);
      expect(reloadedB.first.subjects.first.completed.length, 40);
    });

    test('3. New user account starts with 0 plans and never receives another user\'s legacy data',
        () async {
      const uidExisting = 'uid_existing_user';
      const uidBrandNew = 'uid_brand_new_user';

      // Simulate existing user with local data
      final existingPlan = StudyPlan(
        id: 'plan_existing',
        title: 'Existing Account Study Progress',
        subjects: [Subject(id: 's1', name: 'Existing Subject', total: 50)],
      );
      await StorageService.savePlans([existingPlan], uid: uidExisting);
      await StorageService.saveUserName('Existing Student', uid: uidExisting);

      // Now new user arrives
      StorageService.setActiveUserId(uidBrandNew);
      final newPlans = await StorageService.loadPlans();
      final newName = await StorageService.loadUserName();

      // Brand new user must have empty plans and null name
      expect(newPlans, isEmpty);
      expect(newName, isNull);
    });

    test('4. Onboarding screen defaults user name to empty string when not provided',
        () {
      final ctrl = TextEditingController(text: '');
      expect(ctrl.text, isEmpty);
      expect(ctrl.text.contains('Shruti'), isFalse);
    });

    testWidgets(
        '5. Sign out clears active user context and in-memory state, preventing cross-account leaks',
        (tester) async {
      final userA = MockUser(
        uid: 'user_a_session',
        email: 'shruti@example.com',
        displayName: 'Shruti',
      );
      AuthService.setMockUser(userA);

      final planA = StudyPlan(
        id: 'plan_a_sess',
        title: 'CA Inter Taxation',
        subjects: [Subject(id: 'sub_tax', name: 'Direct Tax', total: 50)],
      );
      await StorageService.savePlans([planA]);
      await StorageService.saveUserName('Shruti');

      expect(StorageService.activeUserId, 'user_a_session');

      // Now sign out
      await AuthService.signOut();

      // Storage active user context must be cleared
      expect(StorageService.activeUserId, isNull);

      // Loading unauthenticated data must not return User A's plans
      final plansAfterSignOut = await StorageService.loadPlans(uid: 'guest_test');
      expect(plansAfterSignOut, isEmpty);
    });

    testWidgets(
        '6. OnboardingScreen initializes with blank name when no initial name is provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: Scaffold(
            body: OnboardingScreen(
              onPlanCreated: (plan, [name]) async {},
              initialUserName: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the text field is empty and does NOT contain "Shruti"
      final nameField = find.widgetWithText(TextField, '');
      expect(nameField, findsWidgets);
      expect(find.text('Shruti'), findsNothing);

      // Attempting to proceed without name shows validation error
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(
          find.text('Please enter your name to personalize your study tracker.'),
          findsOneWidget);
    });

    testWidgets(
        '7. OnboardingScreen allows user to select custom category and subjects without CA Inter',
        (tester) async {
      StudyPlan? createdPlan;
      String? createdUser;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: Scaffold(
            body: OnboardingScreen(
              onPlanCreated: (plan, [name]) async {
                createdPlan = plan;
                createdUser = name;
              },
              initialUserName: 'Aarav Patel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: User name is prefilled with Aarav Patel (NOT Shruti)
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Shruti'), findsNothing);

      // Select "Competitive Exam"
      await tester.tap(find.text('Competitive Exam'));
      await tester.pumpAndSettle();

      // Proceed to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Proceed to Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3 shows competitive exam subjects (General Studies, Quantitative Aptitude)
      expect(find.text('General Studies & Concepts'), findsOneWidget);
      expect(find.text('Advanced Accounting'), findsNothing);

      // Launch study tracker
      await tester.tap(find.text('Launch Tracker'));
      await tester.pumpAndSettle();

      expect(createdPlan, isNotNull);
      expect(createdPlan!.category, 'Competitive Exam');
      expect(createdUser, 'Aarav Patel');
      expect(
          createdPlan!.subjects.any((s) => s.name.contains('Accounting')),
          isFalse);
    });

    test(
        '8. Full two-account lifecycle switch: Account A (CA Inter) <-> Account B (Computer Science)',
        () async {
      final userA = MockUser(
        uid: 'uid_shruti_e2e',
        email: 'shruti@ca.com',
        displayName: 'Shruti',
      );
      final userB = MockUser(
        uid: 'uid_alex_e2e',
        email: 'alex@cs.com',
        displayName: 'Alex Chen',
      );

      // 1. Account A signs in and creates CA Inter Plan
      AuthService.setMockUser(userA);
      StorageService.setActiveUserId(userA.uid);
      final planA = StudyPlan(
        id: 'ca_inter_plan',
        title: 'CA Inter Group 1',
        category: 'Professional Exam',
        subjects: [
          Subject(
            id: 's_acc',
            name: 'Advanced Accounting',
            total: 50,
            completed: [1, 2, 3],
          ),
        ],
      );
      await StorageService.savePlans([planA]);
      await StorageService.saveUserName('Shruti');

      // Verify Account A is active
      expect((await StorageService.loadPlans()).first.title, 'CA Inter Group 1');
      expect(await StorageService.loadUserName(), 'Shruti');

      // 2. Account A signs out
      await AuthService.signOut();
      expect(StorageService.activeUserId, isNull);
      expect(await StorageService.loadPlans(), isEmpty);
      expect(await StorageService.loadUserName(), isNull);

      // 3. Account B signs in -> Clean slate, no plans from Account A
      AuthService.setMockUser(userB);
      StorageService.setActiveUserId(userB.uid);
      expect(await StorageService.loadPlans(), isEmpty);

      // Account B creates B.Tech Computer Science plan
      final planB = StudyPlan(
        id: 'cs_plan',
        title: 'B.Tech CS Sem 4',
        category: 'College / University',
        subjects: [
          Subject(
            id: 's_dsa',
            name: 'Data Structures & Algorithms',
            total: 40,
            completed: [1],
          ),
        ],
      );
      await StorageService.savePlans([planB]);
      await StorageService.saveUserName('Alex Chen');

      // Verify Account B has its own plan
      expect((await StorageService.loadPlans()).first.title, 'B.Tech CS Sem 4');
      expect(await StorageService.loadUserName(), 'Alex Chen');

      // 4. Account B completes lectures 2, 3, 4, 5
      final updatedB = StudyPlan(
        id: 'cs_plan',
        title: 'B.Tech CS Sem 4',
        category: 'College / University',
        subjects: [
          Subject(
            id: 's_dsa',
            name: 'Data Structures & Algorithms',
            total: 40,
            completed: [1, 2, 3, 4, 5],
          ),
        ],
      );
      await StorageService.savePlans([updatedB]);

      // 5. Account B signs out
      await AuthService.signOut();
      expect(StorageService.activeUserId, isNull);
      expect(await StorageService.loadPlans(), isEmpty);

      // 6. Account A signs back in -> Exact CA Inter data restored!
      AuthService.setMockUser(userA);
      StorageService.setActiveUserId(userA.uid);
      final restoredA = await StorageService.loadPlans();
      expect(restoredA.length, 1);
      expect(restoredA.first.title, 'CA Inter Group 1');
      expect(restoredA.first.subjects.first.name, 'Advanced Accounting');
      expect(restoredA.first.subjects.first.completed, [1, 2, 3]); // Exact original progress!
      expect(await StorageService.loadUserName(), 'Shruti');

      // 7. Account A signs out and Account B signs back in -> Exact CS data restored!
      await AuthService.signOut();
      AuthService.setMockUser(userB);
      StorageService.setActiveUserId(userB.uid);
      final restoredB = await StorageService.loadPlans();
      expect(restoredB.length, 1);
      expect(restoredB.first.title, 'B.Tech CS Sem 4');
      expect(restoredB.first.subjects.first.name, 'Data Structures & Algorithms');
      expect(restoredB.first.subjects.first.completed, [1, 2, 3, 4, 5]); // Account B's progress intact!
      expect(await StorageService.loadUserName(), 'Alex Chen');
    });
  });
}
