import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan.dart';
import '../models/class_model.dart';
import '../models/note_model.dart';

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

  static Future<List<StudyPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPlans = prefs.getString(_keyPlans);

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
          await savePlans(plans);
          await saveActivePlanId(migratedPlan.id);
          return plans;
        }
      } catch (_) {}
    }

    return [];
  }

  static Future<void> savePlans(List<StudyPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(plans.map((p) => p.toJson()).toList());
    await prefs.setString(_keyPlans, encoded);
  }

  static Future<String?> loadActivePlanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActivePlanId);
  }

  static Future<void> saveActivePlanId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActivePlanId, id);
  }

  static Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  static Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDark);
  }

  static Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  static Future<ReminderSettings> loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyReminderSettings);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return ReminderSettings.fromJson(decoded);
      } catch (_) {}
    }
    return const ReminderSettings();
  }

  static Future<void> saveReminderSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReminderSettings, jsonEncode(settings.toJson()));
  }

  // ==========================================
  // SAVED CLASSES & SEARCHES (CLASSES HUB)
  // ==========================================

  static Future<List<SavedClass>> loadSavedClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySavedClasses);
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

  static Future<void> saveSavedClasses(List<SavedClass> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
    await prefs.setString(_keySavedClasses, encoded);
  }

  static Future<SavedClass> addOrUpdateSavedClass(SavedClass item) async {
    final list = await loadSavedClasses();
    final index = list.indexWhere((c) => c.videoId == item.videoId);
    if (index >= 0) {
      item.updatedAt = DateTime.now();
      list[index] = item;
    } else {
      list.insert(0, item);
    }
    await saveSavedClasses(list);
    return item;
  }

  static Future<void> removeSavedClass(String videoId) async {
    final list = await loadSavedClasses();
    list.removeWhere((c) => c.videoId == videoId || c.id == videoId);
    await saveSavedClasses(list);
  }

  static Future<List<String>> loadRecentClassesSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentClassesSearches) ?? [];
  }

  static Future<void> addRecentClassesSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyRecentClassesSearches) ?? [];
    list.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);
    if (list.length > 10) {
      list.removeRange(10, list.length);
    }
    await prefs.setStringList(_keyRecentClassesSearches, list);
  }

  static Future<void> clearRecentClassesSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentClassesSearches);
  }

  static Future<String?> loadYouTubeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYouTubeApiKey);
  }

  static Future<void> saveYouTubeApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      await prefs.remove(_keyYouTubeApiKey);
    } else {
      await prefs.setString(_keyYouTubeApiKey, key.trim());
    }
  }

  // ==========================================
  // DIGITAL NOTEBOOKS PERSISTENCE
  // ==========================================
  static Future<List<Notebook>> loadNotebooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotebooks);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((item) =>
                Notebook.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        // Safe fallback on corrupted JSON
      }
    }
    // Default starter notebook if none exist
    final starter = _createStarterNotebook();
    await saveNotebooks([starter]);
    return [starter];
  }

  static Notebook _createStarterNotebook() {
    final now = DateTime.now();
    return Notebook(
      id: 'nb_welcome_starter',
      title: 'Welcome to Digital Notes 📓',
      description:
          'Your interactive canvas for rich lecture notes, equations & sketches.',
      category: 'General',
      coverColorValue: 0xFF6C52EE, // AppColors.primary
      tags: ['Guide', 'QuickStart', 'Important'],
      isFavorite: true,
      pages: [
        NotePage(
          id: 'page_welcome_1',
          pageNumber: 1,
          title: 'Getting Started with Digital Notes',
          content: '''# Welcome to Digital Notes ✨

Take comprehensive, distraction-free study notes with rich formatting and stylus handwriting.

### Key Features:
• **Rich Text Editor**: Use **Bold**, *Italic*, __Underline__, Headings (H1/H2/H3), and bullet/numbered lists.
• **Handwriting & Drawing**: Switch to the Canvas tab to draw with Pen, Pencil, Highlighter, and Eraser.
• **Multi-Page Support**: Add unlimited pages to each notebook.
• **Class Integration**: Open or create linked notes directly from any saved YouTube class.
• **PDF Export**: Export your notebooks and drawings to print-ready PDF files.

> Tip: Your notes auto-save continuously and survive browser refreshes and app restarts.''',
          backgroundStyle: PageBackgroundStyle.ruled,
          drawingStrokes: [
            const DrawingStroke(
              id: 'stroke_welcome_star',
              points: [
                DrawingPoint(x: 100, y: 120),
                DrawingPoint(x: 140, y: 120),
                DrawingPoint(x: 108, y: 145),
                DrawingPoint(x: 120, y: 105),
                DrawingPoint(x: 132, y: 145),
                DrawingPoint(x: 100, y: 120),
              ],
              colorValue: 0xFFF59E0B, // amber gold
              strokeWidth: 2.5,
              tool: DrawingTool.pen,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<void> saveNotebooks(List<Notebook> notebooks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(notebooks.map((n) => n.toJson()).toList());
    await prefs.setString(_keyNotebooks, encoded);
  }

  static Future<void> saveNotebook(Notebook notebook) async {
    final list = await loadNotebooks();
    final index = list.indexWhere((n) => n.id == notebook.id);
    if (index >= 0) {
      list[index] = notebook;
    } else {
      list.insert(0, notebook);
    }
    await saveNotebooks(list);
  }

  static Future<void> deleteNotebook(String notebookId) async {
    final list = await loadNotebooks();
    list.removeWhere((n) => n.id == notebookId);
    await saveNotebooks(list);
  }

  static Future<Notebook?> getNotebookById(String id) async {
    final list = await loadNotebooks();
    return list.where((n) => n.id == id).firstOrNull;
  }

  static Future<List<Notebook>> getNotebooksForClass(String videoId) async {
    final list = await loadNotebooks();
    return list.where((n) => n.linkedVideoId == videoId).toList();
  }

  static Future<List<Notebook>> getNotebooksForSubject(String subjectId) async {
    final list = await loadNotebooks();
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

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPlans);
    await prefs.remove(_keyActivePlanId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyReminderSettings);
    await prefs.remove(_keySavedClasses);
    await prefs.remove(_keyRecentClassesSearches);
    await prefs.remove(_keyYouTubeApiKey);
    await prefs.remove(_keyNotebooks);
    await prefs.remove(_legacyKeySubjects);
    await prefs.remove(_legacyKeyReminders);
    await prefs.remove(_legacyKeyPrimaryTarget);
    await prefs.remove(_legacyKeyBackupTarget);
    await prefs.remove(_legacyKeyPrimaryDate);
    await prefs.remove(_legacyKeyBackupDate);
  }
}
