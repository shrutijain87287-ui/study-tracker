import 'package:flutter/material.dart';
import 'models/study_plan.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }
  try {
    await AuthService.initialize();
    await CloudSyncService.initialize();
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }
  runApp(const StudyTrackerApp());
}

class StudyTrackerApp extends StatefulWidget {
  const StudyTrackerApp({super.key});

  @override
  State<StudyTrackerApp> createState() => _StudyTrackerAppState();
}

class _StudyTrackerAppState extends State<StudyTrackerApp> {
  bool _isDark = false;
  bool _isLoading = true;
  List<StudyPlan> _plans = [];
  String? _activePlanId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  Future<void> _loadAppState() async {
    final uid = AuthService.currentUid;
    if (uid != null) {
      try {
        await CloudSyncService.sync(uid);
      } catch (e) {
        debugPrint('Cloud sync during app startup: $e');
      }
    }

    final dark = await StorageService.loadDarkMode();
    final plans = await StorageService.loadPlans();
    final userName = await StorageService.loadUserName();
    String? activeId = await StorageService.loadActivePlanId();

    if (plans.isNotEmpty &&
        (activeId == null || !plans.any((p) => p.id == activeId))) {
      activeId = plans.first.id;
    }

    if (mounted) {
      setState(() {
        _isDark = dark;
        _plans = plans;
        _userName = userName;
        _activePlanId = activeId;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTheme() async {
    final newMode = !_isDark;
    setState(() => _isDark = newMode);
    await StorageService.saveDarkMode(newMode);
  }

  Future<void> _onPlanCreated(StudyPlan newPlan, [String? userName]) async {
    final updatedPlans = [..._plans, newPlan];
    await StorageService.savePlans(updatedPlans);
    await StorageService.saveActivePlanId(newPlan.id);
    if (userName != null && userName.trim().isNotEmpty) {
      await StorageService.saveUserName(userName.trim());
    }
    setState(() {
      _plans = updatedPlans;
      _activePlanId = newPlan.id;
      if (userName != null && userName.trim().isNotEmpty) {
        _userName = userName.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(isDark: false),
      darkTheme: buildAppTheme(isDark: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _plans.isEmpty
              ? OnboardingScreen(
                  onPlanCreated: _onPlanCreated,
                  initialUserName:
                      _userName ?? Uri.base.queryParameters['user'],
                )
              : HomeShell(
                  initialPlans: _plans,
                  activePlanId: _activePlanId ?? _plans.first.id,
                  isDark: _isDark,
                  userName: _userName,
                  onToggleTheme: _toggleTheme,
                  onReloadAll: _loadAppState,
                ),
    );
  }
}
