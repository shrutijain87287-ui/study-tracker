import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan.dart';
import '../models/class_model.dart';
import '../models/note_model.dart';
import 'auth_service.dart';

class ReminderSettings {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ReminderVibrationPattern vibrationPattern;
  final int snoozeDurationMinutes;

  const ReminderSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.vibrationPattern = ReminderVibrationPattern.standard,
    this.snoozeDurationMinutes = 5,
  });

  ReminderSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    ReminderVibrationPattern? vibrationPattern,
    int? snoozeDurationMinutes,
  }) {
    return ReminderSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'vibrationPattern': vibrationPattern.name,
        'snoozeDurationMinutes': snoozeDurationMinutes,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    ReminderVibrationPattern pat = ReminderVibrationPattern.standard;
    if (json.containsKey('vibrationPattern')) {
      final pStr = json['vibrationPattern'] as String?;
      pat = ReminderVibrationPattern.values.firstWhere(
        (e) => e.name == pStr,
        orElse: () => ReminderVibrationPattern.standard,
      );
    }

    return ReminderSettings(
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      vibrationPattern: pat,
      snoozeDurationMinutes:
          (json['snoozeDurationMinutes'] as num?)?.toInt() ?? 5,
    );
  }
}

class StorageService {
  static const String _keyPlans = 'study_plans_v2';
  static const String _keyActivePlanId = 'active_study_plan_id';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyUserName = 'user_display_name';
  static const String _keyReminderSettings = 'reminder_alarm_settings';
  static const String _keySavedClasses = 'study_saved_classes';
  static const String _keyRecentClassesSearches = 'recent_classes_searches';
  static const String _keyYouTubeApiKey = 'youtube_api_key';
  static const String _keyNotebooks = 'digital_notebooks_v1';

  // Legacy keys from earlier CA Inter tracker version for seamless backward compatibility
  static const String _legacyKeySubjects = 'subjects';
  static const String _legacyKeyReminders = 'reminders';
  static const String _legacyKeyPrimaryTarget = 'primaryTarget';
  static const String _legacyKeyBackupTarget = 'backupTarget';
  static const String _legacyKeyPrimaryDate = 'primaryDate';
  static const String _legacyKeyBackupDate = 'backupDate';

  static String? _activeUserId;

  /// Sets the active user context for local storage scoping.
  static void setActiveUserId(String? uid) {
    _activeUserId = (uid != null && uid.trim().isNotEmpty) ? uid.trim() : null;
  }

  @visibleForTesting
  static void resetTestingState() {
    _activeUserId = null;
  }

  /// Current active user UID, or null if unauthenticated.
  static String? get activeUserId => _activeUserId;

  /// Effective user ID, falling back to AuthService.currentUid if activeUserId is not set.
  static String? get effectiveUserId => _activeUserId ?? AuthService.currentUid;

  /// Resolves the storage key scoped to the active or specified user.
  /// If [explicitUid] is empty string (''), returns un-scoped [baseKey].
  /// If [explicitUid] or [effectiveUserId] is present, returns 'user_${uid}_$baseKey'.
  /// If unauthenticated guest session, returns un-scoped [baseKey].
  static String _resolveKey(String baseKey, [String? explicitUid]) {
    if (explicitUid == '') {
      return baseKey;
    }
    final uid = (explicitUid != null && explicitUid.trim().isNotEmpty)
        ? explicitUid.trim()
        : effectiveUserId;
    if (uid != null && uid.isNotEmpty) {
      return 'user_${uid}_$baseKey';
    }
    return baseKey;
  }

  static Future<SharedPreferences> _getPrefs() =>
      SharedPreferences.getInstance();

