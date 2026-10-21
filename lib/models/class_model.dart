import 'package:flutter/material.dart';

/// Learning progress status for a saved class
enum ClassStatus {
  notStarted,
  inProgress,
  completed,
}

extension ClassStatusExtension on ClassStatus {
  String get label {
    switch (this) {
      case ClassStatus.notStarted:
        return 'Not Started';
      case ClassStatus.inProgress:
        return 'In Progress';
      case ClassStatus.completed:
        return 'Completed';
    }
  }

  IconData get icon {
    switch (this) {
      case ClassStatus.notStarted:
        return Icons.radio_button_unchecked_rounded;
      case ClassStatus.inProgress:
        return Icons.timelapse_rounded;
      case ClassStatus.completed:
        return Icons.check_circle_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ClassStatus.notStarted:
        return const Color(0xFF8C86A8);
      case ClassStatus.inProgress:
        return const Color(0xFF6C52EE); // Primary purple
      case ClassStatus.completed:
        return const Color(0xFF10B981); // Emerald green
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ClassStatus.notStarted:
        return const Color(0xFFF3F1FA);
      case ClassStatus.inProgress:
        return const Color(0xFFEBE6FA);
      case ClassStatus.completed:
        return const Color(0xFFE6F8F0);
    }
  }
}

/// Class-type category filters (keywords for YouTube query / title matching)
enum ClassTypeFilter {
  all,
  fullLecture,
  oneShot,
  revision,
  marathon,
}

extension ClassTypeFilterExtension on ClassTypeFilter {
  String get label {
    switch (this) {
      case ClassTypeFilter.all:
        return 'All Types';
      case ClassTypeFilter.fullLecture:
        return 'Full Lecture';
      case ClassTypeFilter.oneShot:
        return 'One-Shot';
      case ClassTypeFilter.revision:
        return 'Revision';
      case ClassTypeFilter.marathon:
        return 'Marathon';
    }
  }

  String get searchKeyword {
    switch (this) {
      case ClassTypeFilter.all:
        return '';
      case ClassTypeFilter.fullLecture:
        return 'full lecture';
      case ClassTypeFilter.oneShot:
        return 'one shot';
      case ClassTypeFilter.revision:
        return 'revision';
      case ClassTypeFilter.marathon:
        return 'marathon';
    }
  }
}

/// Duration filter for YouTube search
enum ClassDurationFilter {
  any,
  short, // < 4 min
  medium, // 4 - 20 min
  long, // > 20 min
}

extension ClassDurationFilterExtension on ClassDurationFilter {
  String get label {
    switch (this) {
      case ClassDurationFilter.any:
        return 'Any duration';
      case ClassDurationFilter.short:
        return 'Short (< 4 min)';
      case ClassDurationFilter.medium:
        return 'Medium (4–20 min)';
      case ClassDurationFilter.long:
        return 'Long (> 20 min)';
    }
  }

  String get apiValue {
    switch (this) {
      case ClassDurationFilter.any:
        return 'any';
      case ClassDurationFilter.short:
        return 'short';
      case ClassDurationFilter.medium:
        return 'medium';
      case ClassDurationFilter.long:
        return 'long';
    }
  }
}

/// Sort order for search results
enum ClassSortOrder {
  relevance,
  date,
}

extension ClassSortOrderExtension on ClassSortOrder {
  String get label {
    switch (this) {
      case ClassSortOrder.relevance:
        return 'Relevance';
      case ClassSortOrder.date:
        return 'Latest (Upload Date)';
    }
  }

  String get apiValue {
    switch (this) {
      case ClassSortOrder.relevance:
        return 'relevance';
      case ClassSortOrder.date:
        return 'date';
    }
  }
}

/// Represents an educational video discovered from YouTube or Demo catalog
class VideoItem {
  final String id;
  final String title;
  final String description;
  final String channelTitle;
  final String channelId;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final String? duration; // e.g. "1:28:40"
  final String? viewCount; // e.g. "320K views"
  final String? subscriberCount; // e.g. "1.2M subscribers"
  final bool isVerifiedTeacher;
  final String studyCategory;

