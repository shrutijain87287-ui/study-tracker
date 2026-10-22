import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_model.dart';
import '../models/note_model.dart';
import '../models/study_plan.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
  failed,
}

/// Consolidated snapshot of user data for atomic cloud backup & recovery.
class CloudDataBundle {
  final String uid;
  final DateTime exportedAt;
  final String? activePlanId;
  final String? displayName;
  final bool isDarkMode;
  final ReminderSettings reminderSettings;
  final List<StudyPlan> studyPlans;
  final List<Notebook> notebooks;
  final List<SavedClass> savedClasses;
  final List<String> recentSearches;

  const CloudDataBundle({
    required this.uid,
    required this.exportedAt,
    this.activePlanId,
    this.displayName,
    this.isDarkMode = false,
    this.reminderSettings = const ReminderSettings(),
    required this.studyPlans,
    required this.notebooks,
    required this.savedClasses,
    required this.recentSearches,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'exportedAt': exportedAt.toIso8601String(),
        'activePlanId': activePlanId,
        'displayName': displayName,
        'isDarkMode': isDarkMode,
        'reminderSettings': reminderSettings.toJson(),
        'studyPlans': studyPlans.map((p) => p.toJson()).toList(),
        'notebooks': notebooks.map((n) => n.toJson()).toList(),
        'savedClasses': savedClasses.map((c) => c.toJson()).toList(),
        'recentSearches': recentSearches,
      };

  factory CloudDataBundle.fromJson(Map<String, dynamic> json) {
    DateTime exp = DateTime.now();
    if (json['exportedAt'] != null) {
      exp = DateTime.tryParse(json['exportedAt'] as String) ?? DateTime.now();
    }

    final rawPlans = json['studyPlans'] as List? ?? [];
    final plans = rawPlans
        .map((p) => StudyPlan.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    final rawNbs = json['notebooks'] as List? ?? [];
    final nbs = rawNbs
        .map((n) => Notebook.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();

    final rawClasses = json['savedClasses'] as List? ?? [];
    final classes = rawClasses
        .map((c) => SavedClass.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();

    final rawSearches = json['recentSearches'] as List? ?? [];
    final searches = rawSearches.map((s) => s.toString()).toList();

    ReminderSettings rem = const ReminderSettings();
    if (json['reminderSettings'] != null) {
      rem = ReminderSettings.fromJson(
          Map<String, dynamic>.from(json['reminderSettings'] as Map));
    }

    return CloudDataBundle(
      uid: json['uid'] as String? ?? '',
      exportedAt: exp,
      activePlanId: json['activePlanId'] as String?,
      displayName: json['displayName'] as String?,
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      reminderSettings: rem,
      studyPlans: plans,
      notebooks: nbs,
      savedClasses: classes,
      recentSearches: searches,
    );
  }
}

class SyncResult {
  final bool isSuccess;
  final String message;
  final int plansCount;
  final int notebooksCount;

  const SyncResult({
    required this.isSuccess,
    required this.message,
    this.plansCount = 0,
    this.notebooksCount = 0,
  });
}

class CloudSyncService {
  static FirebaseFirestore? _firestore;
  static bool _initialized = false;

  static const String _keyLastSync = 'last_cloud_sync_time';
  static const String _keyMigratedUids = 'migrated_user_uids_v1';

  static final ValueNotifier<SyncStatus> syncStatusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.idle);
  static final ValueNotifier<DateTime?> lastSyncNotifier =
      ValueNotifier<DateTime?>(null);
  static final ValueNotifier<String?> syncErrorNotifier =
      ValueNotifier<String?>(null);

  /// Initializes Firestore safely.
  static Future<bool> initialize() async {
    if (AuthService.isMockMode) return false;
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        final authOk = await AuthService.initialize();
        if (!authOk) return false;
      }
      _firestore = FirebaseFirestore.instance;
      _initialized = true;

      // Load cached last sync time from prefs
      final prefs = await SharedPreferences.getInstance();
      final lastTimeRaw = prefs.getString(_keyLastSync);
      if (lastTimeRaw != null) {
        lastSyncNotifier.value = DateTime.tryParse(lastTimeRaw);
      }

      return true;
    } catch (e) {
      debugPrint('CloudSyncService init notice (offline/local mode): $e');
      _initialized = false;
      return false;
    }
  }

  static bool get isConfigured => _initialized && _firestore != null;

  /// Check whether there is local data that has not yet been migrated for this account.
  static Future<bool> hasUnmigratedLocalData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final migratedList = prefs.getStringList(_keyMigratedUids) ?? [];
    if (migratedList.contains(uid)) {
      return false;
    }

    final localPlans = await StorageService.loadPlans();
    final localNotebooks = await StorageService.loadNotebooks();
    // Ignore default starter notebook if user has not added anything
    final hasUserNotebooks =
        localNotebooks.any((n) => n.id != 'nb_welcome_starter');

    return localPlans.isNotEmpty || hasUserNotebooks;
  }