  /// Migrates legacy un-scoped data to the authenticated user's scoped keys once.
  /// Then removes the un-scoped keys so no subsequent user account ever inherits them.
  static Future<void> _maybeMigrateLegacyData(
      String uid, SharedPreferences prefs) async {
    final userKey = 'user_${uid}_$_keyPlans';
    if (prefs.containsKey(userKey)) return;

    final legacyPlans = prefs.getString(_keyPlans);
    if (legacyPlans != null && legacyPlans.isNotEmpty) {
      await prefs.setString(userKey, legacyPlans);
      await prefs.remove(_keyPlans);
    }

    final legacyActiveId = prefs.getString(_keyActivePlanId);
    if (legacyActiveId != null) {
      await prefs.setString('user_${uid}_$_keyActivePlanId', legacyActiveId);
      await prefs.remove(_keyActivePlanId);
    }

    final legacyUser = prefs.getString(_keyUserName);
    if (legacyUser != null) {
      await prefs.setString('user_${uid}_$_keyUserName', legacyUser);
      await prefs.remove(_keyUserName);
    }

    final legacyReminders = prefs.getString(_keyReminderSettings);
    if (legacyReminders != null) {
      await prefs.setString(
          'user_${uid}_$_keyReminderSettings', legacyReminders);
      await prefs.remove(_keyReminderSettings);
    }

    final legacyClasses = prefs.getString(_keySavedClasses);
    if (legacyClasses != null) {
      await prefs.setString('user_${uid}_$_keySavedClasses', legacyClasses);
      await prefs.remove(_keySavedClasses);
    }

    final legacySearches = prefs.getStringList(_keyRecentClassesSearches);
    if (legacySearches != null) {
      await prefs.setStringList(
          'user_${uid}_$_keyRecentClassesSearches', legacySearches);
      await prefs.remove(_keyRecentClassesSearches);
    }

    final legacyNotebooks = prefs.getString(_keyNotebooks);
    if (legacyNotebooks != null) {
      await prefs.setString('user_${uid}_$_keyNotebooks', legacyNotebooks);
      await prefs.remove(_keyNotebooks);
    }

    final legacyDark = prefs.getBool(_keyDarkMode);
    if (legacyDark != null) {
      await prefs.setBool('user_${uid}_$_keyDarkMode', legacyDark);
      await prefs.remove(_keyDarkMode);
    }
  }

  static Future<List<StudyPlan>> loadPlans({String? uid}) async {
    final targetUid = uid ?? effectiveUserId;
    final prefs = await _getPrefs();

    if (targetUid != null && targetUid.isNotEmpty) {
      await _maybeMigrateLegacyData(targetUid, prefs);
    }

    final key = _resolveKey(_keyPlans, targetUid);
    final rawPlans = prefs.getString(key);

    if (rawPlans != null && rawPlans.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPlans) as List;
        return decoded
            .map((p) => StudyPlan.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
      } catch (e) {
        // Fallback or attempt repair
      }
    }

    // Check for legacy data to migrate
    final legacySubjectsRaw = prefs.getString(_legacyKeySubjects);
    if (legacySubjectsRaw != null && legacySubjectsRaw.isNotEmpty) {
      try {
        final decodedSubjects = jsonDecode(legacySubjectsRaw) as List;
        if (decodedSubjects.isNotEmpty) {
          final subjects = decodedSubjects
              .map((s) => Subject.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();

          final primaryTarget =
              prefs.getString(_legacyKeyPrimaryTarget) ?? 'Target Exam';
          final backupTarget =
              prefs.getString(_legacyKeyBackupTarget) ?? 'Backup Target';
          final pDateStr = prefs.getString(_legacyKeyPrimaryDate);
          final bDateStr = prefs.getString(_legacyKeyBackupDate);

          final remindersRaw = prefs.getString(_legacyKeyReminders) ?? '[]';
          final reminders = (jsonDecode(remindersRaw) as List)
              .map((r) =>
                  StudyReminder.fromJson(Map<String, dynamic>.from(r as Map)))
              .toList();

          final migratedPlan = StudyPlan(
            id: 'migrated_plan_1',
            title: 'My Study Plan',
            category: 'Exam Preparation',
            primaryTargetLabel: primaryTarget,
            primaryTargetDate: (pDateStr != null && pDateStr.isNotEmpty)
                ? DateTime.tryParse(pDateStr)
                : null,
            backupTargetLabel: backupTarget,
            backupTargetDate: (bDateStr != null && bDateStr.isNotEmpty)
                ? DateTime.tryParse(bDateStr)
                : null,
            subjects: subjects,
            reminders: reminders,
          );

          final plans = [migratedPlan];
          await savePlans(plans, uid: targetUid);
          await saveActivePlanId(migratedPlan.id, uid: targetUid);
          return plans;
        }
      } catch (_) {}
    }

    return [];
  }

