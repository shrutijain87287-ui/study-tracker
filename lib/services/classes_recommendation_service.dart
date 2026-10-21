import '../models/class_model.dart';
import '../models/study_plan.dart';
import 'youtube_service.dart';

class ClassesRecommendationService {
  /// Returns popular search chips based on the active study plan category
  List<String> getPopularTopicsForCategory(String? category) {
    final cat = (category ?? '').toLowerCase();

    if (cat.contains('professional') ||
        cat.contains('ca ') ||
        cat.contains('cma') ||
        cat.contains('cs')) {
      return const [
        'AS 10 Property Plant & Equipment',
        'GST Input Tax Credit',
        'Corporate Law Chapter 7',
        'Audit SA 200 Series',
        'Cost Accounting Budgeting',
        'Capital Gains Tax',
        'Foreign Currency Translation',
        'Company Law Directors',
      ];
    } else if (cat.contains('competitive') ||
        cat.contains('upsc') ||
        cat.contains('ssc') ||
        cat.contains('jee') ||
        cat.contains('neet')) {
      return const [
        'Calculus One Shot JEE',
        'Electrostatics Physics',
        'Human Physiology NEET',
        'Modern Indian History UPSC',
        'Organic Reaction Mechanisms',
        'Definite Integration',
        'Data Interpretation Tricks',
        'Fundamental Rights Polity',
      ];
    } else if (cat.contains('school') ||
        cat.contains('cbse') ||
        cat.contains('icse') ||
        cat.contains('12th') ||
        cat.contains('10th')) {
      return const [
        'Class 10 Trigonometry Dear Sir',
        'Chemical Reactions & Equations',
        'Cell The Unit of Life Biology',
        'Electrostatics Class 12',
        'Calculus & Derivatives',
        'Optics & Ray Diagram',
        'Genetics & Heredity',
      ];
    } else if (cat.contains('college') ||
        cat.contains('university') ||
        cat.contains('engineering') ||
        cat.contains('bca') ||
        cat.contains('btech')) {
      return const [
        'Data Structures Abdul Bari',
        'Operating Systems Gate Smashers',
        'Linear Algebra 3Blue1Brown',
        'DBMS Normalization SQL',
        'Computer Networks OSI Model',
        'System Design Fundamentals',
        'Object-Oriented Programming',
      ];
    } else if (cat.contains('certification') ||
        cat.contains('aws') ||
        cat.contains('azure') ||
        cat.contains('pmp') ||
        cat.contains('cfa')) {
      return const [
        'AWS Solutions Architect freeCodeCamp',
        'Python Programming with Mosh',
        'Docker & Kubernetes TechWorld with Nana',
        'Power BI DAX Formulas',
        'PMP Agile Practice Guide',
        'Git & GitHub Masterclass',
      ];
    } else {
      // Default / Self-study
      return const [
        'How to Learn Skills Ali Abdaal',
        'Python Pandas Corey Schafer',
        'Full Stack Web Development',
        'Machine Learning Roadmap',
        'Excel Advanced Formulas',
        'UI/UX Design in Figma',
      ];
    }
  }

  /// Generates dynamic topic suggestions based on the active subjects and chapters
  List<String> getSubjectBasedSuggestions(StudyPlan? plan) {
    if (plan == null || plan.subjects.isEmpty) {
      return getPopularTopicsForCategory(null);
    }

    final suggestions = <String>{};

    for (final subject in plan.subjects) {
      suggestions.add('${subject.name} one shot');
      suggestions.add('${subject.name} revision');
      suggestions.add('${subject.name} marathon');

      for (final chapter in subject.chapters.take(2)) {
        suggestions.add('${subject.name} ${chapter.title}');
      }
    }

    // Blend in category popular topics
    final popular = getPopularTopicsForCategory(plan.category);
    for (final p in popular) {
      suggestions.add(p);
      if (suggestions.length >= 12) break;
    }

    return suggestions.toList();
  }

  /// Fetch recommended classes for Discover home.
  /// In LIVE API mode: queries YouTube dynamically with the student's category and subjects.
  /// In DEMO mode: strictly returns curated items matching the student's category.
  Future<List<VideoItem>> getRecommendedClasses({
    StudyPlan? plan,
    String? categoryFilter,
  }) async {
    final effectiveCategory = (categoryFilter != null &&
            categoryFilter.isNotEmpty &&
            categoryFilter != 'All')
        ? categoryFilter
        : (plan?.category.isNotEmpty == true
            ? plan!.category
            : 'College / University');

    final isLive = await YouTubeService.isLiveApiConfigured();

    if (isLive) {
      // LIVE MODE: Real, dynamic YouTube search
      String query = '';
      if (plan != null && plan.subjects.isNotEmpty) {
        final sub = plan.subjects.first;
        query = '${sub.name} lecture course $effectiveCategory';
      } else {
        query = _getDefaultQueryForCategory(effectiveCategory);
      }

      final res = await YouTubeService.searchClasses(
        query: query,
        category: effectiveCategory,
      );
      if (res.items.isNotEmpty) return res.items;
    }

    // DEMO MODE: Strictly return curated catalog items for this category
    return YouTubeService.getCuratedCatalogForCategory(effectiveCategory);
  }

  String _getDefaultQueryForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('college') || cat.contains('university')) {
      return 'Computer Science engineering data structures lectures';
    } else if (cat.contains('professional') || cat.contains('ca')) {
      return 'CA Intermediate accounting law tax classes';
    } else if (cat.contains('competitive') ||
        cat.contains('jee') ||
        cat.contains('neet') ||
        cat.contains('upsc')) {
      return 'Physics Wallah JEE NEET preparation classes';
    } else if (cat.contains('school')) {
      return 'Class 10 CBSE mathematics science lectures';
    } else if (cat.contains('certification')) {
      return 'AWS Solutions Architect Python course freeCodeCamp';
    } else {
      return 'Programming full course tutorial';
    }
  }

  /// Fetch related classes for a selected video from other teachers
  Future<List<VideoItem>> getRelatedClasses(VideoItem currentVideo) async {
    final titleParts = currentVideo.title.split(RegExp(r'[-–—|:]'));
    final searchTerms =
        titleParts.isNotEmpty && titleParts.first.trim().isNotEmpty
            ? titleParts.first.trim()
            : currentVideo.title;

    final res = await YouTubeService.searchClasses(
      query: searchTerms,
      category: currentVideo.studyCategory,
    );

    return res.items.where((v) => v.id != currentVideo.id).toList();
  }
}
