import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/study_plan.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/auth_screen.dart';
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<User?>? _authSubscription;

  bool _isDark = false;
  bool _isAuthResolved = false;
  bool _isLoading = true;
  User? _currentUser;
  List<StudyPlan> _plans = [];
  String? _activePlanId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _subscribeToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToAuthChanges() {
    _authSubscription = AuthService.authStateChanges.listen((user) async {
      final wasResolved = _isAuthResolved;
      final previousUser = _currentUser;
      _currentUser = user;

      if (!wasResolved) {
        // Initial session resolution on app start or refresh
        await _loadAppState();
        if (mounted) {
          setState(() {
            _isAuthResolved = true;
            _isLoading = false;
          });
        }
      } else if (previousUser?.uid != user?.uid) {
        // Dynamic auth state transition (sign in, sign up, or sign out)
        if (user != null) {
          await _loadAppState();
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          if (mounted) setState(() {});
        } else {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          await _loadAppState();
          if (mounted) setState(() {});
        }
      }
    });
  }

  Future<void> _loadAppState() async {
    final uid = _currentUser?.uid ?? AuthService.currentUid;
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

    final uid = _currentUser?.uid ?? AuthService.currentUid;
    if (uid != null) {
      CloudSyncService.sync(uid).catchError((e) {
        debugPrint('Cloud sync notice after plan creation: $e');
        return const SyncResult(isSuccess: false, message: 'Offline');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Study Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(isDark: false),
      darkTheme: buildAppTheme(isDark: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: !_isAuthResolved || _isLoading
          ? Scaffold(
              backgroundColor:
                  _isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _currentUser == null
              ? AuthScreen(
                  isDismissible: false,
                  onSuccess: _loadAppState,
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