  static Future<void> savePlans(List<StudyPlan> plans, {String? uid}) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(plans.map((p) => p.toJson()).toList());
    await prefs.setString(_resolveKey(_keyPlans, uid), encoded);
  }

  static Future<String?> loadActivePlanId({String? uid}) async {
    final prefs = await _getPrefs();
    return prefs.getString(_resolveKey(_keyActivePlanId, uid));
  }

  static Future<void> saveActivePlanId(String id, {String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.setString(_resolveKey(_keyActivePlanId, uid), id);
  }

  static Future<bool> loadDarkMode({String? uid}) async {
    final prefs = await _getPrefs();
    return prefs.getBool(_resolveKey(_keyDarkMode, uid)) ??
        prefs.getBool(_keyDarkMode) ??
        false;
  }

  static Future<void> saveDarkMode(bool isDark, {String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_resolveKey(_keyDarkMode, uid), isDark);
    await prefs.setBool(_keyDarkMode, isDark);
  }

  static Future<String?> loadUserName({String? uid}) async {
    final prefs = await _getPrefs();
    return prefs.getString(_resolveKey(_keyUserName, uid));
  }

  static Future<void> saveUserName(String name, {String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.setString(_resolveKey(_keyUserName, uid), name);
  }

  static Future<ReminderSettings> loadReminderSettings({String? uid}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_resolveKey(_keyReminderSettings, uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return ReminderSettings.fromJson(decoded);
      } catch (_) {}
    }
    return const ReminderSettings();
  }

  static Future<void> saveReminderSettings(ReminderSettings settings,
      {String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.setString(
        _resolveKey(_keyReminderSettings, uid), jsonEncode(settings.toJson()));
  }

  // ==========================================
  // SAVED CLASSES & SEARCHES (CLASSES HUB)
  // ==========================================

  static Future<List<SavedClass>> loadSavedClasses({String? uid}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_resolveKey(_keySavedClasses, uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map(
                (c) => SavedClass.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveSavedClasses(List<SavedClass> list,
      {String? uid}) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
    await prefs.setString(_resolveKey(_keySavedClasses, uid), encoded);
  }

  static Future<SavedClass> addOrUpdateSavedClass(SavedClass item,
      {String? uid}) async {
    final list = await loadSavedClasses(uid: uid);
    final index = list.indexWhere((c) => c.videoId == item.videoId);
    if (index >= 0) {
      item.updatedAt = DateTime.now();
      list[index] = item;
    } else {
      list.insert(0, item);
    }
    await saveSavedClasses(list, uid: uid);
    return item;
  }

  static Future<void> removeSavedClass(String videoId, {String? uid}) async {
    final list = await loadSavedClasses(uid: uid);
    list.removeWhere((c) => c.videoId == videoId || c.id == videoId);
    await saveSavedClasses(list, uid: uid);
  }

  static Future<List<String>> loadRecentClassesSearches({String? uid}) async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_resolveKey(_keyRecentClassesSearches, uid)) ??
        [];
  }

  static Future<void> addRecentClassesSearch(String query, {String? uid}) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final prefs = await _getPrefs();
    final key = _resolveKey(_keyRecentClassesSearches, uid);
    final list = prefs.getStringList(key) ?? [];
    list.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);
    if (list.length > 10) {
      list.removeRange(10, list.length);
    }
    await prefs.setStringList(key, list);
  }

  static Future<void> clearRecentClassesSearches({String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.remove(_resolveKey(_keyRecentClassesSearches, uid));
  }

  static Future<String?> loadYouTubeApiKey({String? uid}) async {
    final prefs = await _getPrefs();
    return prefs.getString(_resolveKey(_keyYouTubeApiKey, uid)) ??
        prefs.getString(_keyYouTubeApiKey);
  }

  static Future<void> saveYouTubeApiKey(String? key, {String? uid}) async {
    final prefs = await _getPrefs();
    final userKey = _resolveKey(_keyYouTubeApiKey, uid);
    if (key == null || key.trim().isEmpty) {
      await prefs.remove(userKey);
      await prefs.remove(_keyYouTubeApiKey);
    } else {
      await prefs.setString(userKey, key.trim());
      await prefs.setString(_keyYouTubeApiKey, key.trim());
    }
  }

  // ==========================================
  // DIGITAL NOTEBOOKS PERSISTENCE
  // ==========================================
  static Future<List<Notebook>> loadNotebooks({String? uid}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_resolveKey(_keyNotebooks, uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .map((item) =>
                Notebook.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        // Remove legacy sample starter notebook if present, while safely preserving all real notebooks
        final hadStarter = list.any((n) => n.id == 'nb_welcome_starter');
        if (hadStarter) {
          list.removeWhere((n) => n.id == 'nb_welcome_starter');
          await saveNotebooks(list, uid: uid);
        }
        return list;
      } catch (e) {
        // Safe fallback on corrupted JSON
      }
    }
    // Return empty list when no notebooks exist - never auto-seed placeholder notes
    return [];
  }

  static Future<void> saveNotebooks(List<Notebook> notebooks,
      {String? uid}) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(notebooks.map((n) => n.toJson()).toList());
    await prefs.setString(_resolveKey(_keyNotebooks, uid), encoded);
  }

  static Future<void> saveNotebook(Notebook notebook, {String? uid}) async {
    final list = await loadNotebooks(uid: uid);
    final index = list.indexWhere((n) => n.id == notebook.id);
    if (index >= 0) {
      list[index] = notebook;
    } else {
      list.insert(0, notebook);
    }
    await saveNotebooks(list, uid: uid);
  }

  static Future<void> deleteNotebook(String notebookId, {String? uid}) async {
    final list = await loadNotebooks(uid: uid);
    list.removeWhere((n) => n.id == notebookId);
    await saveNotebooks(list, uid: uid);
  }

  static Future<Notebook?> getNotebookById(String id, {String? uid}) async {
    final list = await loadNotebooks(uid: uid);
    return list.where((n) => n.id == id).firstOrNull;
  }

  static Future<List<Notebook>> getNotebooksForClass(String videoId,
      {String? uid}) async {
    final list = await loadNotebooks(uid: uid);
    return list.where((n) => n.linkedVideoId == videoId).toList();
  }

  static Future<List<Notebook>> getNotebooksForSubject(String subjectId,
      {String? uid}) async {
    final list = await loadNotebooks(uid: uid);
    return list.where((n) => n.subjectId == subjectId).toList();
  }

  // Backup Export
  static String exportBackupJson(List<StudyPlan> plans) {
    final backupData = {
      'appName': 'Study Tracker',
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'plans': plans.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  // Backup Import
  static List<StudyPlan> importBackupJson(String rawJson) {
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    if (data.containsKey('plans')) {
      final list = data['plans'] as List;
      return list
          .map((p) => StudyPlan.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } else if (data.containsKey('subjects')) {
      // Legacy single-plan export format
      final subjects = (data['subjects'] as List)
          .map((s) => Subject.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
      return [
        StudyPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: data['primaryTarget'] as String? ?? 'Restored Plan',
          subjects: subjects,
        )
      ];
    }
    throw const FormatException(
        'Unrecognized backup format. Please ensure valid Study Tracker JSON.');
  }

  /// Clears all stored data from preferences (both user-scoped and global).
  static Future<void> clearAllData() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }

  /// Clears all local storage keys belonging specifically to [uid].
  static Future<void> clearUserData(String uid) async {
    final prefs = await _getPrefs();
    final prefix = 'user_${uid}_';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Clears local storage keys belonging to the currently active user session.
  static Future<void> clearActiveUserData() async {
    final uid = effectiveUserId;
    if (uid != null) {
      await clearUserData(uid);
    } else {
      final prefs = await _getPrefs();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('guest_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    }
  }
}