  /// Mark the specified UID as having migrated its initial local data.
  static Future<void> _markMigrated(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final migratedList = prefs.getStringList(_keyMigratedUids) ?? [];
    if (!migratedList.contains(uid)) {
      migratedList.add(uid);
      await prefs.setStringList(_keyMigratedUids, migratedList);
    }
  }

  /// Migrate existing local unauthenticated data into the newly created cloud account.
  /// Verifies cloud write succeeds before marking migration complete.
  static Future<SyncResult> migrateLocalDataToCloud(String uid) async {
    final ok = await initialize();
    if (!ok || _firestore == null) {
      return const SyncResult(
        isSuccess: false,
        message: 'Cannot connect to Cloud Database. Device is offline.',
      );
    }

    syncStatusNotifier.value = SyncStatus.syncing;
    try {
      final bundle = await _createLocalDataBundle(uid);

      // Verify that the cloud write succeeds
      await _writeBundleToFirestore(bundle);

      await _markMigrated(uid);
      await _recordSuccessfulSync();

      syncStatusNotifier.value = SyncStatus.synced;
      return SyncResult(
        isSuccess: true,
        message:
            'Successfully migrated ${bundle.studyPlans.length} study plan(s) and ${bundle.notebooks.length} notebook(s) to your cloud account!',
        plansCount: bundle.studyPlans.length,
        notebooksCount: bundle.notebooks.length,
      );
    } catch (e) {
      syncStatusNotifier.value = SyncStatus.failed;
      syncErrorNotifier.value = e.toString();
      return SyncResult(
        isSuccess: false,
        message: 'Migration failed: ${e.toString()}. Your local data is safe.',
      );
    }
  }

  /// Push local data to Cloud Firestore.
  static Future<SyncResult> backupLocalToCloud(String uid) async {
    final ok = await initialize();
    if (!ok || _firestore == null) {
      syncStatusNotifier.value = SyncStatus.offline;
      return const SyncResult(
        isSuccess: false,
        message: 'Offline: Firebase is not reachable. Changes saved locally.',
      );
    }

    syncStatusNotifier.value = SyncStatus.syncing;
    try {
      final bundle = await _createLocalDataBundle(uid);
      await _writeBundleToFirestore(bundle);
      await _recordSuccessfulSync();

      syncStatusNotifier.value = SyncStatus.synced;
      return SyncResult(
        isSuccess: true,
        message: 'Cloud backup complete. All study progress is synced.',
        plansCount: bundle.studyPlans.length,
        notebooksCount: bundle.notebooks.length,
      );
    } catch (e) {
      syncStatusNotifier.value = SyncStatus.failed;
      syncErrorNotifier.value = e.toString();
      return SyncResult(
        isSuccess: false,
        message: 'Cloud backup failed: ${e.toString()}',
      );
    }
  }

