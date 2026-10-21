enum TrackingType {
  flatLectures, // Simple counter e.g. 50 lectures
  chapters, // Grouped by Chapters -> Topics/Lectures
  tasks, // Checklist of specific tasks/practice sets
}

class StudyNote {
  String id;
  String text;
  String tag;
  DateTime createdAt;

  StudyNote({
    required this.id,
    required this.text,
    this.tag = 'General',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'tag': tag,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] as String? ?? '',
      tag: json['tag'] as String? ?? 'General',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class StudyTask {
  String id;
  String title;
  bool isCompleted;
  String type; // 'Lecture', 'Reading', 'Practice', 'Revision', 'Assignment'
  int estimatedMinutes;

  StudyTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.type = 'Lecture',
    this.estimatedMinutes = 45,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'type': type,
        'estimatedMinutes': estimatedMinutes,
      };

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    return StudyTask(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Task',
      isCompleted: json['isCompleted'] as bool? ?? false,
      type: json['type'] as String? ?? 'Lecture',
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 45,
    );
  }
}

class Chapter {
  String id;
  String title;
  List<StudyTask> topics;

  Chapter({
    required this.id,
    required this.title,
    List<StudyTask>? topics,
  }) : topics = topics ?? [];

  int get totalCount => topics.length;
  int get completedCount => topics.where((t) => t.isCompleted).length;
  bool get isCompleted => totalCount > 0 && completedCount == totalCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'topics': topics.map((t) => t.toJson()).toList(),
      };

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Chapter',
      topics: (json['topics'] as List? ?? [])
          .map((t) => StudyTask.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }
}

class Subject {
  String id;
  String name;
  String code;
  int? colorValue;
  int? iconCodePoint;
  TrackingType trackingType;
  int total; // Used when trackingType == flatLectures
  List<int> completed; // Flat completed lecture indexes (1-based)
  List<Chapter> chapters; // Used when trackingType == chapters
  List<StudyTask> tasks; // Used when trackingType == tasks
  List<StudyNote> notes;
  Map<String, bool> revisionStatus; // e.g. {'R1': true, 'R2': false}

  Subject({
    required this.id,
    required this.name,
    this.code = '',
    this.colorValue,
    this.iconCodePoint,
    this.trackingType = TrackingType.flatLectures,
    this.total = 0,
    List<int>? completed,
    List<Chapter>? chapters,
    List<StudyTask>? tasks,
    List<StudyNote>? notes,
    Map<String, bool>? revisionStatus,
  })  : completed = completed ?? [],
        chapters = chapters ?? [],
        tasks = tasks ?? [],
        notes = notes ?? [],
        revisionStatus = revisionStatus ?? {};

  // Computed total items based on tracking mode
  int get effectiveTotal {
    switch (trackingType) {
      case TrackingType.chapters:
        final count = chapters.fold<int>(0, (sum, c) => sum + c.topics.length);
        return count > 0
            ? count
            : (chapters.isNotEmpty ? chapters.length : total);
      case TrackingType.tasks:
        return tasks.isNotEmpty ? tasks.length : total;
      case TrackingType.flatLectures:
        return total;
    }
  }

  // Computed completed items based on tracking mode
  int get effectiveCompleted {
    switch (trackingType) {
      case TrackingType.chapters:
        final count = chapters.fold<int>(0, (sum, c) => sum + c.completedCount);
        return count > 0
            ? count
            : (chapters.isNotEmpty
                ? chapters.where((c) => c.isCompleted).length
                : completed.length);
      case TrackingType.tasks:
        return tasks.where((t) => t.isCompleted).length;
      case TrackingType.flatLectures:
        return completed.length;
    }
  }

  int get pendingCount =>
      (effectiveTotal - effectiveCompleted).clamp(0, 999999);

  double get progressRatio => effectiveTotal == 0
      ? 0.0
      : (effectiveCompleted / effectiveTotal).clamp(0.0, 1.0);
  int get progressPercent => (progressRatio * 100).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'trackingType': trackingType.name,
        'total': total,
        'completed': completed,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'revisionStatus': revisionStatus,
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    // Determine tracking type
    TrackingType type = TrackingType.flatLectures;
    if (json.containsKey('trackingType')) {
      final tStr = json['trackingType'] as String;
      type = TrackingType.values.firstWhere((e) => e.name == tStr,
          orElse: () => TrackingType.flatLectures);
    } else if (json.containsKey('chapters') &&
        (json['chapters'] as List).isNotEmpty) {
      type = TrackingType.chapters;
    }

    // Convert notes (support legacy format where notes were raw Map<String, dynamic>)
    final rawNotes = json['notes'] as List? ?? [];
    final parsedNotes = rawNotes.map((n) {
      if (n is Map) {
        return StudyNote.fromJson(Map<String, dynamic>.from(n));
      }
      return StudyNote(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: n.toString());
    }).toList();

