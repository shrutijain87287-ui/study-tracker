import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/class_model.dart';
import '../models/note_model.dart';
import '../models/study_plan.dart';
import '../services/classes_recommendation_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_card.dart';
import 'notebook_editor_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final VideoItem video;
  final StudyPlan? studyPlan;
  final SavedClass? initialSavedClass;
  final VoidCallback? onSavedClassChanged;

  const ClassDetailScreen({
    super.key,
    required this.video,
    this.studyPlan,
    this.initialSavedClass,
    this.onSavedClassChanged,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final ClassesRecommendationService _recommendationService =
      ClassesRecommendationService();

  SavedClass? _savedClass;
  bool _isSaved = false;

  // Form states for saving / updating
  late ClassStatus _selectedStatus;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedChapterId;
  String? _selectedChapterTitle;
  late TextEditingController _notesController;

  bool _isDescriptionExpanded = false;
  List<VideoItem> _relatedVideos = [];
  bool _isLoadingRelated = true;
  List<Notebook> _linkedNotebooks = [];

  @override
  void initState() {
    super.initState();
    _savedClass = widget.initialSavedClass;
    _isSaved = _savedClass != null;

    _selectedStatus = _savedClass?.status ?? ClassStatus.notStarted;
    _selectedSubjectId = _savedClass?.linkedSubjectId;
    _selectedSubjectName = _savedClass?.linkedSubjectName;
    _selectedChapterId = _savedClass?.linkedChapterId;
    _selectedChapterTitle = _savedClass?.linkedChapterTitle;
    _notesController = TextEditingController(text: _savedClass?.notes ?? '');

    // Default subject to first available if none selected
    if (_selectedSubjectId == null &&
        widget.studyPlan != null &&
        widget.studyPlan!.subjects.isNotEmpty) {
      final firstSub = widget.studyPlan!.subjects.first;
      _selectedSubjectId = firstSub.id;
      _selectedSubjectName = firstSub.name;
    }

    _loadExistingSavedClass();
    _loadRelatedClasses();
    _loadLinkedNotebooks();
  }

  Future<void> _loadLinkedNotebooks() async {
    final list = await StorageService.getNotebooksForClass(widget.video.id);
    if (mounted) {
      setState(() {
        _linkedNotebooks = list;
      });
    }
  }

  Future<void> _openOrCreateClassNotebook() async {
    if (_linkedNotebooks.isNotEmpty) {
      // Open the latest linked notebook
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotebookEditorScreen(
            notebook: _linkedNotebooks.first,
            onNotebookUpdated: _loadLinkedNotebooks,
          ),
        ),
      );
      return;
    }

    // Create a new linked notebook for this class
    final newNb = Notebook(
      id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
      title: '${widget.video.title} Notes',
      description: 'Study notes for ${widget.video.channelTitle}',
      category: widget.studyPlan?.category ?? 'General',
      subjectId: _selectedSubjectId,
      subjectName: _selectedSubjectName,
      chapterId: _selectedChapterId,
      chapterTitle: _selectedChapterTitle,
      linkedVideoId: widget.video.id,
      linkedVideoTitle: widget.video.title,
      coverColorValue: 0xFF6C52EE,
      tags: [
        'class-notes',
        if (_selectedSubjectName != null) _selectedSubjectName!.toLowerCase(),
      ],
      pages: [
        NotePage(
          id: 'page_${DateTime.now().millisecondsSinceEpoch}_1',
          pageNumber: 1,
          title: 'Class Overview',
          content:
              '# ${widget.video.title}\n**Channel:** ${widget.video.channelTitle}\n\n## Key Concepts\n- \n\n## Important Formulas & Points\n- \n\n## Questions / Doubts\n- ',
        ),
      ],
    );

    await StorageService.saveNotebook(newNb);
    await _loadLinkedNotebooks();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotebookEditorScreen(
            notebook: newNb,
            onNotebookUpdated: _loadLinkedNotebooks,
          ),
        ),
      );
    }
  }

  Future<void> _loadExistingSavedClass() async {
    final allSaved = await StorageService.loadSavedClasses();
    final matchIndex = allSaved.indexWhere((c) => c.videoId == widget.video.id);
    if (matchIndex >= 0) {
      if (!mounted) return;
      setState(() {
        _savedClass = allSaved[matchIndex];
        _isSaved = true;
        _selectedStatus = _savedClass!.status;
        _selectedSubjectId = _savedClass!.linkedSubjectId;
        _selectedSubjectName = _savedClass!.linkedSubjectName;
        _selectedChapterId = _savedClass!.linkedChapterId;
        _selectedChapterTitle = _savedClass!.linkedChapterTitle;
        _notesController.text = _savedClass!.notes;
      });
    }
  }

  Future<void> _loadRelatedClasses() async {
    try {
      final related =
          await _recommendationService.getRelatedClasses(widget.video);
      if (!mounted) return;
      setState(() {
        _relatedVideos = related;
        _isLoadingRelated = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRelated = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _launchYouTube() async {
    final uri = Uri.parse(widget.video.youtubeUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not launch ${widget.video.youtubeUrl}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching YouTube: $e')),
        );
      }
    }
  }

  Future<void> _launchChannel() async {
    final uri = Uri.parse(widget.video.channelUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _saveOrUpdateClass() async {
    final newSaved = SavedClass.fromVideoItem(
      widget.video,
      status: _selectedStatus,
      subjectId: _selectedSubjectId,
      subjectName: _selectedSubjectName,
      chapterId: _selectedChapterId,
      chapterTitle: _selectedChapterTitle,
      notes: _notesController.text.trim(),
    );

    await StorageService.addOrUpdateSavedClass(newSaved);
    widget.onSavedClassChanged?.call();

    if (!mounted) return;
    setState(() {
      _savedClass = newSaved;
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(_isSaved
                ? 'Class updated in My Classes'
                : 'Class saved to My Classes'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteFromSaved() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove from My Classes?'),
        content: const Text(
          'This will remove this class and any associated personal notes from your saved tracker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && _savedClass != null) {
      await StorageService.removeSavedClass(_savedClass!.id);
      widget.onSavedClassChanged?.call();
      if (!mounted) return;
      setState(() {
        _savedClass = null;
        _isSaved = false;
        _notesController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from My Classes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Class Details',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSaved ? AppColors.primary : textSecondary,
            ),
            tooltip: _isSaved ? 'Saved to My Classes' : 'Save Class',
            onPressed: _isSaved ? _deleteFromSaved : _saveOrUpdateClass,
          ),
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, color: textSecondary),
            tooltip: 'Open in YouTube',
            onPressed: _launchYouTube,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Video Preview & Player Launch Banner
                _buildVideoHero(
                    cardBg, borderColor, textPrimary, textSecondary),
                const SizedBox(height: 20),

                // 2. Video Title, Teacher & Metadata Card
                _buildVideoMetadataCard(
                    cardBg, borderColor, textPrimary, textSecondary, isDark),
                const SizedBox(height: 20),

                // 3. Study Tracker Integration Card ("Save to My Classes")
                _buildStudyTrackerCard(
                    cardBg, borderColor, textPrimary, textSecondary, isDark),
                const SizedBox(height: 28),

                // 4. Related Classes from Other Teachers (Multi-Teacher Exploration)
                _buildRelatedClassesSection(textPrimary, textSecondary),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoHero(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 16:9 Thumbnail preview with play affordance
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C52EE), Color(0xFF2D9CDB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 64,
                      ),
                    ),
                  ),
                ),
                // Gradient scrim
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black45],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Duration overlay
                if (widget.video.duration != null &&
                    widget.video.duration!.isNotEmpty)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.video.duration!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Center play button
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: _launchYouTube,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Launch action bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _launchYouTube,
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: const Text(
                      'Open & Watch in YouTube',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000), // YouTube red
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _launchChannel,
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('Channel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: borderColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMetadataCard(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.video.studyCategory,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            widget.video.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Channel and stats row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.video.channelTitle.isNotEmpty
                      ? widget.video.channelTitle.characters.first.toUpperCase()
                      : 'T',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.video.channelTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.video.isVerifiedTeacher) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    if (widget.video.subscriberCount != null)
                      Text(
                        widget.video.subscriberCount!,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.video.viewCount != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.video.viewCount!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.video.formattedPublishedDate.isNotEmpty)
                Text(
                  widget.video.formattedPublishedDate,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
            ],
          ),

          // Collapsible description
          if (widget.video.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              widget.video.description,
              maxLines: _isDescriptionExpanded ? null : 3,
              overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Text(
                _isDescriptionExpanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyTrackerCard(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final subjects = widget.studyPlan?.subjects ?? [];

    // Find currently selected subject object to extract chapters
    Subject? currentSubject;
    if (_selectedSubjectId != null) {
      currentSubject = subjects.firstWhere(
        (s) => s.id == _selectedSubjectId,
        orElse: () =>
            subjects.isNotEmpty ? subjects.first : Subject(id: '', name: ''),
      );
    }

    final chapters = currentSubject?.chapters ?? [];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              _isSaved ? AppColors.primary.withValues(alpha: 0.4) : borderColor,
          width: _isSaved ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.playlist_add_check_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Tracker Integration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      _isSaved
                          ? 'This class is saved in your study plan.'
                          : 'Track progress, link to subject/chapter & add notes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSaved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pastelMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Saved',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pastelMintText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Status Selection Pills
          Text(
            'Completion Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ClassStatus.values.map((status) {
              final isSelected = _selectedStatus == status;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? status.color : status.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? status.color
                            : status.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status.icon,
                          size: 18,
                          color: isSelected ? Colors.white : status.color,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // 2. Link to Subject
          if (subjects.isNotEmpty) ...[
            Text(
              'Link to Subject',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSubjectId,
                  dropdownColor: cardBg,
                  hint: Text('Select Subject',
                      style: TextStyle(color: textSecondary)),
                  items: subjects.map((sub) {
                    return DropdownMenuItem<String>(
                      value: sub.id,
                      child: Text(
                        sub.name,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId == null) return;
                    final sub = subjects.firstWhere((s) => s.id == newId);
                    setState(() {
                      _selectedSubjectId = newId;
                      _selectedSubjectName = sub.name;
                      _selectedChapterId = null;
                      _selectedChapterTitle = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Link to Chapter (if chapters exist)
            if (chapters.isNotEmpty) ...[
              Text(
                'Link to Chapter (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedChapterId,
                    dropdownColor: cardBg,
                    hint: Text('All Chapters / General',
                        style: TextStyle(color: textSecondary, fontSize: 13)),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Chapters / General',
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                      ),
                      ...chapters.map((ch) {
                        return DropdownMenuItem<String>(
                          value: ch.id,
                          child: Text(
                            ch.title,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                          ),
                        );
                      }),
                    ],
                    onChanged: (newId) {
                      setState(() {
                        _selectedChapterId = newId;
                        _selectedChapterTitle = newId != null
                            ? chapters.firstWhere((c) => c.id == newId).title
                            : null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],

          // 4. Personal Notes Field
          Text(
            'Personal Study Notes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. Important formulas covered at 14:30. Revise before exam.',
              hintStyle: TextStyle(
                fontSize: 12,
                color: textSecondary.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(fontSize: 13, color: textPrimary),
          ),
          const SizedBox(height: 18),

          // 5. Actions
          Row(
            children: [
              if (_isSaved) ...[
                TextButton.icon(
                  onPressed: _deleteFromSaved,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              ElevatedButton.icon(
                onPressed: _saveOrUpdateClass,
                icon: Icon(
                  _isSaved ? Icons.check_rounded : Icons.bookmark_add_rounded,
                  size: 18,
                ),
                label: Text(
                  _isSaved ? 'Update Saved Class' : 'Save to My Classes',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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

          const Divider(height: 28),

          // 6. Digital Study Notes (Rich Text & Handwriting Integration)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Digital Study Notebook',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _openOrCreateClassNotebook,
                icon: Icon(
                  _linkedNotebooks.isEmpty
                      ? Icons.note_add_rounded
                      : Icons.open_in_new_rounded,
                  size: 16,
                ),
                label: Text(
                  _linkedNotebooks.isEmpty
                      ? 'Create Class Notes'
                      : 'Open Notebook (${_linkedNotebooks.length})',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (_linkedNotebooks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF262243) : const Color(0xFFF6F3FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B3363)
                      : const Color(0xFFE4DCF9),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked to: ${_linkedNotebooks.first.title} (${_linkedNotebooks.first.totalPages} pages, ${_linkedNotebooks.first.totalWordCount} words)',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedClassesSection(Color textPrimary, Color textSecondary) {
    if (_isLoadingRelated) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_relatedVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.people_alt_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Other Teachers Explaining This Topic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Compare teaching styles and select the explanation that works best for you.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 580;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isWide ? 1.05 : 1.15,
              ),
              itemCount: _relatedVideos.take(4).length,
              itemBuilder: (context, index) {
                final relatedVideo = _relatedVideos[index];
                return VideoCard(
                  video: relatedVideo,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ClassDetailScreen(
                          video: relatedVideo,
                          studyPlan: widget.studyPlan,
                          onSavedClassChanged: widget.onSavedClassChanged,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
