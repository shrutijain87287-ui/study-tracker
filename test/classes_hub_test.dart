import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/class_model.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/services/classes_recommendation_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/services/youtube_service.dart';
import 'package:ca_inter_tracker/widgets/video_card.dart';
import 'package:ca_inter_tracker/screens/classes_hub_screen.dart';
import 'package:ca_inter_tracker/screens/class_detail_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Class Models and Serialization', () {
    test('ClassStatus labels and properties', () {
      expect(ClassStatus.notStarted.label, 'Not Started');
      expect(ClassStatus.inProgress.label, 'In Progress');
      expect(ClassStatus.completed.label, 'Completed');
      expect(ClassStatus.completed.icon, Icons.check_circle_rounded);
    });

    test('VideoItem JSON roundtrip and formatting', () {
      final now = DateTime(2025, 5, 10);
      final video = VideoItem(
        id: 'v123',
        title: 'CA Inter AS 10 One Shot',
        channelTitle: 'CA Rishabh Jain',
        channelId: 'UC_test_123',
        thumbnailUrl: 'https://img.youtube.com/vi/v123/hqdefault.jpg',
        duration: '1:45:20',
        viewCount: '150K views',
        subscriberCount: '450K subscribers',
        publishedAt: now,
        isVerifiedTeacher: true,
        studyCategory: 'Professional Exam',
      );

      final json = video.toJson();
      final restored = VideoItem.fromJson(json);

      expect(restored.id, 'v123');
      expect(restored.title, 'CA Inter AS 10 One Shot');
      expect(restored.channelTitle, 'CA Rishabh Jain');
      expect(restored.duration, '1:45:20');
      expect(restored.isVerifiedTeacher, true);
      expect(restored.youtubeUrl, 'https://www.youtube.com/watch?v=v123');
      expect(
          restored.channelUrl, 'https://www.youtube.com/channel/UC_test_123');
    });

    test('SavedClass from VideoItem and JSON roundtrip', () {
      const video = VideoItem(
        id: 'v456',
        title: 'GST Input Tax Credit Full Lecture',
        channelTitle: 'CA Shruti Kedia',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: '2:10:00',
        viewCount: '95K views',
      );

      final saved = SavedClass.fromVideoItem(
        video,
        subjectId: 'sub_tax',
        subjectName: 'Taxation',
        chapterId: 'ch_itc',
        chapterTitle: 'Input Tax Credit',
        status: ClassStatus.inProgress,
        notes: 'Section 16 conditions are crucial for exam.',
      );

      expect(saved.id, 'v456');
      expect(saved.videoId, 'v456');
      expect(saved.linkedSubjectName, 'Taxation');
      expect(saved.linkedChapterTitle, 'Input Tax Credit');
      expect(saved.status, ClassStatus.inProgress);
      expect(saved.notes, contains('Section 16'));

      final json = saved.toJson();
      final restored = SavedClass.fromJson(json);
      expect(restored.id, 'v456');
      expect(restored.status, ClassStatus.inProgress);
      expect(restored.linkedSubjectId, 'sub_tax');
      expect(restored.notes, contains('Section 16'));
    });
  });

  group('YouTubeService and Utility Parsers', () {
    test('ISO 8601 duration parser handles H:M:S and M:S', () {
      expect(YouTubeService.formatIsoDuration('PT1H28M40S'), '1:28:40');
      expect(YouTubeService.formatIsoDuration('PT45M12S'), '45:12');
      expect(YouTubeService.formatIsoDuration('PT2H5M'), '2:05:00');
      expect(YouTubeService.formatIsoDuration('PT50S'), '0:50');
      expect(YouTubeService.formatIsoDuration(''), '');
    });

    test('View count formatter', () {
      expect(YouTubeService.formatViewCount(320000), '320K views');
      expect(YouTubeService.formatViewCount(1500000), '1.5M views');
      expect(YouTubeService.formatViewCount(850), '850 views');
    });

    test('Extract distinct teachers and counts', () {
      final items = [
        const VideoItem(
            id: '1',
            title: 'A',
            channelTitle: 'Teacher Alpha',
            thumbnailUrl: ''),
        const VideoItem(
            id: '2',
            title: 'B',
            channelTitle: 'Teacher Beta',
            thumbnailUrl: ''),
        const VideoItem(
            id: '3',
            title: 'C',
            channelTitle: 'Teacher Alpha',
            thumbnailUrl: ''),
      ];

      final teachers = YouTubeService.extractTeachers(items);
      expect(teachers.length, 2);
      expect(teachers.first.name, 'Teacher Alpha');
      expect(teachers.first.videoCount, 2);
      expect(teachers[1].name, 'Teacher Beta');
      expect(teachers[1].videoCount, 1);
    });

    test('Demo search finds multi-teacher classes for CA Inter AS 10',
        () async {
      final res = await YouTubeService.searchClasses(
        query: 'AS 10',
        category: 'Professional Exam',
      );

      expect(res.isDemoMode, true);
      expect(res.items.isNotEmpty, true);

      // Check multi-teacher discovery in results
      final teachers = YouTubeService.extractTeachers(res.items);
      expect(teachers.length, greaterThanOrEqualTo(2));
      expect(
        teachers.any((t) =>
            t.name.toLowerCase().contains('rishabh') ||
            t.name.toLowerCase().contains('shruti')),
        true,
      );
    });

    test('Demo search respects teacher filter', () async {
      final res = await YouTubeService.searchClasses(
        query: 'AS 10',
        selectedTeacher: 'CA Rishabh Jain',
      );

      expect(res.items.isNotEmpty, true);
      expect(res.items.every((v) => v.channelTitle == 'CA Rishabh Jain'), true);
    });
  });

  group('ClassesRecommendationService', () {
    test('Returns tailored popular topics by category', () {
      final service = ClassesRecommendationService();

      final proTopics =
          service.getPopularTopicsForCategory('Professional Exam');
      expect(proTopics.any((t) => t.contains('AS 10')), true);

      final competitiveTopics =
          service.getPopularTopicsForCategory('Competitive Exam');
      expect(
          competitiveTopics
              .any((t) => t.contains('Polity') || t.contains('Physics')),
          true);

      final collegeTopics =
          service.getPopularTopicsForCategory('College / University');
      expect(collegeTopics.any((t) => t.contains('Data Structures')), true);
    });

    test('Generates subject-based topic suggestions from plan', () {
      final service = ClassesRecommendationService();
      final plan = StudyPlan(
        id: 'plan_1',
        title: 'CA Inter Both Groups',
        category: 'Professional Exam',
        subjects: [
          Subject(
            id: 'sub_1',
            name: 'Advanced Accounting',
            chapters: [
              Chapter(id: 'c1', title: 'AS 10 Property Plant Equipment')
            ],
          ),
        ],
      );

      final suggestions = service.getSubjectBasedSuggestions(plan);
      expect(suggestions.any((s) => s.contains('Advanced Accounting one shot')),
          true);
      expect(
          suggestions.any((s) => s.contains('AS 10 Property Plant Equipment')),
          true);
    });
  });

  group('StorageService for Classes', () {
    test('Save, load, update, and remove saved classes', () async {
      const video = VideoItem(
        id: 'save_test_1',
        title: 'Data Structures Trees & Graphs',
        channelTitle: 'Abdul Bari',
        thumbnailUrl: '',
      );

      final saved = SavedClass.fromVideoItem(
        video,
        status: ClassStatus.notStarted,
        notes: 'Review before interview',
      );

      await StorageService.addOrUpdateSavedClass(saved);

      var list = await StorageService.loadSavedClasses();
      expect(list.length, 1);
      expect(list.first.id, 'save_test_1');
      expect(list.first.notes, 'Review before interview');

      // Update status
      saved.status = ClassStatus.completed;
      saved.notes = 'Done!';
      await StorageService.addOrUpdateSavedClass(saved);

      list = await StorageService.loadSavedClasses();
      expect(list.length, 1);
      expect(list.first.status, ClassStatus.completed);
      expect(list.first.notes, 'Done!');

      // Remove
      await StorageService.removeSavedClass('save_test_1');
      list = await StorageService.loadSavedClasses();
      expect(list.isEmpty, true);
    });

    test('Recent searches persistence and deduplication', () async {
      await StorageService.addRecentClassesSearch('AS 10');
      await StorageService.addRecentClassesSearch('GST');
      await StorageService.addRecentClassesSearch(
          'AS 10'); // Duplicate to front

      final searches = await StorageService.loadRecentClassesSearches();
      expect(searches.first, 'AS 10');
      expect(searches[1], 'GST');
      expect(searches.length, 2);

      await StorageService.clearRecentClassesSearches();
      final empty = await StorageService.loadRecentClassesSearches();
      expect(empty.isEmpty, true);
    });
  });

  group('Classes Hub Widgets & UI Tests', () {
    testWidgets(
        'VideoCard renders thumbnail, duration, verified badge, and handles tap',
        (tester) async {
      bool tapped = false;
      bool saveToggled = false;

      const video = VideoItem(
        id: 'vid_ui_1',
        title: 'CA Inter Corporate Law Chapter 1',
        channelTitle: 'CA Ankita Patni',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: '1:12:45',
        viewCount: '210K views',
        isVerifiedTeacher: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: video,
              onTap: () => tapped = true,
              onToggleSave: () => saveToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('CA Inter Corporate Law Chapter 1'), findsOneWidget);
      expect(find.text('CA Ankita Patni'), findsOneWidget);
      expect(find.text('1:12:45'), findsOneWidget);
      expect(find.text('210K views'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      await tester.tap(find.text('CA Inter Corporate Law Chapter 1'));
      expect(tapped, true);

      await tester.tap(find.byTooltip('Save Class'));
      expect(saveToggled, true);
    });

    testWidgets('ClassesHubScreen loads and renders Discover tab components',
        (tester) async {
      final plan = StudyPlan(
        id: 'p1',
        title: 'CA Inter May 2026',
        category: 'Professional Exam',
        subjects: [Subject(id: 's1', name: 'Advanced Accounting')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassesHubScreen(studyPlan: plan),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Classes Hub'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('My Classes (0)'), findsOneWidget);
      expect(find.text('Popular Topics'), findsOneWidget);
      expect(find.text('Recommended for You'), findsOneWidget);
    });

    testWidgets(
        'ClassesHubScreen executes search and displays multi-teacher filter chips',
        (tester) async {
      final plan = StudyPlan(
        id: 'p1',
        title: 'My Study Plan',
        category: 'Professional Exam',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassesHubScreen(studyPlan: plan),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'AS 10');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Check results banner and multi-teacher filter row
      expect(find.text('Filter by Teacher / Channel:'), findsOneWidget);
      expect(find.textContaining('All Teachers'), findsOneWidget);
    });

    test('Query Parser correctly extracts teacher and subject terms', () {
      // 1. Teacher + Subject
      final q1 = YouTubeService.parseTeacherAndSubject('Rishabh Jain Audit');
      expect(q1.hasExplicitTeacher, true);
      expect(q1.teacherTerm, 'Rishabh Jain');
      expect(q1.subjectTerm, 'Audit');
      expect(q1.isTeacherAndSubject, true);

      // 2. Subject by Teacher
      final q2 = YouTubeService.parseTeacherAndSubject('Audit by Rishabh Jain');
      expect(q2.hasExplicitTeacher, true);
      expect(q2.teacherTerm, 'Rishabh Jain');
      expect(q2.subjectTerm, 'Audit');

      // 3. Honorific Prefix
      final q3 = YouTubeService.parseTeacherAndSubject('CA Rishabh Jain');
      expect(q3.hasExplicitTeacher, true);
      expect(q3.teacherTerm, 'CA Rishabh Jain');
      expect(q3.isTeacherOnly, true);

      // 4. Subject Only (No Teacher)
      final q4 = YouTubeService.parseTeacherAndSubject('Audit');
      expect(q4.hasExplicitTeacher, false);
      expect(q4.teacherTerm, isNull);
      expect(q4.subjectTerm, 'Audit');
      expect(q4.isSubjectOnly, true);

      // 5. College CS Teacher + Subject
      final q5 = YouTubeService.parseTeacherAndSubject('Abdul Bari Trees');
      expect(q5.hasExplicitTeacher, true);
      expect(q5.teacherTerm, 'Abdul Bari');
      expect(q5.subjectTerm, 'Trees');

      // 6. School Teacher + Subject
      final q6 = YouTubeService.parseTeacherAndSubject(
          'Class 10 Trigonometry Dear Sir');
      expect(q6.hasExplicitTeacher, true);
      expect(q6.teacherTerm, 'Dear Sir');
      expect(q6.subjectTerm, contains('Trigonometry'));
    });

    test(
        'Strict Teacher + Subject search returns zero results when teacher does not teach subject',
        () async {
      // Rishabh Jain only teaches AS 10 & Corporate Law in the catalog, NOT Audit
      final res =
          await YouTubeService.searchClasses(query: 'Rishabh Jain Audit');
      expect(res.noMatchingForTeacherSubject, true);
      expect(res.items.isEmpty, true);
      expect(res.parsedTeacher, contains('Rishabh Jain'));
      expect(res.parsedSubject, 'Audit');
    });

    test(
        'Strict Teacher + Subject search returns matching video when teacher teaches subject',
        () async {
      // Amit Tated teaches Audit in the catalog
      final res = await YouTubeService.searchClasses(query: 'Amit Tated Audit');
      expect(res.noMatchingForTeacherSubject, false);
      expect(res.items.isNotEmpty, true);
      expect(res.items.every((v) => v.channelTitle == 'CA Amit Tated'), true);
      expect(res.items.first.title, contains('Audit'));
    });

    test('Teacher-only search returns all videos by that teacher', () async {
      final res = await YouTubeService.searchClasses(query: 'Rishabh Jain');
      expect(res.items.isNotEmpty, true);
      expect(res.items.every((v) => v.channelTitle == 'CA Rishabh Jain'), true);
      expect(res.items.length, greaterThanOrEqualTo(2)); // AS 10 + Law
    });

    test('Subject-only search allows multi-teacher discovery', () async {
      final res = await YouTubeService.searchClasses(query: 'AS 10');
      expect(res.items.isNotEmpty, true);
      final teachers = YouTubeService.extractTeachers(res.items);
      expect(teachers.length, greaterThanOrEqualTo(2));
    });

    test(
        'Category-aware recommendation strictly isolates study categories in Demo Mode',
        () async {
      final service = ClassesRecommendationService();

      // College / University plan
      final collegePlan = StudyPlan(
        id: 'c1',
        title: 'B.Tech CS',
        category: 'College / University',
      );
      final collegeVideos =
          await service.getRecommendedClasses(plan: collegePlan);
      expect(collegeVideos.isNotEmpty, true);
      expect(
          collegeVideos.every((v) => v.studyCategory == 'College / University'),
          true);
      expect(collegeVideos.any((v) => v.channelTitle.contains('CA ')),
          false); // No CA videos!

      // School plan
      final schoolPlan = StudyPlan(
        id: 's1',
        title: 'Class 10 CBSE',
        category: 'School',
      );
      final schoolVideos =
          await service.getRecommendedClasses(plan: schoolPlan);
      expect(schoolVideos.isNotEmpty, true);
      expect(schoolVideos.every((v) => v.studyCategory == 'School'), true);

      // Competitive Exam plan
      final compPlan = StudyPlan(
        id: 'cp1',
        title: 'JEE 2026',
        category: 'Competitive Exam',
      );
      final compVideos = await service.getRecommendedClasses(plan: compPlan);
      expect(compVideos.isNotEmpty, true);
      expect(
          compVideos.every((v) => v.studyCategory == 'Competitive Exam'), true);
    });

    test('ChannelCandidate JSON serialization', () {
      const candidate = ChannelCandidate(
        channelId: 'UC_test_ch',
        title: 'CA Rishabh Jain Classes',
        description: 'Official channel for CA Inter',
        thumbnailUrl: 'https://example.com/ch.jpg',
        subscriberCount: '1.2M subscribers',
        isVerified: true,
      );

      final json = candidate.toJson();
      final restored = ChannelCandidate.fromJson(json);

      expect(restored.channelId, 'UC_test_ch');
      expect(restored.title, 'CA Rishabh Jain Classes');
      expect(restored.subscriberCount, '1.2M subscribers');
      expect(restored.isVerified, true);
    });
  });

  group('YouTube URL Detection and Direct Navigation', () {
    test('extractVideoId accurately parses all YouTube URL formats', () {
      // 1. youtube.com/watch?v=ID
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.extractVideoId('http://youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      // Query params before v
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      // Query params after v (timestamps, playlist)
      expect(
        YouTubeService.extractVideoId(
            'https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PL123'),
        'dQw4w9WgXcQ',
      );

      // 2. youtu.be/ID
      expect(
        YouTubeService.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.extractVideoId(
            'https://youtu.be/dQw4w9WgXcQ?si=abc123xyz'),
        'dQw4w9WgXcQ',
      );

      // 3. youtube.com/live/ID
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.extractVideoId('https://youtube.com/live/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );

      // 4. youtube.com/shorts/ID
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.extractVideoId(
            'https://youtube.com/shorts/dQw4w9WgXcQ?feature=share'),
        'dQw4w9WgXcQ',
      );

      // 5. youtube.com/embed/ID
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );

      // 6. Whitespace handling
      expect(
        YouTubeService.extractVideoId('  https://youtu.be/dQw4w9WgXcQ \n '),
        'dQw4w9WgXcQ',
      );

      // 7. Demo/test catalog ID support
      expect(
        YouTubeService.extractVideoId('https://youtu.be/demo_as10_rishabh'),
        'demo_as10_rishabh',
      );
      expect(
        YouTubeService.extractVideoId(
            'https://www.youtube.com/watch?v=demo_as10_rishabh'),
        'demo_as10_rishabh',
      );

      // 8. Normal search queries MUST return null to preserve text search
      expect(YouTubeService.extractVideoId('CA Rishabh Jain Audit'), isNull);
      expect(YouTubeService.extractVideoId('AS 10 one shot'), isNull);
      expect(YouTubeService.extractVideoId('Physics Wallah'), isNull);
      expect(YouTubeService.extractVideoId('https://google.com'), isNull);
      expect(
          YouTubeService.extractVideoId(
              'https://www.youtube.com/feed/subscriptions'),
          isNull);
      expect(YouTubeService.extractVideoId('https://www.youtube.com/watch?v='),
          isNull);
      expect(YouTubeService.extractVideoId(''), isNull);
    });

    test('fetchVideoById fetches demo catalog video metadata', () async {
      final video = await YouTubeService.fetchVideoById('demo_as10_rishabh');
      expect(video, isNotNull);
      expect(video!.id, 'demo_as10_rishabh');
      expect(video.channelTitle, 'CA Rishabh Jain');
      expect(video.title, contains('AS 10'));
      expect(video.duration, isNotEmpty);
    });

    test('fetchVideoById handles invalid or unavailable video gracefully',
        () async {
      final video =
          await YouTubeService.fetchVideoById('invalid_fake_id_12345');
      expect(video, isNull);
    });

    testWidgets('Search input detects pasted YouTube URL and adapts button',
        (tester) async {
      final plan = StudyPlan(
        id: 'p1',
        title: 'CA Inter May 2026',
        category: 'Professional Exam',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassesHubScreen(studyPlan: plan),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField).first;

      // 1. Text search shows 'Search' button
      await tester.enterText(searchInput, 'AS 10');
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Open Video'), findsNothing);

      // 2. Pasting YouTube URL adapts button to 'Open Video'
      await tester.enterText(searchInput, 'https://youtu.be/demo_as10_rishabh');
      await tester.pumpAndSettle();
      expect(find.text('Open Video'), findsOneWidget);
      expect(find.text('Search'), findsNothing);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });

    testWidgets(
        'Pasting valid YouTube URL navigates directly to ClassDetailScreen',
        (tester) async {
      final plan = StudyPlan(
        id: 'p1',
        title: 'CA Inter May 2026',
        category: 'Professional Exam',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassesHubScreen(studyPlan: plan),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'https://youtu.be/demo_as10_rishabh');
      await tester.pumpAndSettle();

      // Tap 'Open Video'
      await tester.tap(find.text('Open Video'));
      await tester.pumpAndSettle();

      // Direct navigation to ClassDetailScreen
      expect(find.byType(ClassDetailScreen), findsOneWidget);
      expect(find.text('AS 10 – Full Lecture | CA Inter Advanced Accounting'),
          findsOneWidget);
      expect(find.text('CA Rishabh Jain'), findsOneWidget);
      expect(find.text('Open & Watch in YouTube'), findsOneWidget);
    });

    testWidgets(
        'Pasting unavailable YouTube URL displays error SnackBar gracefully',
        (tester) async {
      final plan = StudyPlan(
        id: 'p1',
        title: 'CA Inter May 2026',
        category: 'Professional Exam',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassesHubScreen(studyPlan: plan),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField).first;
      // Enter invalid URL that will return null from fetchVideoById
      await tester.enterText(searchInput, 'https://youtu.be/invalid99999');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Video'));
      await tester.pumpAndSettle();

      // Should remain on ClassesHubScreen and show error SnackBar
      expect(find.byType(ClassDetailScreen), findsNothing);
      expect(find.textContaining('Unable to load video'), findsOneWidget);
    });
  });
}