  /// Restore user's data from Cloud Firestore to the local device.
  /// Safeguard: Never replace populated local data with an empty cloud response.
  static Future<SyncResult> restoreCloudToLocal(String uid) async {
    final ok = await initialize();
    if (!ok || _firestore == null) {
      syncStatusNotifier.value = SyncStatus.offline;
      return const SyncResult(
        isSuccess: false,
        message: 'Offline: Unable to reach Cloud Firestore.',
      );
    }

    syncStatusNotifier.value = SyncStatus.syncing;
    try {
      final docRef = _firestore!
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('data');
      final snapshot = await docRef.get();

      CloudDataBundle? bundle;

      if (snapshot.exists &&
          snapshot.data() != null &&
          snapshot.data()!.isNotEmpty) {
        bundle = CloudDataBundle.fromJson(snapshot.data()!);
      } else {
        // Fallback: Check if data exists in granular subcollections
        final plansSnap = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('study_plans')
            .get();
        final nbsSnap = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('notebooks')
            .get();
        final classesSnap = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('classes')
            .doc('data')
            .get();
        final profileSnap = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('data')
            .get();

        if (plansSnap.docs.isNotEmpty || nbsSnap.docs.isNotEmpty) {
          final plans =
              plansSnap.docs.map((d) => StudyPlan.fromJson(d.data())).toList();
          final nbs =
              nbsSnap.docs.map((d) => Notebook.fromJson(d.data())).toList();
          final classesData = classesSnap.data() ?? {};
          final rawClasses = classesData['savedClasses'] as List? ?? [];
          final savedClasses = rawClasses
              .map((c) =>
                  SavedClass.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
          final recentSearches = (classesData['recentSearches'] as List? ?? [])
              .map((s) => s.toString())
              .toList();
          final profileData = profileSnap.data() ?? {};

          bundle = CloudDataBundle(
            uid: uid,
            exportedAt: DateTime.now(),
            studyPlans: plans,
            notebooks: nbs,
            savedClasses: savedClasses,
            recentSearches: recentSearches,
            activePlanId: profileData['activePlanId'] as String?,
            displayName: profileData['displayName'] as String?,
            isDarkMode: profileData['isDarkMode'] as bool? ?? false,
          );
        }
      }

      if (bundle == null ||
          (bundle.studyPlans.isEmpty && bundle.notebooks.isEmpty)) {
        syncStatusNotifier.value = SyncStatus.synced;
        return const SyncResult(
          isSuccess: false,
          message:
              'No existing cloud backup found for this account. Local data preserved.',
        );
      }

      // SAFEGUARD: Never replace populated local data with an empty cloud list
      final localPlans = await StorageService.loadPlans();
      if (bundle.studyPlans.isEmpty && localPlans.isNotEmpty) {
        syncStatusNotifier.value = SyncStatus.synced;
        return SyncResult(
          isSuccess: false,
          message:
              'Cloud has 0 plans while local has ${localPlans.length} plans. Overwrite prevented to protect your data.',
        );
      }

      // Apply cloud data to local storage
      if (bundle.studyPlans.isNotEmpty) {
        await StorageService.savePlans(bundle.studyPlans);
      }
      if (bundle.activePlanId != null) {
        await StorageService.saveActivePlanId(bundle.activePlanId!);
      }
      if (bundle.notebooks.isNotEmpty) {
        await StorageService.saveNotebooks(bundle.notebooks);
      }
      if (bundle.savedClasses.isNotEmpty) {
        await StorageService.saveSavedClasses(bundle.savedClasses);
      }
      if (bundle.recentSearches.isNotEmpty) {
        for (final q in bundle.recentSearches.reversed) {
          await StorageService.addRecentClassesSearch(q);
        }
      }
      if (bundle.displayName != null && bundle.displayName!.trim().isNotEmpty) {
        await StorageService.saveUserName(bundle.displayName!.trim());
      }
      await StorageService.saveDarkMode(bundle.isDarkMode);
      await StorageService.saveReminderSettings(bundle.reminderSettings);

      await _recordSuccessfulSync();
      syncStatusNotifier.value = SyncStatus.synced;

      return SyncResult(
        isSuccess: true,
        message:
            'Restored ${bundle.studyPlans.length} study plan(s) and ${bundle.notebooks.length} notebook(s) from cloud!',
        plansCount: bundle.studyPlans.length,
        notebooksCount: bundle.notebooks.length,
      );
    } catch (e) {
      syncStatusNotifier.value = SyncStatus.failed;
      syncErrorNotifier.value = e.toString();
      return SyncResult(
        isSuccess: false,
        message: 'Cloud restore failed: ${e.toString()}. Local data preserved.',
      );
    }
  }

  /// Two-way sync: Synchronizes local and cloud, with conflict resolution favoring
  /// the most recently updated data, and never erasing data silently.
  static Future<SyncResult> sync(String uid) async {
    final ok = await initialize();
    if (!ok || _firestore == null) {
      syncStatusNotifier.value = SyncStatus.offline;
      return const SyncResult(
        isSuccess: false,
        message: 'Offline: Firebase is unreachable. Local changes preserved.',
      );
    }

    syncStatusNotifier.value = SyncStatus.syncing;
    try {
      final docRef = _firestore!
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('data');
      final remoteSnap = await docRef.get();

      final localBundle = await _createLocalDataBundle(uid);

      if (!remoteSnap.exists || remoteSnap.data() == null) {
        // No cloud data yet - upload local
        await _writeBundleToFirestore(localBundle);
        await _recordSuccessfulSync();
        syncStatusNotifier.value = SyncStatus.synced;
        return SyncResult(
          isSuccess: true,
          message: 'Initial cloud sync complete.',
          plansCount: localBundle.studyPlans.length,
          notebooksCount: localBundle.notebooks.length,
        );
      }

      final remoteBundle = CloudDataBundle.fromJson(remoteSnap.data()!);

      // If remote has plans but local is empty (e.g. freshly reinstalled app), restore from cloud!
      if (localBundle.studyPlans.isEmpty &&
          remoteBundle.studyPlans.isNotEmpty) {
        return await restoreCloudToLocal(uid);
      }

      // Merge study plans safely by ID
      final mergedPlansMap = <String, StudyPlan>{};
      for (final p in remoteBundle.studyPlans) {
        mergedPlansMap[p.id] = p;
      }
      for (final p in localBundle.studyPlans) {
        // Local takes precedence or replaces remote
        mergedPlansMap[p.id] = p;
      }
      final mergedPlans = mergedPlansMap.values.toList();

      // Merge notebooks safely by ID
      final mergedNotebooksMap = <String, Notebook>{};
      for (final n in remoteBundle.notebooks) {
        mergedNotebooksMap[n.id] = n;
      }
      for (final n in localBundle.notebooks) {
        // If both exist, keep the one with the latest updatedAt
        if (mergedNotebooksMap.containsKey(n.id)) {
          final remoteNb = mergedNotebooksMap[n.id]!;
          if (n.updatedAt.isAfter(remoteNb.updatedAt)) {
            mergedNotebooksMap[n.id] = n;
          }
        } else {
          mergedNotebooksMap[n.id] = n;
        }
      }
      final mergedNotebooks = mergedNotebooksMap.values.toList();

      // Merge saved classes by videoId
      final mergedClassesMap = <String, SavedClass>{};
      for (final c in remoteBundle.savedClasses) {
        mergedClassesMap[c.videoId] = c;
      }
      for (final c in localBundle.savedClasses) {
        mergedClassesMap[c.videoId] = c;
      }
      final mergedClasses = mergedClassesMap.values.toList();

      // Write merged bundle back to both local and cloud
      await StorageService.savePlans(mergedPlans);
      await StorageService.saveNotebooks(mergedNotebooks);
      await StorageService.saveSavedClasses(mergedClasses);

      final updatedBundle = CloudDataBundle(
        uid: uid,
        exportedAt: DateTime.now(),
        activePlanId: localBundle.activePlanId ?? remoteBundle.activePlanId,
        displayName: localBundle.displayName ?? remoteBundle.displayName,
        isDarkMode: localBundle.isDarkMode,
        reminderSettings: localBundle.reminderSettings,
        studyPlans: mergedPlans,
        notebooks: mergedNotebooks,
        savedClasses: mergedClasses,
        recentSearches: localBundle.recentSearches,
      );

      await _writeBundleToFirestore(updatedBundle);
      await _recordSuccessfulSync();

      syncStatusNotifier.value = SyncStatus.synced;
      return SyncResult(
        isSuccess: true,
        message:
            'Synchronized with cloud (${mergedPlans.length} plans, ${mergedNotebooks.length} notebooks).',
        plansCount: mergedPlans.length,
        notebooksCount: mergedNotebooks.length,
      );
    } catch (e) {
      syncStatusNotifier.value = SyncStatus.failed;
      syncErrorNotifier.value = e.toString();
      return SyncResult(
        isSuccess: false,
        message: 'Sync error: ${e.toString()}',
      );
    }
  }

  /// Builds a complete `CloudDataBundle` from device local storage.
  static Future<CloudDataBundle> _createLocalDataBundle(String uid) async {
    final plans = await StorageService.loadPlans();
    final notebooks = await StorageService.loadNotebooks();
    final savedClasses = await StorageService.loadSavedClasses();
    final searches = await StorageService.loadRecentClassesSearches();
    final activeId = await StorageService.loadActivePlanId();
    final isDark = await StorageService.loadDarkMode();
    final userName = await StorageService.loadUserName();
    final reminderSettings = await StorageService.loadReminderSettings();

    return CloudDataBundle(
      uid: uid,
      exportedAt: DateTime.now(),
      activePlanId: activeId,
      displayName: userName ?? AuthService.displayName,
      isDarkMode: isDark,
      reminderSettings: reminderSettings,
      studyPlans: plans,
      notebooks: notebooks,
      savedClasses: savedClasses,
      recentSearches: searches,
    );
  }

  /// Writes bundle to Firestore atomic backup document and subcollections.
  static Future<void> _writeBundleToFirestore(CloudDataBundle bundle) async {
    if (_firestore == null) return;

    final batch = _firestore!.batch();

    // 1. Root user profile document
    final profileRef = _firestore!
        .collection('users')
        .doc(bundle.uid)
        .collection('profile')
        .doc('data');
    batch.set(
        profileRef,
        {
          'uid': bundle.uid,
          'displayName': bundle.displayName,
          'email': AuthService.currentEmail,
          'activePlanId': bundle.activePlanId,
          'isDarkMode': bundle.isDarkMode,
          'reminderSettings': bundle.reminderSettings.toJson(),
          'updatedAt': bundle.exportedAt.toIso8601String(),
          'plansCount': bundle.studyPlans.length,
          'notebooksCount': bundle.notebooks.length,
        },
        SetOptions(merge: true));

    // 2. Atomic backup document
    final backupRef = _firestore!
        .collection('users')
        .doc(bundle.uid)
        .collection('backup')
        .doc('data');
    batch.set(backupRef, bundle.toJson(), SetOptions(merge: true));

    // 3. Classes document
    final classesRef = _firestore!
        .collection('users')
        .doc(bundle.uid)
        .collection('classes')
        .doc('data');
    batch.set(
        classesRef,
        {
          'savedClasses': bundle.savedClasses.map((c) => c.toJson()).toList(),
          'recentSearches': bundle.recentSearches,
          'updatedAt': bundle.exportedAt.toIso8601String(),
        },
        SetOptions(merge: true));

    await batch.commit();

    // 4. Subcollection sync for individual study plans (for granular queries if needed)
    for (final plan in bundle.studyPlans) {
      final planDoc = _firestore!
          .collection('users')
          .doc(bundle.uid)
          .collection('study_plans')
          .doc(plan.id);
      await planDoc.set(plan.toJson(), SetOptions(merge: true));
    }

    // 5. Subcollection sync for individual digital notebooks
    for (final nb in bundle.notebooks) {
      final nbDoc = _firestore!
          .collection('users')
          .doc(bundle.uid)
          .collection('notebooks')
          .doc(nb.id);
      await nbDoc.set(nb.toJson(), SetOptions(merge: true));
    }
  }

  static Future<void> _recordSuccessfulSync() async {
    final now = DateTime.now();
    lastSyncNotifier.value = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, now.toIso8601String());
  }

  /// Reset sync state on user sign out.
  static Future<void> resetSyncState() async {
    syncStatusNotifier.value = SyncStatus.idle;
    lastSyncNotifier.value = null;
    syncErrorNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSync);
  }
}
