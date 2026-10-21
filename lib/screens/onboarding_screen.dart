import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(StudyPlan newPlan, [String? userName])
      onPlanCreated;
  final String? initialUserName;

  const OnboardingScreen({
    super.key,
    required this.onPlanCreated,
    this.initialUserName,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // Step 1: User Name & Plan Name & Category
  late final TextEditingController _userNameCtrl;
  late final TextEditingController _planNameCtrl;
  String _selectedCategory = 'College / University';
  String? _nameError;
  String? _planError;

  // Step 2: Category-Specific Conditional Fields
  final _categoryField1Ctrl =
      TextEditingController(text: 'University / Institution');
  final _categoryField2Ctrl = TextEditingController(text: 'Semester 4');
  final _primaryTargetCtrl = TextEditingController(text: 'End Semester Exams');
  DateTime? _primaryTargetDate = DateTime.now().add(const Duration(days: 90));
  final _backupTargetCtrl = TextEditingController(text: 'Supplementary Window');
  DateTime? _backupTargetDate;
  double _dailyGoalHours = 3.0;

  // Step 3: Initial Subjects
  final List<Map<String, dynamic>> _subjects = [];

  // Card definitions
  final List<_CategoryData> _categories = [
    const _CategoryData(
      id: 'College / University',
      title: 'College / University',
      description: 'Track semester subjects, exams, assignments and projects.',
      icon: Icons.school_rounded,
      bgColorLight: Color(0xFFF0EDFD),
      accentColor: Color(0xFF6C52EE),
      defaultPlanName: 'Semester Study Plan',
      defaultField1Label: 'Institution / College',
      defaultField1Hint: 'e.g. Stanford, Delhi University, BITS',
      defaultField2Label: 'Course & Semester',
      defaultField2Hint: 'e.g. B.Tech Computer Science - Sem 4',
      defaultPrimaryTarget: 'End Semester Exams',
      defaultBackupTarget: 'Mid-term Submissions',
      defaultSubjects: [
        'Data Structures & Algorithms',
        'Operating Systems & Networks',
        'Database Management Systems',
      ],
    ),
    const _CategoryData(
      id: 'Competitive Exam',
      title: 'Competitive Exam',
      description:
          'Prepare for UPSC, SSC, JEE, NEET, GATE, CUET or any other competitive exam.',
      icon: Icons.workspace_premium_rounded,
      bgColorLight: Color(0xFFFFF0E6),
      accentColor: Color(0xFFFF7043),
      defaultPlanName: 'Competitive Exam Target',
      defaultField1Label: 'Exam Name',
      defaultField1Hint: 'e.g. UPSC CSE, JEE Advanced, NEET, GATE',
      defaultField2Label: 'Target Attempt / Stage',
      defaultField2Hint: 'e.g. Prelims 2027, Stage 1, Mains',
      defaultPrimaryTarget: 'Prelims / Main Exam',
      defaultBackupTarget: 'Next Attempt / Phase 2',
      defaultSubjects: [
        'General Studies & Concepts',
        'Quantitative & Analytical Aptitude',
        'Previous Year Questions & Mocks',
      ],
    ),
    const _CategoryData(
      id: 'Professional Exam',
      title: 'Professional Exam',
      description:
          'For CA, CS, CMA, ACCA, CFA or any professional qualification course.',
      icon: Icons.business_center_rounded,
      bgColorLight: Color(0xFFE3F2FD),
      accentColor: Color(0xFF1976D2),
      defaultPlanName: 'Professional Qualification Plan',
      defaultField1Label: 'Qualification & Level',
      defaultField1Hint: 'e.g. CA Intermediate, CFA Level 1, ACCA',
      defaultField2Label: 'Group / Module',
      defaultField2Hint: 'e.g. Group 1 & 2, Part 1',
      defaultPrimaryTarget: 'May 2027 Attempt',
      defaultBackupTarget: 'September 2027 Attempt',
      defaultSubjects: [
        'Advanced Accounting',
        'Corporate & Other Laws',
        'Direct & Indirect Taxation',
      ],
    ),
    const _CategoryData(
      id: 'School',
      title: 'School',
      description: 'Track school subjects, exams, homework and revision.',
      icon: Icons.auto_stories_rounded,
      bgColorLight: Color(0xFFE8F8F0),
      accentColor: Color(0xFF2E7D32),
      defaultPlanName: 'High School Academic Plan',
      defaultField1Label: 'Class / Grade',
      defaultField1Hint: 'e.g. Class 12, Grade 10',
      defaultField2Label: 'Educational Board',
      defaultField2Hint: 'e.g. CBSE Board, ICSE, State Board',
      defaultPrimaryTarget: 'Annual Board Exams',
      defaultBackupTarget: 'Pre-Board / Mid-Term Exams',
      defaultSubjects: [
        'Mathematics',
        'Physics & Chemistry',
        'English & Social Studies',
      ],
    ),
    const _CategoryData(
      id: 'Certification',
      title: 'Certification',
      description:
          'For skill-based certifications like Google, AWS, Microsoft, etc.',
      icon: Icons.military_tech_rounded,
      bgColorLight: Color(0xFFF3E5F5),
      accentColor: Color(0xFF8E24AA),
      defaultPlanName: 'Cloud Certification Plan',
      defaultField1Label: 'Certification Title',
      defaultField1Hint: 'e.g. AWS Solutions Architect, GCP Associate',
      defaultField2Label: 'Certification Provider',
      defaultField2Hint: 'e.g. Amazon Web Services, Google Cloud',
      defaultPrimaryTarget: 'Exam Certification Date',
      defaultBackupTarget: 'Retake / Review Window',
      defaultSubjects: [
        'Architecture Fundamentals',
        'Hands-on Lab Exercises',
        'Practice Exam Questions',
      ],
    ),
    const _CategoryData(
      id: 'Self-Study',
      title: 'Self-Study',
      description:
          'Learn at your own pace, from new skills to personal learning goals.',
      icon: Icons.person_rounded,
      bgColorLight: Color(0xFFFCE4EC),
      accentColor: Color(0xFFD81B60),
      defaultPlanName: 'Independent Learning Roadmap',
      defaultField1Label: 'Primary Learning Goal',
      defaultField1Hint: 'e.g. Master Flutter & Backend Architecture',
      defaultField2Label: 'Focus Area / Projects',
      defaultField2Hint: 'e.g. 5 Real-world Projects & Open Source',
      defaultPrimaryTarget: 'Project Completion Target',
      defaultBackupTarget: 'Code Review & Polishing',
      defaultSubjects: [
        'Core Principles & Foundations',
        'Hands-on Project Building',
        'Advanced Topics & Deployment',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userNameCtrl = TextEditingController(
      text: widget.initialUserName?.isNotEmpty == true
          ? widget.initialUserName!
          : 'Shruti',
    );
    _planNameCtrl = TextEditingController(text: 'My Study Plan');
    _applyCategoryDefaults(_selectedCategory, isInit: true);
  }

  void _applyCategoryDefaults(String catId, {bool isInit = false}) {
    final cat = _categories.firstWhere((c) => c.id == catId,
        orElse: () => _categories.first);
    if (!isInit ||
        _planNameCtrl.text.trim().isEmpty ||
        _planNameCtrl.text == 'My Study Plan') {
      _planNameCtrl.text = cat.defaultPlanName;
    }
    _categoryField1Ctrl.text = '';
    _categoryField2Ctrl.text = '';
    _primaryTargetCtrl.text = cat.defaultPrimaryTarget;
    _backupTargetCtrl.text = cat.defaultBackupTarget;

    // Reset default subjects
    _subjects.clear();
    for (final sName in cat.defaultSubjects) {
      _subjects.add({
        'name': sName,
        'count': 30,
        'type': TrackingType.flatLectures,
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _userNameCtrl.dispose();
    _planNameCtrl.dispose();
    _categoryField1Ctrl.dispose();
    _categoryField2Ctrl.dispose();
    _primaryTargetCtrl.dispose();
    _backupTargetCtrl.dispose();
    super.dispose();
  }

  void _addSubjectField() {
    setState(() {
      _subjects.add({
        'name': 'Subject ${_subjects.length + 1}',
        'count': 25,
        'type': TrackingType.flatLectures,
      });
    });
  }

  void _removeSubjectField(int index) {
    if (_subjects.length <= 1) return;
    setState(() => _subjects.removeAt(index));
  }

  void _validateAndProceedStep1() {
    final name = _userNameCtrl.text.trim();
    final plan = _planNameCtrl.text.trim();

    setState(() {
      _nameError = name.isEmpty
          ? 'Please enter your name to personalize your study tracker.'
          : null;
      _planError =
          plan.isEmpty ? 'Please enter what you are preparing for.' : null;
    });

    if (_nameError == null && _planError == null) {
      // Advance to step 2
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _validateAndProceedStep2() {
    if (_primaryTargetCtrl.text.trim().isEmpty) {
      _primaryTargetCtrl.text = 'Target Exam';
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishSetup() async {
    final userName = _userNameCtrl.text.trim();
    final title = _planNameCtrl.text.trim().isEmpty
        ? 'My Study Plan'
        : _planNameCtrl.text.trim();
    final primaryLabel = _primaryTargetCtrl.text.trim().isEmpty
        ? 'Target Exam'
        : _primaryTargetCtrl.text.trim();
    final backupLabel = _backupTargetCtrl.text.trim().isEmpty
        ? 'Backup Target'
        : _backupTargetCtrl.text.trim();

    final List<Subject> parsedSubjects = [];
    for (int i = 0; i < _subjects.length; i++) {
      final item = _subjects[i];
      final name = (item['name'] as String).trim();
      if (name.isEmpty) continue;
      final count = (item['count'] as int).clamp(0, 500);
      final style = AppIcons.getStyleFor(name, i);

      parsedSubjects.add(
        Subject(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          total: count,
          trackingType: item['type'] as TrackingType,
          colorValue: style.$2.toARGB32(),
          iconCodePoint: style.$1.codePoint,
          revisionStatus: {
            'R1 (First Pass)': false,
            'R2 (Deep Review)': false,
            'R3 (Exam Practice)': false
          },
        ),
      );
    }

    final newPlan = StudyPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: _selectedCategory,
      primaryTargetLabel: primaryLabel,
      primaryTargetDate: _primaryTargetDate,
      backupTargetLabel: backupLabel,
      backupTargetDate: _backupTargetDate,
      dailyGoalMinutes: (_dailyGoalHours * 60).round(),
      subjects: parsedSubjects,
    );

    if (userName.isNotEmpty) {
      await StorageService.saveUserName(userName);
    }

    await widget.onPlanCreated(newPlan, userName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final showSideDecorations = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Background subtle gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF121124),
                            const Color(0xFF171630),
                            const Color(0xFF131227),
                          ]
                        : [
                            const Color(0xFFF9F7FD),
                            const Color(0xFFF2EDFA),
                            const Color(0xFFEDF3FC),
                          ],
                  ),
                ),
              ),
            ),

            // Top-right and bottom-right decorative dot patterns
            Positioned(
              top: 20,
              right: 24,
              child: _buildDotMatrix(isDark),
            ),
            Positioned(
              bottom: 20,
              right: 24,
              child: _buildDotMatrix(isDark),
            ),

            // Main Content Area with Optional Side Illustrations on large screens
            Row(
              children: [
                // Left Side Illustration (Desktop only)
                if (showSideDecorations)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildLeftIllustration(isDark),
                      ),
                    ),
                  ),

                // Center Onboarding Card & Form
                SizedBox(
                  width: showSideDecorations ? 880 : screenWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Header & 3-Step Progress Indicator
                      _buildTopHeader(isDark),

                      // 2. Page View (Steps 1, 2, 3)
                      Expanded(
                        child: PageView(
                          controller: _pageCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) =>
                              setState(() => _currentStep = i),
                          children: [
                            _buildStep1PlanInfo(isDark),
                            _buildStep2TargetsAndGoals(isDark),
                            _buildStep3Subjects(isDark),
                          ],
                        ),
                      ),

                      // 3. Bottom Action Area
                      _buildBottomActionArea(isDark),
                    ],
                  ),
                ),

                // Right Side Illustration (Desktop only)
                if (showSideDecorations)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildRightIllustration(isDark),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP HEADER & PROGRESS INDICATOR
  // ==========================================
  Widget _buildTopHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App Logo and Name
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Study Tracker',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3-Pill Progress Indicator + Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(3, (i) {
                  final isActive = i == _currentStep;
                  final isDone = i < _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 34 : 20,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: (isActive || isDone)
                          ? AppColors.primaryGradient
                          : null,
                      color: (isActive || isDone)
                          ? null
                          : (isDark
                              ? const Color(0xFF352F56)
                              : const Color(0xFFE4DCF5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              Text(
                'Step ${_currentStep + 1} of 3',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFC7C3DD)
                      : const Color(0xFF5C5474),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 1: WELCOME, NAME, PLAN, & 6 CATEGORIES
  // ==========================================
  Widget _buildStep1PlanInfo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Heading & Subtitle
          Text(
            'Welcome to Study Tracker 👋',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF15123A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Let's set up your study plan to create a personalized experience tailored to your goals.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.35,
              color: isDark ? const Color(0xFFB4AFCC) : const Color(0xFF6B6684),
            ),
          ),
          const SizedBox(height: 14),

          // 1. First, tell us your name (Card)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _nameError != null
                    ? Colors.redAccent
                    : (isDark ? AppColors.borderDark : const Color(0xFFECE7F6)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2D284D)
                            : const Color(0xFFF0EDFD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'First, tell us your name',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : const Color(0xFF15123A),
                            ),
                          ),
                          Text(
                            'So we can make your study journey more personal!',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF787295),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF17152B)
                        : const Color(0xFFFAF9FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF312C57)
                          : const Color(0xFFE6E1F2),
                      width: 1.1,
                    ),
                  ),
                  child: TextField(
                    controller: _userNameCtrl,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    onChanged: (val) {
                      if (_nameError != null && val.trim().isNotEmpty) {
                        setState(() => _nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Your Name (e.g. Shruti)',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF6B658A)
                            : const Color(0xFFA5A0BE),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 19,
                        color: Color(0xFF8C86A8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                    ),
                  ),
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _nameError!,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. What are you preparing for?
          Row(
            children: [
              const Icon(Icons.bookmark_border_rounded,
                  size: 19, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'What are you preparing for?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF15123A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _planError != null
                    ? Colors.redAccent
                    : (isDark ? AppColors.borderDark : const Color(0xFFECE7F6)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _planNameCtrl,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              onChanged: (val) {
                if (_planError != null && val.trim().isNotEmpty) {
                  setState(() => _planError = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'My Study Plan (e.g. CA Inter, B.Com, UPSC, etc.)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF6B658A)
                      : const Color(0xFFA5A0BE),
                ),
                prefixIcon: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 19,
                  color: Color(0xFF8C86A8),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
            ),
          ),
          if (_planError != null) ...[
            const SizedBox(height: 5),
            Text(
              _planError!,
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            'You can always create multiple study plans later.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF9D97B8) : const Color(0xFF8882A3),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Select a category
          Row(
            children: [
              const Icon(Icons.grid_view_rounded,
                  size: 19, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Select a category',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF15123A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Choose the option that best describes your study goal. You can customize it later.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF9D97B8) : const Color(0xFF787295),
            ),
          ),
          const SizedBox(height: 10),

          // 6 Category Selection Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int columns = 3;
              if (width < 500) {
                columns = 1;
              } else if (width < 700) {
                columns = 2;
              }

              final itemWidth = (width - ((columns - 1) * 10)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.id;
                  return SizedBox(
                    width: itemWidth,
                    child: _buildCategoryCard(cat, isSelected, isDark),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Category Card Widget
  Widget _buildCategoryCard(_CategoryData cat, bool isSelected, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = cat.id;
            _applyCategoryDefaults(cat.id);
          });
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppColors.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF262143) : const Color(0xFFF5F2FD))
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : const Color(0xFFECE7F6)),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? cat.accentColor.withValues(alpha: 0.22)
                      : cat.bgColorLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  cat.icon,
                  color: cat.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : const Color(0xFF15123A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFFA29DBF)
                            : const Color(0xFF666180),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Selection Badge or Chevron
              if (isSelected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF282542)
                        : const Color(0xFFF7F5FC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? const Color(0xFF6B658A)
                        : const Color(0xFFA29DBF),
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: CATEGORY-SPECIFIC TARGETS & GOALS
  // ==========================================
  Widget _buildStep2TargetsAndGoals(bool isDark) {
    final cat = _categories.firstWhere((c) => c.id == _selectedCategory,
        orElse: () => _categories.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D284D)
                      : const Color(0xFFF0EDFD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                '${cat.title} Targets 🎯',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF15123A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure milestones specifically customized for your ${_selectedCategory.toLowerCase()} goal.',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: isDark ? const Color(0xFFB4AFCC) : const Color(0xFF6B6684),
            ),
          ),
          const SizedBox(height: 22),

          // Conditional Field 1
          Text(
            cat.defaultField1Label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF15123A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _categoryField1Ctrl,
              decoration: InputDecoration(
                hintText: cat.defaultField1Hint,
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFFA5A0BE)),
                prefixIcon: const Icon(Icons.domain_rounded,
                    size: 20, color: Color(0xFF8C86A8)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Conditional Field 2
          Text(
            cat.defaultField2Label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF15123A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _categoryField2Ctrl,
              decoration: InputDecoration(
                hintText: cat.defaultField2Hint,
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFFA5A0BE)),
                prefixIcon: const Icon(Icons.layers_rounded,
                    size: 20, color: Color(0xFF8C86A8)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Target Exam Label & Date
          Text(
            'Primary Target Exam & Date',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF15123A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _primaryTargetCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. End Semester Exams, May 2027 Attempt',
                prefixIcon: Icon(Icons.flag_rounded,
                    size: 20, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _primaryTargetDate ?? now.add(const Duration(days: 90)),
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() => _primaryTargetDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF17152B) : const Color(0xFFFAF9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _primaryTargetDate == null
                          ? 'Select Target Date'
                          : DateFormat.yMMMMd().format(_primaryTargetDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Backup / Secondary Target (Optional)
          Text(
            'Backup / Secondary Target (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF15123A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _backupTargetCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. September Retake Window, Secondary Attempt',
                prefixIcon: Icon(Icons.outlined_flag_rounded,
                    size: 20, color: Color(0xFF8C86A8)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _backupTargetDate ?? now.add(const Duration(days: 180)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() => _backupTargetDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF17152B) : const Color(0xFFFAF9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_repeat_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _backupTargetDate == null
                          ? 'Select Backup Date (Optional)'
                          : DateFormat.yMMMMd().format(_backupTargetDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (_backupTargetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _backupTargetDate = null),
                    )
                  else
                    const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Daily Study Goal Target Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Study Target',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF15123A),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_dailyGoalHours.toStringAsFixed(1)} hrs / day',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _dailyGoalHours,
            min: 0.5,
            max: 12.0,
            divisions: 23,
            label: '${_dailyGoalHours.toStringAsFixed(1)} hrs',
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _dailyGoalHours = val),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: INITIAL SUBJECTS
  // ==========================================
  Widget _buildStep3Subjects(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initial Subjects & Courses 📚',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : const Color(0xFF15123A),
                      ),
                    ),
                    Text(
                      'Add subjects for your $_selectedCategory plan.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFB4AFCC)
                            : const Color(0xFF6B6684),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addSubjectField,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Subject'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // List of subject inputs
          ..._subjects.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: item['name'] as String,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Subject Name',
                            hintText:
                                'e.g. Data Structures, Macroeconomics, Tax',
                            prefixIcon: Icon(
                              AppIcons.getStyleFor(
                                      item['name'] as String, index)
                                  .$1,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : const Color(0xFFECE7F6),
                              ),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => item['name'] = val),
                        ),
                      ),
                      if (_subjects.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          onPressed: () => _removeSubjectField(index),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<TrackingType>(
                          initialValue: item['type'] as TrackingType,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Tracking Mode',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TrackingType.flatLectures,
                              child: Text('Lecture Counter (1..N)'),
                            ),
                            DropdownMenuItem(
                              value: TrackingType.chapters,
                              child: Text('Chapters & Topics'),
                            ),
                            DropdownMenuItem(
                              value: TrackingType.tasks,
                              child: Text('Task Checklist'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => item['type'] = val);
                          },
                        ),
                      ),
                      if (item['type'] == TrackingType.flatLectures) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: (item['count'] as int).toString(),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Total Lectures',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 0) {
                                item['count'] = parsed;
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM ACTION AREA
  // ==========================================
  Widget _buildBottomActionArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button on steps 2 & 3
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          const Spacer(),

          // Primary Action Button (Next Step / Launch)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_currentStep == 0) {
                  _validateAndProceedStep1();
                } else if (_currentStep == 1) {
                  _validateAndProceedStep2();
                } else {
                  _finishSetup();
                }
              },
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentStep == 2 ? 'Launch Tracker' : 'Next Step',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _currentStep == 2
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DECORATIVE ILLUSTRATIONS (DESKTOP)
  // ==========================================
  Widget _buildLeftIllustration(bool isDark) {
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pinned Sticky Note
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2C2748) : const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📌 Small\nsteps\nevery day\nlead to\nbig results.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: isDark
                          ? const Color(0xFFE5E1FA)
                          : const Color(0xFF5D5134),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text('💜', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stacked Pastel Books & Cup
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Stack of 2 Books
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Book (Lavender)
                  Container(
                    width: 105,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC7B9F8),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB4A1F3),
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(6)),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 6,
                          height: 24,
                          color: const Color(0xFFFF8FA3),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Bottom Book (Pastel Blue)
                  Container(
                    width: 120,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF90CAF9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF64B5F6),
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // Pen Cup
              Container(
                width: 32,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B284B)
                      : const Color(0xFFEBE6FA),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8), top: Radius.circular(3)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -12,
                      left: 6,
                      child: Container(
                        width: 4,
                        height: 20,
                        color: const Color(0xFF81D4FA),
                      ),
                    ),
                    Positioned(
                      top: -16,
                      left: 14,
                      child: Container(
                        width: 4,
                        height: 24,
                        color: const Color(0xFFBA68C8),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      left: 22,
                      child: Container(
                        width: 4,
                        height: 18,
                        color: const Color(0xFFFFB74D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Potted Plant
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282449) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, color: Color(0xFF9575CD), size: 18),
                SizedBox(width: 4),
                Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD54F), size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightIllustration(bool isDark) {
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist Clipboard & Target Bullseye
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clipboard
              Container(
                width: 95,
                height: 135,
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF221F3C) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top clip
                    Center(
                      child: Container(
                        width: 28,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3 Checkbox items
                    ...List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C52EE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 10),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF3F3B66)
                                      : const Color(0xFFE5E0F2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Bullseye Target
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF4081),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x38FF4081),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF4081),
                        ),
                        child: const Center(
                          child: Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pinned Sticky Note
          Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2C2748) : const Color(0xFFFFF5EA),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A better\nyou is\nin progress',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: isDark
                          ? const Color(0xFFE5E1FA)
                          : const Color(0xFF5D5134),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text('💜', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotMatrix(bool isDark) {
    return Column(
      children: List.generate(4, (r) {
        return Row(
          children: List.generate(4, (c) {
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (isDark ? const Color(0xFF383259) : const Color(0xFFDCD6EF))
                        .withValues(alpha: 0.7),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _CategoryData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color bgColorLight;
  final Color accentColor;
  final String defaultPlanName;
  final String defaultField1Label;
  final String defaultField1Hint;
  final String defaultField2Label;
  final String defaultField2Hint;
  final String defaultPrimaryTarget;
  final String defaultBackupTarget;
  final List<String> defaultSubjects;

  const _CategoryData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.bgColorLight,
    required this.accentColor,
    required this.defaultPlanName,
    required this.defaultField1Label,
    required this.defaultField1Hint,
    required this.defaultField2Label,
    required this.defaultField2Hint,
    required this.defaultPrimaryTarget,
    required this.defaultBackupTarget,
    required this.defaultSubjects,
  });
}