  const VideoItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.channelTitle,
    this.channelId = '',
    required this.thumbnailUrl,
    this.publishedAt,
    this.duration,
    this.viewCount,
    this.subscriberCount,
    this.isVerifiedTeacher = true,
    this.studyCategory = 'General',
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$id';
  String get channelUrl => channelId.isNotEmpty
      ? 'https://www.youtube.com/channel/$channelId'
      : 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(channelTitle)}';

  String get formattedPublishedDate {
    if (publishedAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(publishedAt!);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'channelTitle': channelTitle,
        'channelId': channelId,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt?.toIso8601String(),
        'duration': duration,
        'viewCount': viewCount,
        'subscriberCount': subscriberCount,
        'isVerifiedTeacher': isVerifiedTeacher,
        'studyCategory': studyCategory,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Video',
      description: json['description'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? 'Unknown Channel',
      channelId: json['channelId'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      duration: json['duration'] as String?,
      viewCount: json['viewCount'] as String?,
      subscriberCount: json['subscriberCount'] as String?,
      isVerifiedTeacher: json['isVerifiedTeacher'] as bool? ?? true,
      studyCategory: json['studyCategory'] as String? ?? 'General',
    );
  }
}

/// Represents a student's bookmarked / saved class with study progress and notes
class SavedClass {
  final String id; // Typically the videoId
  final String videoId;
  String title;
  String channelTitle;
  String channelId;
  String thumbnailUrl;
  String? duration;
  String? viewCount;
  DateTime? publishedAt;
  String studyCategory;
  String? linkedSubjectId;
  String? linkedSubjectName;
  String? linkedChapterId;
  String? linkedChapterTitle;
  ClassStatus status;
  String notes;
  final DateTime savedAt;
  DateTime updatedAt;

  SavedClass({
    required this.id,
    required this.videoId,
    required this.title,
    required this.channelTitle,
    this.channelId = '',
    required this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.publishedAt,
    this.studyCategory = 'General',
    this.linkedSubjectId,
    this.linkedSubjectName,
    this.linkedChapterId,
    this.linkedChapterTitle,
    this.status = ClassStatus.notStarted,
    this.notes = '',
    DateTime? savedAt,
    DateTime? updatedAt,
  })  : savedAt = savedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';

  VideoItem toVideoItem() {
    return VideoItem(
      id: videoId,
      title: title,
      channelTitle: channelTitle,
      channelId: channelId,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      viewCount: viewCount,
      publishedAt: publishedAt,
      studyCategory: studyCategory,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'channelTitle': channelTitle,
        'channelId': channelId,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'viewCount': viewCount,
        'publishedAt': publishedAt?.toIso8601String(),
        'studyCategory': studyCategory,
        'linkedSubjectId': linkedSubjectId,
        'linkedSubjectName': linkedSubjectName,
        'linkedChapterId': linkedChapterId,
        'linkedChapterTitle': linkedChapterTitle,
        'status': status.name,
        'notes': notes,
        'savedAt': savedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SavedClass.fromJson(Map<String, dynamic> json) {
    ClassStatus stat = ClassStatus.notStarted;
    if (json.containsKey('status')) {
      final sStr = json['status'] as String?;
      stat = ClassStatus.values.firstWhere(
        (e) => e.name == sStr,
        orElse: () => ClassStatus.notStarted,
      );
    }

    return SavedClass(
      id: json['id'] as String? ?? (json['videoId'] as String? ?? ''),
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Class',
      channelTitle: json['channelTitle'] as String? ?? 'Unknown Channel',
      channelId: json['channelId'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: json['duration'] as String?,
      viewCount: json['viewCount'] as String?,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      studyCategory: json['studyCategory'] as String? ?? 'General',
      linkedSubjectId: json['linkedSubjectId'] as String?,
      linkedSubjectName: json['linkedSubjectName'] as String?,
      linkedChapterId: json['linkedChapterId'] as String?,
      linkedChapterTitle: json['linkedChapterTitle'] as String?,
      status: stat,
      notes: json['notes'] as String? ?? '',
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory SavedClass.fromVideoItem(
    VideoItem item, {
    String? subjectId,
    String? subjectName,
    String? chapterId,
    String? chapterTitle,
    ClassStatus status = ClassStatus.notStarted,
    String notes = '',
  }) {
    return SavedClass(
      id: item.id,
      videoId: item.id,
      title: item.title,
      channelTitle: item.channelTitle,
      channelId: item.channelId,
      thumbnailUrl: item.thumbnailUrl,
      duration: item.duration,
      viewCount: item.viewCount,
      publishedAt: item.publishedAt,
      studyCategory: item.studyCategory,
      linkedSubjectId: subjectId,
      linkedSubjectName: subjectName,
      linkedChapterId: chapterId,
      linkedChapterTitle: chapterTitle,
      status: status,
      notes: notes,
    );
  }
}

/// Channel / Teacher filter item aggregated dynamically from search results
class TeacherFilterItem {
  final String name;
  final String channelId;
  final int videoCount;

  const TeacherFilterItem({
    required this.name,
    this.channelId = '',
    required this.videoCount,
  });
}

/// Represents a candidate YouTube channel for an educator / teacher
class ChannelCandidate {
  final String channelId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String? subscriberCount;
  final bool isVerified;
  final String? customUrl;

  const ChannelCandidate({
    required this.channelId,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    this.subscriberCount,
    this.isVerified = true,
    this.customUrl,
  });

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'subscriberCount': subscriberCount,
        'isVerified': isVerified,
        'customUrl': customUrl,
      };

  factory ChannelCandidate.fromJson(Map<String, dynamic> json) {
    return ChannelCandidate(
      channelId: json['channelId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      subscriberCount: json['subscriberCount'] as String?,
      isVerified: json['isVerified'] as bool? ?? true,
      customUrl: json['customUrl'] as String?,
    );
  }
}

/// Represents the parsed intent of a user's search query,
/// cleanly separating explicit teacher/channel and subject/topic terms.
class ParsedTeacherSubjectQuery {
  final String rawQuery;
  final String? teacherTerm;
  final String? subjectTerm;
  final bool hasExplicitTeacher;
  final String? lockedChannelId;
  final String? lockedChannelTitle;

  const ParsedTeacherSubjectQuery({
    required this.rawQuery,
    this.teacherTerm,
    this.subjectTerm,
    this.hasExplicitTeacher = false,
    this.lockedChannelId,
    this.lockedChannelTitle,
  });

  bool get isTeacherAndSubject =>
      teacherTerm != null &&
      teacherTerm!.trim().isNotEmpty &&
      subjectTerm != null &&
      subjectTerm!.trim().isNotEmpty;

  bool get isTeacherOnly =>
      teacherTerm != null &&
      teacherTerm!.trim().isNotEmpty &&
      (subjectTerm == null || subjectTerm!.trim().isEmpty);

  bool get isSubjectOnly => !hasExplicitTeacher;

  @override
  String toString() =>
      'ParsedTeacherSubjectQuery(raw: "$rawQuery", teacher: "$teacherTerm", subject: "$subjectTerm", explicit: $hasExplicitTeacher, channelId: "$lockedChannelId")';
}
