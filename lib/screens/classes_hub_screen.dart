import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/study_plan.dart';
import '../services/classes_recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/channel_selection_dialog.dart';
import '../widgets/video_card.dart';
import 'class_detail_screen.dart';

class ClassesHubScreen extends StatefulWidget {
  final StudyPlan? studyPlan;
  final VoidCallback? onPlanUpdated;

  const ClassesHubScreen({
    super.key,
    this.studyPlan,
    this.onPlanUpdated,
  });

  @override
  State<ClassesHubScreen> createState() => _ClassesHubScreenState();
}

class _ClassesHubScreenState extends State<ClassesHubScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ClassesRecommendationService _recommendationService =
      ClassesRecommendationService();

  late TabController _tabController;

  // API Mode
  bool _isLiveApi = false;

  // Discover state
  List<String> _recentSearches = [];
  List<String> _popularTopics = [];
  String _selectedCategoryPill = 'All';
  List<VideoItem> _recommendedClasses = [];
  bool _isLoadingRecommendations = true;

  // Active Search state
  bool _isSearching = false;
  String _activeSearchQuery = '';
  bool _isLoadingResults = false;
  String? _searchErrorMessage;
  bool _isDemoResult = false;
  List<VideoItem> _allSearchResults = [];
  List<VideoItem> _filteredSearchResults = [];
  List<TeacherFilterItem> _availableTeachers = [];
  String? _selectedTeacher;
  ClassTypeFilter _selectedClassType = ClassTypeFilter.all;
  final ClassDurationFilter _selectedDuration = ClassDurationFilter.any;
  ClassSortOrder _selectedSortOrder = ClassSortOrder.relevance;
  String? _nextPageToken;
  bool _isLoadingMore = false;
  String? _lockedChannelId;
  String? _lockedChannelTitle;
  String? _parsedTeacher;
  String? _parsedSubject;
  bool _noMatchingForTeacherSubject = false;
  List<ChannelCandidate> _channelCandidates = [];
  bool _isResolvingUrl = false;

  // My Classes state
  List<SavedClass> _savedClasses = [];
  bool _isLoadingSaved = true;
  String _savedSearchQuery = '';
  ClassStatus? _savedStatusFilter;
  String? _savedSubjectFilter;

  final List<String> _categories = const [
    'All',
    'Professional Exam',
    'Competitive Exam',
    'College / University',
    'School',
    'Certification',
    'Self-Study',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _checkApiMode();
    await _loadRecentSearches();
    _loadPopularTopics();
    await _loadRecommendations();
    await _loadSavedClasses();
  }

  Future<void> _checkApiMode() async {
    final hasKey = await YouTubeService.isLiveApiConfigured();
    if (mounted) {
      setState(() {
        _isLiveApi = hasKey;
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    final recent = await StorageService.loadRecentClassesSearches();
    if (mounted) {
      setState(() {
        _recentSearches = recent;
      });
    }
  }

  void _loadPopularTopics() {
    final topics = _recommendationService.getPopularTopicsForCategory(
      _selectedCategoryPill == 'All'
          ? widget.studyPlan?.category
          : _selectedCategoryPill,
    );
    setState(() {
      _popularTopics = topics;
    });
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });
    try {
      final list = await _recommendationService.getRecommendedClasses(
        plan: widget.studyPlan,
        categoryFilter: _selectedCategoryPill,
      );
      if (mounted) {
        setState(() {
          _recommendedClasses = list;
          _isLoadingRecommendations = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _loadSavedClasses() async {
    final saved = await StorageService.loadSavedClasses();
    if (mounted) {
      setState(() {
        _savedClasses = saved;
        _isLoadingSaved = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // SEARCH EXECUTION
  Future<void> _executeSearch(String query, {bool saveRecent = true}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // Detect pasted YouTube video URLs (watch, youtu.be, live, shorts, embed)
    final directVideoId = YouTubeService.extractVideoId(cleanQuery);
    if (directVideoId != null) {
      await _handleDirectVideoUrl(directVideoId, cleanQuery);
      return;
    }

    setState(() {
      _isSearching = true;
      _activeSearchQuery = cleanQuery;
      _isLoadingResults = true;
      _searchErrorMessage = null;
      _noMatchingForTeacherSubject = false;
      _searchController.text = cleanQuery;
    });

    if (saveRecent) {
      await StorageService.addRecentClassesSearch(cleanQuery);
      await _loadRecentSearches();
    }

    final result = await YouTubeService.searchClasses(
      query: cleanQuery,
      category: _selectedCategoryPill == 'All' ? null : _selectedCategoryPill,
      classType: _selectedClassType,
      duration: _selectedDuration,
      sortOrder: _selectedSortOrder,
      selectedTeacher: _selectedTeacher,
      lockedChannelId: _lockedChannelId,
      lockedChannelTitle: _lockedChannelTitle,
      requireChannelSelectionIfAmbiguous: true,
    );

    if (!mounted) return;

    // Handle ambiguous channel disambiguation
    if (result.isChannelAmbiguous && result.channelCandidates.isNotEmpty) {
      setState(() {
        _isLoadingResults = false;
        _channelCandidates = result.channelCandidates;
        _parsedTeacher = result.parsedTeacher;
        _parsedSubject = result.parsedSubject;
      });
      ChannelSelectionDialog.show(
        context: context,
        teacherName: result.parsedTeacher ?? cleanQuery,
        subjectName: result.parsedSubject,
        candidates: result.channelCandidates,
        onChannelSelected: (chosen) {
          setState(() {
            _lockedChannelId = chosen.channelId;
            _lockedChannelTitle = chosen.title;
          });
          _executeSearch(cleanQuery, saveRecent: false);
        },
        onSearchAllChannels: () {
          setState(() {
            _lockedChannelId = null;
            _lockedChannelTitle = null;
            _selectedTeacher = null;
          });
          _executeSearch(result.parsedSubject ?? cleanQuery, saveRecent: false);
        },
      );
      return;
    }

    if (result.hasError && result.items.isEmpty) {
      setState(() {
        _isLoadingResults = false;
        _searchErrorMessage = result.errorMessage;
        _allSearchResults = [];
        _filteredSearchResults = [];
        _availableTeachers = [];
        _noMatchingForTeacherSubject = false;
      });
      return;
    }

    final teachers = YouTubeService.extractTeachers(result.items);

    setState(() {
      _isLoadingResults = false;
      _allSearchResults = result.items;
      _filteredSearchResults = result.items;
      _availableTeachers = teachers;
      _isDemoResult = result.isDemoMode;
      _nextPageToken = result.nextPageToken;
      _searchErrorMessage = result.errorMessage;
      _noMatchingForTeacherSubject = result.noMatchingForTeacherSubject;
      _parsedTeacher = result.parsedTeacher;
      _parsedSubject = result.parsedSubject;
      _lockedChannelTitle = result.resolvedChannelTitle ?? _lockedChannelTitle;
      _lockedChannelId = result.resolvedChannelId ?? _lockedChannelId;
      _channelCandidates = result.channelCandidates;
    });
  }

  void _searchSubjectAcrossAllTeachers(String subject) {
    setState(() {
      _lockedChannelId = null;
      _lockedChannelTitle = null;
      _selectedTeacher = null;
      _parsedTeacher = null;
      _noMatchingForTeacherSubject = false;
    });
    _executeSearch(subject);
  }

  void _showChannelSelector() async {
    final query = _activeSearchQuery;
    final parsed = YouTubeService.parseTeacherAndSubject(query);
    final teacherToResolve =
        _lockedChannelTitle ?? _selectedTeacher ?? parsed.teacherTerm ?? query;
    final apiKey = await YouTubeService.getApiKey();

    if (!mounted) return;

    var candidates = _channelCandidates;
    if (candidates.isEmpty) {
      candidates = await YouTubeService.resolveChannels(
        apiKey: apiKey,
        teacherQuery: teacherToResolve,
      );
    }

    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('No alternative channels found for "$teacherToResolve"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ChannelSelectionDialog.show(
      context: context,
      teacherName: teacherToResolve,
      subjectName: _parsedSubject ?? parsed.subjectTerm,
      candidates: candidates,
      onChannelSelected: (chosen) {
        setState(() {
          _lockedChannelId = chosen.channelId;
          _lockedChannelTitle = chosen.title;
        });
        _executeSearch(query, saveRecent: false);
      },
      onSearchAllChannels: () {
        setState(() {
          _lockedChannelId = null;
          _lockedChannelTitle = null;
          _selectedTeacher = null;
        });
        _executeSearch(_parsedSubject ?? query, saveRecent: false);
      },
    );
  }

  void _clearTeacherFilter() {
    setState(() {
      _selectedTeacher = null;
      _lockedChannelId = null;
      _lockedChannelTitle = null;
      _parsedTeacher = null;
      _noMatchingForTeacherSubject = false;
      if (_allSearchResults.isNotEmpty) {
        _filteredSearchResults = _allSearchResults;
      }
    });
    if (_parsedSubject != null && _parsedSubject!.isNotEmpty) {
      _executeSearch(_parsedSubject!, saveRecent: false);
    } else {
      _executeSearch(_activeSearchQuery, saveRecent: false);
    }
  }

  void _applyTeacherFilter(String? teacher) {
    setState(() {
      _selectedTeacher = teacher;
      if (teacher == null) {
        _filteredSearchResults = _allSearchResults;
      } else {
        _filteredSearchResults = _allSearchResults
            .where((v) =>
                v.channelTitle.toLowerCase().trim() ==
                teacher.toLowerCase().trim())
            .toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _activeSearchQuery = '';
      _searchController.clear();
      _isResolvingUrl = false;
      _allSearchResults = [];
      _filteredSearchResults = [];
      _availableTeachers = [];
      _selectedTeacher = null;
      _lockedChannelId = null;
      _lockedChannelTitle = null;
      _parsedTeacher = null;
      _parsedSubject = null;
      _noMatchingForTeacherSubject = false;
      _channelCandidates = [];
      _searchErrorMessage = null;
    });
  }

  Future<void> _handleDirectVideoUrl(String videoId, String rawUrl) async {
    setState(() {
      _isResolvingUrl = true;
    });

    try {
      final video = await YouTubeService.fetchVideoById(videoId);

      if (!mounted) return;

      setState(() {
        _isResolvingUrl = false;
      });

      if (video != null) {
        // Save to recent searches so student can easily find it later
        await StorageService.addRecentClassesSearch(video.title);
        await _loadRecentSearches();

        // Directly open video details screen
        _openDetail(video);
      } else {
        // Handle invalid, private, or unavailable videos gracefully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to load video ($videoId). It may be private, removed, or invalid.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingUrl = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading video: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_nextPageToken == null || _isLoadingMore || !_isSearching) return;

    setState(() {
      _isLoadingMore = true;
    });

    final result = await YouTubeService.searchClasses(
      query: _activeSearchQuery,
      category: _selectedCategoryPill == 'All' ? null : _selectedCategoryPill,
      classType: _selectedClassType,
      duration: _selectedDuration,
      sortOrder: _selectedSortOrder,
      selectedTeacher: _selectedTeacher,
      lockedChannelId: _lockedChannelId,
      lockedChannelTitle: _lockedChannelTitle,
      pageToken: _nextPageToken,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;
      _nextPageToken = result.nextPageToken;

      // Deduplicate new items to prevent duplicate video IDs
      final existingIds = _allSearchResults.map((v) => v.id).toSet();
      final newItems =
          result.items.where((v) => !existingIds.contains(v.id)).toList();
      _allSearchResults.addAll(newItems);

      _availableTeachers = YouTubeService.extractTeachers(_allSearchResults);
      _applyTeacherFilter(_selectedTeacher);
    });
  }

  bool _isClassSaved(String videoId) {
    return _savedClasses.any((c) => c.videoId == videoId);
  }

  Future<void> _toggleSave(VideoItem video) async {
    final existingIndex =
        _savedClasses.indexWhere((c) => c.videoId == video.id);
    if (existingIndex >= 0) {
      final removed = _savedClasses[existingIndex];
      await StorageService.removeSavedClass(removed.id);
      await _loadSavedClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from My Classes'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Auto-save with default initial values or prompt
      final newSaved = SavedClass.fromVideoItem(
        video,
        subjectId: widget.studyPlan?.subjects.isNotEmpty == true
            ? widget.studyPlan!.subjects.first.id
            : null,
        subjectName: widget.studyPlan?.subjects.isNotEmpty == true
            ? widget.studyPlan!.subjects.first.name
            : null,
        status: ClassStatus.notStarted,
      );
      await StorageService.addOrUpdateSavedClass(newSaved);
      await _loadSavedClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Saved to My Classes'),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(VideoItem video) {
    final savedMatch =
        _savedClasses.where((c) => c.videoId == video.id).firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassDetailScreen(
          video: video,
          studyPlan: widget.studyPlan,
          initialSavedClass: savedMatch,
          onSavedClassChanged: () {
            _loadSavedClasses();
            widget.onPlanUpdated?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Header
            _buildTopHeader(cardBg, borderColor, textPrimary, textSecondary),

            // Tab bar (Discover vs My Classes)
            _buildTabBar(cardBg, borderColor, textPrimary, textSecondary),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoverTab(
                      cardBg, borderColor, textPrimary, textSecondary, isDark),
                  _buildMyClassesTab(
                      cardBg, borderColor, textPrimary, textSecondary, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TOP HEADER
  Widget _buildTopHeader(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_display_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Classes Hub',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live API vs Demo Mode Badge
                    GestureDetector(
                      onTap: () async {
                        final changed = await ApiKeyDialog.show(context);
                        if (changed == true) {
                          await _checkApiMode();
                          if (_isSearching) {
                            _executeSearch(_activeSearchQuery,
                                saveRecent: false);
                          } else {
                            _loadRecommendations();
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isLiveApi
                              ? AppColors.primaryLight
                              : AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isLiveApi
                                ? AppColors.primary.withAlpha(60)
                                : AppColors.pastelMintText.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isLiveApi
                                  ? Icons.cloud_done_rounded
                                  : Icons.smart_button_rounded,
                              size: 12,
                              color: _isLiveApi
                                  ? AppColors.primary
                                  : AppColors.pastelMintText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isLiveApi ? 'Live API' : 'Demo Mode',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isLiveApi
                                    ? AppColors.primary
                                    : AppColors.pastelMintText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Multi-teacher educational discovery across YouTube',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'YouTube API Settings',
            color: textSecondary,
            onPressed: () async {
              final changed = await ApiKeyDialog.show(context);
              if (changed == true) {
                await _checkApiMode();
                if (_isSearching) {
                  _executeSearch(_activeSearchQuery, saveRecent: false);
                } else {
                  _loadRecommendations();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // TAB BAR
  Widget _buildTabBar(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          const Tab(
            icon: Icon(Icons.explore_rounded, size: 18),
            text: 'Discover',
          ),
          Tab(
            icon: const Icon(Icons.bookmark_rounded, size: 18),
            text: 'My Classes (${_savedClasses.length})',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DISCOVER TAB
  // ==========================================
  Widget _buildDiscoverTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Search Bar
                _buildSearchBar(
                    cardBg, borderColor, textPrimary, textSecondary),
                const SizedBox(height: 14),

                if (_isSearching)
                  // Search Results View
                  _buildSearchResultsSection(
                      cardBg, borderColor, textPrimary, textSecondary, isDark)
                else
                  // Discover Home View
                  _buildDiscoverHomeSection(
                      cardBg, borderColor, textPrimary, textSecondary, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // SEARCH BAR
  Widget _buildSearchBar(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final currentText = _searchController.text.trim();
    final isYouTubeUrl = YouTubeService.extractVideoId(currentText) != null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYouTubeUrl ? AppColors.primary.withAlpha(140) : borderColor,
          width: isYouTubeUrl ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            isYouTubeUrl
                ? Icons.play_circle_fill_rounded
                : Icons.search_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Search chapter, topic, teacher, or paste YouTube link...',
                hintStyle: TextStyle(
                  color: textSecondary.withAlpha(150),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(fontSize: 14, color: textPrimary),
              onChanged: (_) {
                setState(() {});
              },
              onSubmitted: (val) => _executeSearch(val),
            ),
          ),
          if (_searchController.text.isNotEmpty || _isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: textSecondary,
              onPressed: _clearSearch,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _isResolvingUrl
                  ? null
                  : () => _executeSearch(_searchController.text),
              icon: _isResolvingUrl
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isYouTubeUrl
                          ? Icons.open_in_new_rounded
                          : Icons.search_rounded,
                      size: 16,
                    ),
              label: Text(
                _isResolvingUrl
                    ? 'Loading...'
                    : (isYouTubeUrl ? 'Open Video' : 'Search'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DISCOVER HOME
  Widget _buildDiscoverHomeSection(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Demo Mode Honest Notice Banner
        if (!_isLiveApi) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pastelMint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.pastelMintText.withAlpha(60),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.pastelMintText,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Curated Demo Catalog Active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pastelMintText,
                        ),
                      ),
                      Text(
                        'Browse realistic multi-teacher educational videos with zero setup. Add your Google Cloud YouTube Data API v3 key in Settings to search live YouTube directly.',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      ApiKeyDialog.show(context).then((_) => _checkApiMode()),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text(
                    'Configure API',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Category Pills Row
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategoryPill == cat;
              return FilterChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    _selectedCategoryPill = cat;
                  });
                  _loadPopularTopics();
                  _loadRecommendations();
                },
                backgroundColor: cardBg,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : borderColor,
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        // Recent Searches (if any)
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await StorageService.clearRecentClassesSearches();
                  _loadRecentSearches();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                ),
                child: Text(
                  'Clear all',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((term) {
              return ActionChip(
                avatar: Icon(Icons.search, size: 14, color: textSecondary),
                label: Text(term),
                labelStyle: TextStyle(fontSize: 12, color: textPrimary),
                backgroundColor:
                    isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                onPressed: () => _executeSearch(term),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Popular Topics Chips
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              'Popular Topics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularTopics.map((topic) {
            return ActionChip(
              label: Text(topic),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              backgroundColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.primary.withAlpha(40)),
              ),
              onPressed: () => _executeSearch(topic),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Recommended for You Header
        Row(
          children: [
            const Icon(Icons.recommend_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Recommended for You',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            if (widget.studyPlan != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.studyPlan!.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Classes tailored to your study plan subjects and category.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 14),

        // Recommendations Grid
        if (_isLoadingRecommendations)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_recommendedClasses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No recommendations found. Try searching for a specific topic.',
                style: TextStyle(color: textSecondary),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 2 : 1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 1.05 : 1.15,
                ),
                itemCount: _recommendedClasses.length,
                itemBuilder: (context, index) {
                  final video = _recommendedClasses[index];
                  return VideoCard(
                    video: video,
                    isSaved: _isClassSaved(video.id),
                    onTap: () => _openDetail(video),
                    onToggleSave: () => _toggleSave(video),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // SEARCH RESULTS WITH MULTI-TEACHER DISCOVERY
  // ==========================================
  Widget _buildSearchResultsSection(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Top Summary Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Results for "$_activeSearchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isDemoResult) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Demo Catalog',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pastelMintText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${_filteredSearchResults.length} classes available from multiple teachers',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Strict Channel / Educator Filter Pill (if active)
        if (_lockedChannelTitle != null ||
            _selectedTeacher != null ||
            _parsedTeacher != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Strict Educator Filter: ${_lockedChannelTitle ?? _selectedTeacher ?? _parsedTeacher}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: _showChannelSelector,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Change Channel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _clearTeacherFilter,
                  child: const Tooltip(
                    message: 'Clear teacher filter and search all',
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 1. DYNAMIC TEACHER FILTER PILLS (Multi-Teacher Comparison!)
        if (_availableTeachers.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Filter by Teacher / Channel:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              if (_selectedTeacher != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => _applyTeacherFilter(null),
                  child: const Text(
                    'Show All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // "All Teachers" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('All Teachers (${_allSearchResults.length})'),
                    selected: _selectedTeacher == null,
                    onSelected: (_) => _applyTeacherFilter(null),
                    backgroundColor: cardBg,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color:
                          _selectedTeacher == null ? Colors.white : textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _selectedTeacher == null
                            ? AppColors.primary
                            : borderColor,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                ),
                // Dynamic teacher chips
                ..._availableTeachers.map((teacher) {
                  final isSelected = _selectedTeacher == teacher.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: isSelected
                            ? Colors.white.withAlpha(200)
                            : AppColors.primaryLight,
                        child: Text(
                          teacher.name.isNotEmpty
                              ? teacher.name.characters.first.toUpperCase()
                              : 'T',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      label: Text('${teacher.name} (${teacher.videoCount})'),
                      selected: isSelected,
                      onSelected: (_) =>
                          _applyTeacherFilter(isSelected ? null : teacher.name),
                      backgroundColor: cardBg,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textPrimary,
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : borderColor,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. CLASS TYPE & DURATION FILTERS ROW
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Class Type Filters
              ...ClassTypeFilter.values.map((type) {
                final isSelected = _selectedClassType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedClassType = type;
                        });
                        _executeSearch(_activeSearchQuery, saveRecent: false);
                      }
                    },
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: cardBg,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : textSecondary,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : borderColor,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }),
              const SizedBox(width: 8),

              // Sort dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ClassSortOrder>(
                    value: _selectedSortOrder,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    items: ClassSortOrder.values.map((order) {
                      return DropdownMenuItem(
                        value: order,
                        child: Text(order.label),
                      );
                    }).toList(),
                    onChanged: (newOrder) {
                      if (newOrder != null) {
                        setState(() {
                          _selectedSortOrder = newOrder;
                        });
                        _executeSearch(_activeSearchQuery, saveRecent: false);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Error message banner (if any)
        if (_searchErrorMessage != null && _allSearchResults.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pastelPink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.pastelPinkText.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.pastelPinkText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _searchErrorMessage!,
                        style: const TextStyle(
                          color: AppColors.pastelPinkText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await YouTubeService.setApiKey('');
                        await _checkApiMode();
                        _executeSearch(_activeSearchQuery, saveRecent: false);
                      },
                      child: const Text('Switch to Demo Mode'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _executeSearch(_activeSearchQuery, saveRecent: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Loading Indicator
        if (_isLoadingResults)
          const Padding(
            padding: EdgeInsets.all(60),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text(
                    'Searching across teachers & channels...',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          )
        else if (_noMatchingForTeacherSubject)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching classes found for "${_parsedTeacher ?? _lockedChannelTitle ?? 'this educator'}" on "${_parsedSubject ?? 'this subject'}"',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This educator channel does not appear to have classes covering this subject. You can search across all educators or pick a different channel.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_parsedSubject != null && _parsedSubject!.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _searchSubjectAcrossAllTeachers(_parsedSubject!),
                        icon: const Icon(Icons.public_rounded, size: 16),
                        label: Text(
                            'Search "$_parsedSubject" across all teachers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: _showChannelSelector,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Select another channel'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (_filteredSearchResults.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: textSecondary.withAlpha(120),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No classes found matching your criteria',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try removing the teacher filter or using broader keywords.',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (_selectedTeacher != null)
                    OutlinedButton(
                      onPressed: () => _applyTeacherFilter(null),
                      child: const Text('Show All Teachers'),
                    ),
                ],
              ),
            ),
          )
        else
          // Results Grid
          Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isWide ? 1.05 : 1.15,
                    ),
                    itemCount: _filteredSearchResults.length,
                    itemBuilder: (context, index) {
                      final video = _filteredSearchResults[index];
                      return VideoCard(
                        video: video,
                        isSaved: _isClassSaved(video.id),
                        onTap: () => _openDetail(video),
                        onToggleSave: () => _toggleSave(video),
                      );
                    },
                  );
                },
              ),

              // Load More Button
              if (_nextPageToken != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: OutlinedButton(
                    onPressed: _isLoadingMore ? null : _loadMore,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: borderColor),
                    ),
                    child: _isLoadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Load More Classes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // ==========================================
  // MY CLASSES TAB
  // ==========================================
  Widget _buildMyClassesTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (_isLoadingSaved) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter saved classes
    var filtered = _savedClasses;
    if (_savedSearchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) =>
              c.title.toLowerCase().contains(_savedSearchQuery.toLowerCase()) ||
              c.channelTitle
                  .toLowerCase()
                  .contains(_savedSearchQuery.toLowerCase()) ||
              (c.linkedSubjectName ?? '')
                  .toLowerCase()
                  .contains(_savedSearchQuery.toLowerCase()))
          .toList();
    }
    if (_savedStatusFilter != null) {
      filtered = filtered.where((c) => c.status == _savedStatusFilter).toList();
    }
    if (_savedSubjectFilter != null) {
      filtered = filtered
          .where((c) => c.linkedSubjectId == _savedSubjectFilter)
          .toList();
    }

    final totalSaved = _savedClasses.length;
    final inProgressCount =
        _savedClasses.where((c) => c.status == ClassStatus.inProgress).length;
    final completedCount =
        _savedClasses.where((c) => c.status == ClassStatus.completed).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Stats Summary Header
                _buildSavedStatsRow(
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  totalSaved,
                  inProgressCount,
                  completedCount,
                ),
                const SizedBox(height: 18),

                // 2. Search & Filter Bar
                _buildSavedFilters(
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  isDark,
                ),
                const SizedBox(height: 18),

                // 3. Saved Classes List
                if (_savedClasses.isEmpty)
                  _buildEmptySavedState(textPrimary, textSecondary)
                else if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'No saved classes match your current filter.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 650;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 2 : 1,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWide ? 1.05 : 1.15,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final saved = filtered[index];
                          return _buildSavedClassCard(
                            saved,
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isDark,
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedStatsRow(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    int total,
    int inProgress,
    int completed,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Saved',
            total.toString(),
            Icons.bookmark_added_rounded,
            AppColors.primary,
            AppColors.primaryLight,
            cardBg,
            borderColor,
            textPrimary,
            textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            inProgress.toString(),
            Icons.timelapse_rounded,
            AppColors.primary,
            AppColors.pastelPurple,
            cardBg,
            borderColor,
            textPrimary,
            textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completed.toString(),
            Icons.check_circle_rounded,
            AppColors.pastelMintText,
            AppColors.pastelMint,
            cardBg,
            borderColor,
            textPrimary,
            textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    Color iconBg,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedFilters(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final subjects = widget.studyPlan?.subjects ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search inside saved
        TextField(
          decoration: InputDecoration(
            hintText: 'Search within saved classes & notes...',
            hintStyle: TextStyle(
              fontSize: 12,
              color: textSecondary.withAlpha(150),
            ),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.primary),
            filled: true,
            fillColor: cardBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          style: TextStyle(fontSize: 13, color: textPrimary),
          onChanged: (val) {
            setState(() {
              _savedSearchQuery = val.trim();
            });
          },
        ),
        const SizedBox(height: 10),

        // Status & Subject Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // All Status
              FilterChip(
                label: const Text('All Status'),
                selected: _savedStatusFilter == null,
                onSelected: (_) => setState(() => _savedStatusFilter = null),
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _savedStatusFilter == null
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _savedStatusFilter == null
                      ? AppColors.primary
                      : textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _savedStatusFilter == null
                        ? AppColors.primary
                        : borderColor,
                  ),
                ),
                showCheckmark: false,
              ),
              const SizedBox(width: 6),
              // Status values
              ...ClassStatus.values.map((st) {
                final isSelected = _savedStatusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(st.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _savedStatusFilter = isSelected ? null : st;
                    }),
                    selectedColor: st.backgroundColor,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? st.color : textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? st.color : borderColor,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }),

              if (subjects.isNotEmpty) ...[
                const SizedBox(width: 8),
                // Subject dropdown filter
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _savedSubjectFilter,
                      hint: Text('All Subjects',
                          style: TextStyle(fontSize: 11, color: textSecondary)),
                      isDense: true,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Subjects',
                              style: TextStyle(
                                  fontSize: 11, color: textSecondary)),
                        ),
                        ...subjects.map((s) {
                          return DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name,
                                style: const TextStyle(fontSize: 11)),
                          );
                        }),
                      ],
                      onChanged: (newSubId) {
                        setState(() {
                          _savedSubjectFilter = newSubId;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedClassCard(
    SavedClass saved,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final video = saved.toVideoItem();
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetail(video),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top status and subject badge row
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: saved.status.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(saved.status.icon,
                              size: 12, color: saved.status.color),
                          const SizedBox(width: 4),
                          Text(
                            saved.status.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: saved.status.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (saved.linkedSubjectName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          saved.linkedSubjectName!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Video Card contents
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              saved.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.primaryLight,
                                child: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Title & Channel
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              saved.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              saved.channelTitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Personal Notes Preview (if any)
                if (saved.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            saved.notes,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions row
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      saved.duration ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const Spacer(),
                    // Quick Status Changer Popup
                    PopupMenuButton<ClassStatus>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      tooltip: 'Change Status',
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (newStatus) async {
                        saved.status = newStatus;
                        await StorageService.addOrUpdateSavedClass(saved);
                        _loadSavedClasses();
                      },
                      itemBuilder: (context) => ClassStatus.values.map((st) {
                        return PopupMenuItem(
                          value: st,
                          child: Row(
                            children: [
                              Icon(st.icon, size: 16, color: st.color),
                              const SizedBox(width: 8),
                              Text(st.label,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySavedState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No classes saved yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore classes across multiple teachers in the Discover tab and tap the bookmark icon to save them to your personal study tracker.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Explore Classes in Discover'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