    return Subject(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Untitled Subject',
      code: json['code'] as String? ?? '',
      colorValue: json['colorValue'] as int?,
      iconCodePoint: json['iconCodePoint'] as int?,
      trackingType: type,
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      chapters: (json['chapters'] as List? ?? [])
          .map((c) => Chapter.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      tasks: (json['tasks'] as List? ?? [])
          .map((t) => StudyTask.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
      notes: parsedNotes,
      revisionStatus: (json['revisionStatus'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), v as bool? ?? false)),
    );
  }
}

class StudySession {
  String id;
  String? subjectId;
  String subjectName;
  int minutes;
  String topic;
  String type; // 'Pomodoro', 'Stopwatch', 'Manual'
  DateTime timestamp;

  StudySession({
    required this.id,
    this.subjectId,
    required this.subjectName,
    required this.minutes,
    this.topic = '',
    this.type = 'Pomodoro',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'minutes': minutes,
        'topic': topic,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      subjectId: json['subjectId'] as String?,
      subjectName: json['subjectName'] as String? ?? 'General Study',
      minutes: (json['minutes'] as num?)?.toInt() ?? 25,
      topic: json['topic'] as String? ?? '',
      type: json['type'] as String? ?? 'Pomodoro',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum ReminderRecurrence {
  none,
  daily,
  weekdays,
  weekly,
}

enum ReminderVibrationPattern {
  standard,
  heartbeat,
  rapid,
  gentle,
}

class StudyReminder {
  int id;
  String title;
  int hour;
  int minute;
  bool enabled;
  ReminderRecurrence recurrence;
  DateTime? date;
  String? subjectName;
  bool soundEnabled;
  bool vibrationEnabled;
  ReminderVibrationPattern vibrationPattern;

  StudyReminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.recurrence = ReminderRecurrence.daily,
    this.date,
    this.subjectName,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.vibrationPattern = ReminderVibrationPattern.standard,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'recurrence': recurrence.name,
        'date': date?.toIso8601String(),
        'subjectName': subjectName,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'vibrationPattern': vibrationPattern.name,
      };

  factory StudyReminder.fromJson(Map<String, dynamic> json) {
    ReminderRecurrence rec = ReminderRecurrence.daily;
    if (json.containsKey('recurrence')) {
      final rStr = json['recurrence'] as String?;
      rec = ReminderRecurrence.values.firstWhere(
        (e) => e.name == rStr,
        orElse: () => ReminderRecurrence.daily,
      );
    }

    ReminderVibrationPattern vibPat = ReminderVibrationPattern.standard;
    if (json.containsKey('vibrationPattern')) {
      final vStr = json['vibrationPattern'] as String?;
      vibPat = ReminderVibrationPattern.values.firstWhere(
        (e) => e.name == vStr,
        orElse: () => ReminderVibrationPattern.standard,
      );
    }

    DateTime? parsedDate;
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'] as String);
    }

    return StudyReminder(
      id: (json['id'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: json['title'] as String? ?? 'Study Reminder',
      hour: (json['hour'] as num?)?.toInt() ?? 9,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      recurrence: rec,
      date: parsedDate,
      subjectName: json['subjectName'] as String?,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      vibrationPattern: vibPat,
    );
  }
}

class TargetCountdown {
  final int days;
  final int months;
  final int hours;
  final int minutes;
  final bool isPast;

  const TargetCountdown({
    required this.days,
    required this.months,
    required this.hours,
    required this.minutes,
    this.isPast = false,
  });

  static TargetCountdown calculate(DateTime? targetDate) {
    if (targetDate == null) {
      return const TargetCountdown(days: 0, months: 0, hours: 0, minutes: 0);
    }
    final now = DateTime.now();
    final diff = targetDate.difference(now);
    if (diff.isNegative) {
      return const TargetCountdown(
          days: 0, months: 0, hours: 0, minutes: 0, isPast: true);
    }
    final totalDays = diff.inDays;
    final months = (totalDays / 30.44).floor();
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    return TargetCountdown(
      days: totalDays,
      months: months,
      hours: hours,
      minutes: minutes,
      isPast: false,
    );
  }
}

class StudyPlan {
  String id;
  String title;
  String
      category; // 'College / University', 'Professional Exam', 'Certification', 'Competitive Exam', 'School', 'Self-Study'
  String primaryTargetLabel;
  DateTime? primaryTargetDate;
  String backupTargetLabel;
  DateTime? backupTargetDate;
  int dailyGoalMinutes; // Default 180 (3 hrs)
  List<String>
      revisionCycles; // e.g. ['R1 (First Pass)', 'R2 (Consolidation)', 'R3 (Mock Ready)']
  List<Subject> subjects;
  List<StudySession> sessions;
  List<StudyReminder> reminders;
  DateTime createdAt;

  StudyPlan({
    required this.id,
    required this.title,
    this.category = 'General Study',
    this.primaryTargetLabel = 'Target Exam',
    this.primaryTargetDate,
    this.backupTargetLabel = 'Backup Target',
    this.backupTargetDate,
    this.dailyGoalMinutes = 180,
    List<String>? revisionCycles,
    List<Subject>? subjects,
    List<StudySession>? sessions,
    List<StudyReminder>? reminders,
    DateTime? createdAt,
  })  : revisionCycles = revisionCycles ??
            ['R1 (First Pass)', 'R2 (Deep Review)', 'R3 (Exam Practice)'],
        subjects = subjects ?? [],
        sessions = sessions ?? [],
        reminders = reminders ?? [],
        createdAt = createdAt ?? DateTime.now();

  // Total items across all subjects
  int get totalItems => subjects.fold(0, (sum, s) => sum + s.effectiveTotal);
  int get completedItems =>
      subjects.fold(0, (sum, s) => sum + s.effectiveCompleted);
  int get pendingItems => (totalItems - completedItems).clamp(0, 999999);
  double get overallProgress =>
      totalItems == 0 ? 0.0 : (completedItems / totalItems).clamp(0.0, 1.0);
  int get overallProgressPercent => (overallProgress * 100).round();

  // Days remaining to primary target
  int? get daysUntilPrimary {
    if (primaryTargetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(primaryTargetDate!.year, primaryTargetDate!.month,
        primaryTargetDate!.day);
    return target.difference(today).inDays;
  }

  // Days remaining to backup target
  int? get daysUntilBackup {
    if (backupTargetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
        backupTargetDate!.year, backupTargetDate!.month, backupTargetDate!.day);
    return target.difference(today).inDays;
  }

  // Workload Pace: Items/day needed
  double get dailyRequiredPace {
    final days = daysUntilPrimary;
    if (days == null || days <= 0 || pendingItems <= 0) return 0.0;
    return (pendingItems / days);
  }

  // Study time today in minutes
  int get todayStudyMinutes {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sessions.where((s) {
      final sDate =
          DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
      return sDate == today;
    }).fold(0, (sum, s) => sum + s.minutes);
  }

  // Target Countdown breakdowns
  TargetCountdown get primaryCountdown =>
      TargetCountdown.calculate(primaryTargetDate);
  TargetCountdown get backupCountdown =>
      TargetCountdown.calculate(backupTargetDate);

  // Total completed revisions across all subjects
  int get completedRevisions {
    int count = 0;
    for (final s in subjects) {
      count += s.revisionStatus.values.where((v) => v == true).length;
    }
    return count;
  }

  // Self Tests completed count
  int get selfTestsCompleted {
    int count = 0;
    for (final s in subjects) {
      for (final c in s.chapters) {
        count += c.topics
            .where((t) =>
                t.isCompleted &&
                (t.type.toLowerCase().contains('test') ||
                    t.title.toLowerCase().contains('test')))
            .length;
      }
      count += s.tasks
          .where((t) =>
              t.isCompleted &&
              (t.type.toLowerCase().contains('test') ||
                  t.title.toLowerCase().contains('test')))
          .length;
    }
    return count;
  }

  // Consecutive study streak days
  int get studyStreakDays {
    if (sessions.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>{};
    for (final s in sessions) {
      dates.add(DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day));
    }

    int streak = 0;
    DateTime checkDate =
        dates.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (dates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Days of current week (Monday=0 .. Sunday=6) with recorded study sessions
  List<bool> get currentWeekActiveDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final activeDays = <bool>[];
    final dates = sessions
        .map((s) =>
            '${s.timestamp.year}-${s.timestamp.month}-${s.timestamp.day}')
        .toSet();

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      activeDays.add(dates.contains(key));
    }
    return activeDays;
  }

  // Study time this week in minutes
  int get weekStudyMinutes {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return sessions
        .where((s) => s.timestamp.isAfter(sevenDaysAgo))
        .fold(0, (sum, s) => sum + s.minutes);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'primaryTargetLabel': primaryTargetLabel,
        'primaryTargetDate': primaryTargetDate?.toIso8601String(),
        'backupTargetLabel': backupTargetLabel,
        'backupTargetDate': backupTargetDate?.toIso8601String(),
        'dailyGoalMinutes': dailyGoalMinutes,
        'revisionCycles': revisionCycles,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'My Study Plan',
      category: json['category'] as String? ?? 'General Study',
      primaryTargetLabel:
          json['primaryTargetLabel'] as String? ?? 'Target Exam',
      primaryTargetDate: json['primaryTargetDate'] != null
          ? DateTime.tryParse(json['primaryTargetDate'] as String)
          : null,
      backupTargetLabel:
          json['backupTargetLabel'] as String? ?? 'Backup Target',
      backupTargetDate: json['backupTargetDate'] != null
          ? DateTime.tryParse(json['backupTargetDate'] as String)
          : null,
      dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 180,
      revisionCycles: (json['revisionCycles'] as List? ??
              ['R1 (First Pass)', 'R2 (Deep Review)', 'R3 (Exam Practice)'])
          .map((e) => e.toString())
          .toList(),
      subjects: (json['subjects'] as List? ?? [])
          .map((s) => Subject.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      sessions: (json['sessions'] as List? ?? [])
          .map(
              (s) => StudySession.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      reminders: (json['reminders'] as List? ?? [])
          .map((r) =>
              StudyReminder.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
