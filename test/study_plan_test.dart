import 'package:flutter_test/flutter_test.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';

void main() {
  group('StudyPlan & Subject Models Tests', () {
    test('Flat lectures counting & progress calculation', () {
      final subject = Subject(
        id: 's1',
        name: 'Mathematics',
        total: 20,
        completed: [1, 2, 3, 4, 5],
        trackingType: TrackingType.flatLectures,
      );

      expect(subject.effectiveTotal, 20);
      expect(subject.effectiveCompleted, 5);
      expect(subject.pendingCount, 15);
      expect(subject.progressPercent, 25);
    });

    test('Chapters and topics counting & completion', () {
      final chapter1 = Chapter(
        id: 'c1',
        title: 'Calculus',
        topics: [
          StudyTask(id: 't1', title: 'Limits', isCompleted: true),
          StudyTask(id: 't2', title: 'Derivatives', isCompleted: true),
        ],
      );
      final chapter2 = Chapter(
        id: 'c2',
        title: 'Algebra',
        topics: [
          StudyTask(id: 't3', title: 'Matrices', isCompleted: false),
        ],
      );

      final subject = Subject(
        id: 's2',
        name: 'Higher Math',
        trackingType: TrackingType.chapters,
        chapters: [chapter1, chapter2],
      );

      expect(chapter1.isCompleted, true);
      expect(chapter2.isCompleted, false);
      expect(subject.effectiveTotal, 3);
      expect(subject.effectiveCompleted, 2);
      expect(subject.pendingCount, 1);
      expect(subject.progressPercent, 67);
    });

    test('Target countdown and daily pace calculator', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 10));

      final plan = StudyPlan(
        id: 'p1',
        title: 'Exam Plan',
        primaryTargetLabel: 'Final Exam',
        primaryTargetDate: targetDate,
        subjects: [
          Subject(
              id: 's1',
              name: 'Sub 1',
              total: 50,
              completed: [1, 2, 3, 4, 5]), // 45 pending
          Subject(
              id: 's2',
              name: 'Sub 2',
              total: 20,
              completed: [1, 2, 3, 4, 5]), // 15 pending
        ],
      );

      expect(plan.totalItems, 70);
      expect(plan.completedItems, 10);
      expect(plan.pendingItems, 60);
      expect(plan.daysUntilPrimary, 10);
      expect(plan.dailyRequiredPace,
          closeTo(6.0, 0.1)); // 60 items / 10 days = 6 items/day
    });

    test('Study sessions and today minutes aggregation', () {
      final now = DateTime.now();
      final plan = StudyPlan(
        id: 'p1',
        title: 'Study Plan',
        sessions: [
          StudySession(
              id: '1', subjectName: 'Math', minutes: 45, timestamp: now),
          StudySession(
              id: '2', subjectName: 'Physics', minutes: 30, timestamp: now),
          StudySession(
              id: '3',
              subjectName: 'Chemistry',
              minutes: 60,
              timestamp: now.subtract(const Duration(days: 3))),
        ],
      );

      expect(plan.todayStudyMinutes, 75);
      expect(plan.weekStudyMinutes, 135);
    });

    test('JSON Export and Import roundtrip', () {
      final plan = StudyPlan(
        id: 'plan_test',
        title: 'Full Stack Web Dev',
        category: 'Self-Study',
        primaryTargetLabel: 'Portfolio Launch',
        primaryTargetDate: DateTime(2027, 1, 1),
        dailyGoalMinutes: 120,
        subjects: [
          Subject(
            id: 'sub_1',
            name: 'React & Flutter',
            total: 30,
            completed: [1, 2, 3],
            notes: [
              StudyNote(
                  id: 'n1', text: 'State management principles', tag: 'Concept')
            ],
          ),
        ],
        sessions: [
          StudySession(
              id: 'sess_1', subjectName: 'React & Flutter', minutes: 50),
        ],
        reminders: [
          StudyReminder(id: 101, title: 'Morning Code', hour: 8, minute: 30),
        ],
      );

      final exportedJson = StorageService.exportBackupJson([plan]);
      expect(exportedJson.contains('Full Stack Web Dev'), true);
      expect(exportedJson.contains('State management principles'), true);

      final restored = StorageService.importBackupJson(exportedJson);
      expect(restored.length, 1);
      expect(restored.first.title, 'Full Stack Web Dev');
      expect(restored.first.subjects.length, 1);
      expect(restored.first.subjects.first.effectiveTotal, 30);
      expect(restored.first.subjects.first.effectiveCompleted, 3);
      expect(restored.first.subjects.first.notes.first.text,
          'State management principles');
      expect(restored.first.sessions.length, 1);
      expect(restored.first.reminders.length, 1);
    });

    test('TargetCountdown breakdown calculation', () {
      final now = DateTime.now();
      final target = now.add(const Duration(days: 45, hours: 5, minutes: 12));
      final countdown = TargetCountdown.calculate(target);

      expect(countdown.isPast, false);
      expect(countdown.days, 45);
      expect(countdown.months, 1); // 45 / 30.44 = 1 month
      expect(countdown.hours, 5);
      expect(countdown.minutes, inInclusiveRange(11, 12));

      // Past target test
      final pastTarget = now.subtract(const Duration(days: 2));
      final pastCountdown = TargetCountdown.calculate(pastTarget);
      expect(pastCountdown.isPast, true);
      expect(pastCountdown.days, 0);
    });

    test('Study streak calculation and weekly active days', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final plan = StudyPlan(
        id: 'streak_test',
        title: 'Streak Plan',
        sessions: [
          StudySession(
              id: 's1', subjectName: 'Math', minutes: 30, timestamp: today),
          StudySession(
              id: 's2', subjectName: 'Math', minutes: 45, timestamp: yesterday),
          StudySession(
              id: 's3',
              subjectName: 'Math',
              minutes: 25,
              timestamp: twoDaysAgo),
        ],
      );

      expect(plan.studyStreakDays, 3);
      expect(plan.currentWeekActiveDays.length, 7);
      expect(plan.currentWeekActiveDays.contains(true), true);
    });

    test('Revision status and self-tests counting', () {
      final subject = Subject(
        id: 'sub_rev',
        name: 'Economics',
        revisionStatus: {'R1': true, 'R2': true, 'R3': false},
        tasks: [
          StudyTask(
              id: 't1',
              title: 'Chapter 1 Mock Test',
              type: 'Self Test',
              isCompleted: true),
          StudyTask(
              id: 't2',
              title: 'Chapter 2 Quiz Test',
              type: 'Test',
              isCompleted: true),
          StudyTask(
              id: 't3',
              title: 'Reading notes',
              type: 'Reading',
              isCompleted: true),
        ],
      );

      final plan = StudyPlan(
        id: 'rev_plan',
        title: 'Revision Plan',
        subjects: [subject],
      );

      expect(plan.completedRevisions, 2);
      expect(plan.selfTestsCompleted, 2);
    });
  });
}
