import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import 'storage_service.dart';

/// Encapsulates search results, teacher channels, and strict query metadata
class SearchResult {
  final List<VideoItem> items;
  final String? nextPageToken;
  final int totalResults;
  final bool isDemoMode;
  final String? errorMessage;
  final List<TeacherFilterItem> availableTeachers;
  final List<ChannelCandidate> channelCandidates;
  final bool isChannelAmbiguous;
  final String? resolvedChannelTitle;
  final String? resolvedChannelId;
  final String? parsedTeacher;
  final String? parsedSubject;
  final bool noMatchingForTeacherSubject;

  const SearchResult({
    required this.items,
    this.nextPageToken,
    this.totalResults = 0,
    this.isDemoMode = false,
    this.errorMessage,
    this.availableTeachers = const [],
    this.channelCandidates = const [],
    this.isChannelAmbiguous = false,
    this.resolvedChannelTitle,
    this.resolvedChannelId,
    this.parsedTeacher,
    this.parsedSubject,
    this.noMatchingForTeacherSubject = false,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
  bool get isEmpty => items.isEmpty;
}

class CachedSearchResult {
  final SearchResult result;
  final DateTime cachedAt;

  CachedSearchResult(this.result) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 15);
}

class YouTubeService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  // In-memory query cache to reduce repeated requests and protect API quota
  static final Map<String, CachedSearchResult> _cache = {};

  // Channel lookup cache (30-minute expiration)
  static final Map<String,
          ({List<ChannelCandidate> candidates, DateTime cachedAt})>
      _channelCache = {};

  /// Comprehensive directory of known educators across all 6 study categories
  static const List<String> _knownEducators = [
    // CA & Professional Exams
    'CA Rishabh Jain', 'Rishabh Jain',
    'CA Shruti Kedia', 'Shruti Kedia',
    'CA Mayank Agarwal', 'Mayank Agarwal',
    'CA Amit Tated', 'Amit Tated',
    'CA Aditya Sharma', 'Aditya Sharma',
    'CA Ankita Patni', 'Ankita Patni',
    'CA Vishal Bhattad', 'Vishal Bhattad',
    'CA Shubham Singhal', 'Shubham Singhal',
    'CA Bhanwar Borana', 'Bhanwar Borana',
    'CA Pratik Jagati', 'Pratik Jagati',
    'CA Atul Agarwal', 'Atul Agarwal',
    'CA Pravin Khatod', 'Pravin Khatod',
    'CA Darshan Khare', 'Darshan Khare',
    'CA Vijay Sarda', 'Vijay Sarda',
    'CA Swapnil Patni', 'Swapnil Patni',
    'CA Kapil Goyal', 'Kapil Goyal',
    'CA Abhishek Bansal', 'Abhishek Bansal',
    'CA Neeraj Arora', 'Neeraj Arora',

    // Competitive Exams (JEE / NEET / UPSC / SSC)
    'Physics Wallah', 'Alakh Pandey',
    'Mohit Tyagi',
    'Dr. Neha Taneja', 'Neha Taneja',
    'StudyIQ IAS', 'StudyIQ',
    'Unacademy JEE', 'Unacademy',
    'Aman Dhattarwal', 'Apni Kaksha',
    'Ashish Arora', 'Physics Galaxy',
    'Vikas Divyakirti', 'Drishti IAS',
    'Khan Sir', 'Khan GS Research',

    // School
    'Dear Sir',
    'Vedantu 9&10', 'Vedantu',
    'Magnet Brains',
    'Shobhit Nirwan',
    'Prashant Kirad',
    'Khan Academy',

    // College / University & Engineering
    'Abdul Bari',
    'Gate Smashers', 'Varun Singla',
    '3Blue1Brown', 'Grant Sanderson',
    'NPTEL',
    'Saurabh Shukla',
    'Jenny\'s Lectures',
    'Love Babbar',
    'Striver', 'take U forward',

    // Certification & Self-Study
    'freeCodeCamp',
    'Programming with Mosh', 'Mosh Hamedani',
    'TechWorld with Nana', 'Nana Janashia',
    'Ali Abdaal',
    'Corey Schafer',
    'Hitesh Choudhary', 'Chai aur Code',
    'CodeWithHarry',
    'Traversy Media',
    'Web Dev Simplified',
    'Fireship',
  ];

  /// Get active API key (from StorageService, with fallback to dart-define)
  static Future<String> getApiKey() async {
    final customKey = await StorageService.loadYouTubeApiKey();
    if (customKey != null && customKey.trim().isNotEmpty) {
      return customKey.trim();
    }
    // Compile-time environment variable fallback
    return const String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
  }

  /// Set custom API key in storage
  static Future<void> setApiKey(String key) async {
    await StorageService.saveYouTubeApiKey(key.trim());
    _cache.clear(); // Invalidate cache on key switch
    _channelCache.clear();
  }

  /// Test whether an API key works by making a tiny 1-result query
  static Future<({bool isValid, String message})> testApiKey(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      return (isValid: false, message: 'API key cannot be empty');
    }
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'type': 'video',
        'maxResults': '1',
        'q': 'education',
        'key': cleanKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return (isValid: true, message: 'Valid API key! Connected to YouTube.');
      } else if (res.statusCode == 403) {
        final body = res.body.toLowerCase();
        if (body.contains('quotaexceeded')) {
          return (
            isValid: false,
            message: 'Key valid, but daily quota (10,000 units) is exceeded.'
          );
        }
        return (
          isValid: false,
          message:
              'Access denied (HTTP 403). Ensure YouTube Data API v3 is enabled.'
        );
      } else if (res.statusCode == 400) {
        return (isValid: false, message: 'Invalid API key format.');
      } else {
        return (
          isValid: false,
          message: 'YouTube returned status ${res.statusCode}'
        );
      }
    } catch (e) {
      return (isValid: false, message: 'Network error testing API key: $e');
    }
  }

  /// Check whether live API mode is configured
  static Future<bool> isLiveApiConfigured() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }

  /// Extracts the YouTube video ID if [input] is a valid YouTube URL.
  /// Supports:
  /// - youtube.com/watch?v=ID (including m.youtube.com, query params before/after v)
  /// - youtu.be/ID (including query params like ?si=...)
  /// - youtube.com/live/ID
  /// - youtube.com/shorts/ID
  /// - youtube.com/embed/ID
  /// Returns null if the input is not a recognized YouTube video URL.
  static String? extractVideoId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // Fast filter: must contain youtube.com or youtu.be
    if (!clean.contains('youtube.com') && !clean.contains('youtu.be')) {
      return null;
    }

    try {
      final uri = Uri.tryParse(
          clean.startsWith('http://') || clean.startsWith('https://')
              ? clean
              : 'https://$clean');

      if (uri != null) {
        final host = uri.host.toLowerCase();
        final isYouTubeHost = host == 'youtube.com' ||
            host == 'www.youtube.com' ||
            host == 'm.youtube.com' ||
            host == 'music.youtube.com';

        // 1. youtu.be/ID
        if (host == 'youtu.be' || host == 'www.youtu.be') {
          if (uri.pathSegments.isNotEmpty) {
            final id = uri.pathSegments.first;
            if (_isValidVideoId(id)) return id;
          }
        }

        // 2. youtube.com/watch?v=ID
        if (isYouTubeHost && (uri.path == '/watch' || uri.path == '/watch/')) {
          final v = uri.queryParameters['v'];
          if (v != null && _isValidVideoId(v)) return v;
        }

        // 3. youtube.com/shorts/ID
        if (isYouTubeHost &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'shorts') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            if (_isValidVideoId(id)) return id;
          }
        }

        // 4. youtube.com/live/ID
        if (isYouTubeHost &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'live') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            if (_isValidVideoId(id)) return id;
          }
        }

        // 5. youtube.com/embed/ID
        if (isYouTubeHost &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'embed') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            if (_isValidVideoId(id)) return id;
          }
        }
      }

      // Regex fallbacks for non-standard formats or unusual query parameter sequences
      final watchMatch = RegExp(
        r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (watchMatch != null) {
        final id = watchMatch.group(1);
        if (id != null && _isValidVideoId(id)) return id;
      }

      final shortsMatch = RegExp(
        r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (shortsMatch != null) {
        final id = shortsMatch.group(1);
        if (id != null && _isValidVideoId(id)) return id;
      }

      final liveMatch = RegExp(
        r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (liveMatch != null) {
        final id = liveMatch.group(1);
        if (id != null && _isValidVideoId(id)) return id;
      }
    } catch (_) {}

    return null;
  }

  static bool _isValidVideoId(String id) {
    if (id.isEmpty) return false;
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return true;
    if (id.startsWith('demo_')) return true;
    return false;
  }

  /// Fetches video metadata for a specific YouTube video ID.
  /// Strategy:
  /// 1. Check local demo catalog first (supports demo IDs and offline testing).
  /// 2. If API key is available, query official YouTube Data API v3 (`videos.list`).
  /// 3. If no API key or API call fails / quota exceeded, fallback to official
  ///    free YouTube oEmbed API (`https://www.youtube.com/oembed?url=...`).
  /// 4. Gracefully returns null if the video does not exist, is private, or removed.
  static Future<VideoItem?> fetchVideoById(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    // Check demo catalog first
    final demoMatch = _demoCatalog.where((v) => v.id == cleanId).firstOrNull;
    if (demoMatch != null) {
      return demoMatch;
    }

    final apiKey = await getApiKey();

    // Tier 1: YouTube Data API v3
    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
          'part': 'snippet,contentDetails,statistics',
          'id': cleanId,
          'key': apiKey,
        });

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = (data['items'] as List? ?? []);
          if (items.isNotEmpty) {
            final item = items.first as Map<String, dynamic>;
            final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
            final contentDetails =
                item['contentDetails'] as Map<String, dynamic>? ?? {};
            final statistics =
                item['statistics'] as Map<String, dynamic>? ?? {};

            final title = snippet['title'] as String? ?? 'YouTube Video';
            final desc = snippet['description'] as String? ?? '';
            final channelTitle =
                snippet['channelTitle'] as String? ?? 'Educational Channel';
            final channelId = snippet['channelId'] as String? ?? '';
            final publishedAt =
                DateTime.tryParse(snippet['publishedAt'] as String? ?? '');

            final thumbnails =
                snippet['thumbnails'] as Map<String, dynamic>? ?? {};
            final thumb = thumbnails['maxres']?['url'] ??
                thumbnails['high']?['url'] ??
                thumbnails['medium']?['url'] ??
                thumbnails['default']?['url'] ??
                'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg';

            String? durationStr;
            if (contentDetails.containsKey('duration')) {
              durationStr = formatIsoDuration(
                  contentDetails['duration'] as String? ?? '');
            }

            String? viewStr;
            if (statistics.containsKey('viewCount')) {
              final cnt =
                  int.tryParse(statistics['viewCount'] as String? ?? '');
              if (cnt != null) viewStr = formatViewCount(cnt);
            }

            return VideoItem(
              id: cleanId,
              title: _cleanHtmlEntities(title),
              description: desc,
              channelTitle: _cleanHtmlEntities(channelTitle),
              channelId: channelId,
              thumbnailUrl: thumb,
              publishedAt: publishedAt,
              duration: durationStr,
              viewCount: viewStr,
              isVerifiedTeacher: true,
              studyCategory: 'General',
            );
          }
        }
      } catch (e) {
        debugPrint('YouTube Data API fetchVideoById error: $e');
      }
    }

    // Tier 2: Free official YouTube oEmbed API fallback
    // (Works with zero API keys and no quota usage)
    try {
      final oEmbedUri =
          Uri.parse('https://www.youtube.com/oembed').replace(queryParameters: {
        'url': 'https://www.youtube.com/watch?v=$cleanId',
        'format': 'json',
      });

      final response =
          await http.get(oEmbedUri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String? ?? 'YouTube Video';
        final authorName = data['author_name'] as String? ?? 'YouTube Creator';
        final authorUrl = data['author_url'] as String? ?? '';
        final thumb = data['thumbnail_url'] as String? ??
            'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg';

        String channelId = '';
        if (authorUrl.contains('/channel/')) {
          channelId = authorUrl.split('/channel/').last.split('?').first;
        }

        return VideoItem(
          id: cleanId,
          title: _cleanHtmlEntities(title),
          description: 'Imported via direct YouTube link.',
          channelTitle: _cleanHtmlEntities(authorName),
          channelId: channelId,
          thumbnailUrl: thumb,
          publishedAt: DateTime.now(),
          duration: null,
          viewCount: null,
          isVerifiedTeacher: true,
          studyCategory: 'General',
        );
      } else if (response.statusCode == 404 || response.statusCode == 401) {
        // Video does not exist, is private, or restricted
        return null;
      }
    } catch (e) {
      debugPrint('YouTube oEmbed fetch error: $e');
    }

    // Tier 3: Partial substring match in demo catalog for test IDs
    final fallbackDemo =
        _demoCatalog.where((v) => v.id.contains(cleanId)).firstOrNull;
    if (fallbackDemo != null) return fallbackDemo;

    return null;
  }

  /// Parse search input into explicit teacher and subject/topic components
  static ParsedTeacherSubjectQuery parseTeacherAndSubject(String rawQuery) {
    final clean = rawQuery.trim();
    if (clean.isEmpty) {
      return const ParsedTeacherSubjectQuery(rawQuery: '');
    }

    // Pattern 1: "Subject by Teacher" or "Subject from Teacher"
    final byMatch =
        RegExp(r'^(.*?)\s+(?:by|from)\s+(.+)$', caseSensitive: false)
            .firstMatch(clean);
    if (byMatch != null) {
      final subjectPart = byMatch.group(1)!.trim();
      final teacherPart = byMatch.group(2)!.trim();
      if (teacherPart.isNotEmpty) {
        return ParsedTeacherSubjectQuery(
          rawQuery: clean,
          teacherTerm: teacherPart,
          subjectTerm: subjectPart.isEmpty ? null : subjectPart,
          hasExplicitTeacher: true,
        );
      }
    }

    // Pattern 2: "Teacher - Subject" or "Teacher : Subject"
    final sepMatch = RegExp(r'^(.+?)\s*[-:]\s*(.+)$').firstMatch(clean);
    if (sepMatch != null) {
      final p1 = sepMatch.group(1)!.trim();
      final p2 = sepMatch.group(2)!.trim();
      // Check if p1 starts with honorifics or matches known educators
      if (_hasHonorific(p1) || _isKnownEducator(p1)) {
        return ParsedTeacherSubjectQuery(
          rawQuery: clean,
          teacherTerm: p1,
          subjectTerm: p2.isEmpty ? null : p2,
          hasExplicitTeacher: true,
        );
      } else if (_hasHonorific(p2) || _isKnownEducator(p2)) {
        return ParsedTeacherSubjectQuery(
          rawQuery: clean,
          teacherTerm: p2,
          subjectTerm: p1.isEmpty ? null : p1,
          hasExplicitTeacher: true,
        );
      }
    }

    // Pattern 3: Honorific prefix (e.g. "CA Rishabh Jain Audit", "Dr. Neha Taneja Biology")
    final honorificMatch = RegExp(
      r'^(CA|CS|CMA|Dr\.?|Prof\.?|Er\.?|Sir)\s+([A-Za-z]+(?:\s+[A-Za-z]+)?)\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (honorificMatch != null) {
      final prefix = honorificMatch.group(1)!.trim();
      final name = honorificMatch.group(2)!.trim();
      final remainder = honorificMatch.group(3)!.trim();
      return ParsedTeacherSubjectQuery(
        rawQuery: clean,
        teacherTerm: '$prefix $name',
        subjectTerm: remainder.isEmpty ? null : remainder,
        hasExplicitTeacher: true,
      );
    }

    // Pattern 4: Check against known educators list (sorted longest first to prevent prefix issues)
    final sortedEducators = List<String>.from(_knownEducators)
      ..sort((a, b) => b.length.compareTo(a.length));

    final lowerClean = clean.toLowerCase();
    for (final educator in sortedEducators) {
      final lowerEd = educator.toLowerCase();
      if (lowerClean.contains(lowerEd)) {
        // Extract remainder as subject
        final remainder = clean
            .replaceAll(
                RegExp(RegExp.escape(educator), caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        return ParsedTeacherSubjectQuery(
          rawQuery: clean,
          teacherTerm: educator,
          subjectTerm: remainder.isEmpty ? null : remainder,
          hasExplicitTeacher: true,
        );
      }
    }

    // Default: Open search across all teachers
    return ParsedTeacherSubjectQuery(
      rawQuery: clean,
      teacherTerm: null,
      subjectTerm: clean,
      hasExplicitTeacher: false,
    );
  }

  static bool _hasHonorific(String text) {
    return RegExp(r'^(CA|CS|CMA|Dr\.?|Prof\.?|Er\.?|Sir)\s+',
            caseSensitive: false)
        .hasMatch(text.trim());
  }

  static bool _isKnownEducator(String text) {
    final lower = text.trim().toLowerCase();
    return _knownEducators.any((e) => e.toLowerCase() == lower);
  }

  /// Resolve candidate YouTube channels for a teacher name
  static Future<List<ChannelCandidate>> resolveChannels({
    required String apiKey,
    required String teacherQuery,
  }) async {
    final cleanTeacher = teacherQuery.trim();
    if (cleanTeacher.isEmpty) return const [];

    final cacheKey = cleanTeacher.toLowerCase();
    if (_channelCache.containsKey(cacheKey)) {
      final entry = _channelCache[cacheKey]!;
      if (DateTime.now().difference(entry.cachedAt) <
          const Duration(minutes: 30)) {
        return entry.candidates;
      }
    }

    if (apiKey.isEmpty) {
      // Demo Mode channel resolution
      final matches = _resolveDemoChannels(cleanTeacher);
      _channelCache[cacheKey] = (candidates: matches, cachedAt: DateTime.now());
      return matches;
    }

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'type': 'channel',
        'q': cleanTeacher,
        'maxResults': '5',
        'key': apiKey,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List? ?? []);
      final channelIds = <String>[];
      final List<Map<String, dynamic>> rawSnippets = [];

      for (final item in items) {
        final idObj = item['id'];
        final chId = idObj is Map ? idObj['channelId'] as String? ?? '' : '';
        if (chId.isNotEmpty) {
          channelIds.add(chId);
          rawSnippets.add({
            'channelId': chId,
            'snippet': item['snippet'] ?? {},
          });
        }
      }

      if (channelIds.isEmpty) return const [];

      // Batch fetch channel statistics to get subscriber counts
      final statsMap = await _fetchChannelStats(apiKey, channelIds);

      final List<ChannelCandidate> result = [];
      for (final raw in rawSnippets) {
        final chId = raw['channelId'] as String;
        final snip = raw['snippet'] as Map<String, dynamic>;
        final title = snip['title'] as String? ?? 'Educator Channel';
        final desc = snip['description'] as String? ?? '';
        final thumbs = snip['thumbnails'] as Map<String, dynamic>? ?? {};
        final thumb = thumbs['high']?['url'] ??
            thumbs['medium']?['url'] ??
            thumbs['default']?['url'] ??
            '';
        final subs = statsMap[chId];

        result.add(ChannelCandidate(
          channelId: chId,
          title: _cleanHtmlEntities(title),
          description: desc,
          thumbnailUrl: thumb,
          subscriberCount: subs != null ? formatSubscriberCount(subs) : null,
          isVerified: true,
        ));
      }

      _channelCache[cacheKey] = (candidates: result, cachedAt: DateTime.now());
      return result;
    } catch (e) {
      debugPrint('Channel resolution error: $e');
      return const [];
    }
  }

  static Future<Map<String, int>> _fetchChannelStats(
      String apiKey, List<String> channelIds) async {
    final Map<String, int> map = {};
    try {
      final uri = Uri.parse('$_baseUrl/channels').replace(queryParameters: {
        'part': 'statistics',
        'id': channelIds.join(','),
        'key': apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        for (final item in (data['items'] as List? ?? [])) {
          final id = item['id'] as String? ?? '';
          final stats = item['statistics'] as Map<String, dynamic>?;
          if (id.isNotEmpty && stats != null) {
            final subs =
                int.tryParse(stats['subscriberCount'] as String? ?? '');
            if (subs != null) map[id] = subs;
          }
        }
      }
    } catch (_) {}
    return map;
  }

  static List<ChannelCandidate> _resolveDemoChannels(String teacherQuery) {
    final lower = teacherQuery.toLowerCase();
    final Map<String, ChannelCandidate> seen = {};

    for (final video in _demoCatalog) {
      if (video.channelTitle.toLowerCase().contains(lower) ||
          video.title.toLowerCase().contains(lower)) {
        if (!seen.containsKey(video.channelId)) {
          seen[video.channelId] = ChannelCandidate(
            channelId: video.channelId,
            title: video.channelTitle,
            description:
                'Official Demo Educator Channel for ${video.studyCategory}',
            thumbnailUrl: video.thumbnailUrl,
            subscriberCount: video.subscriberCount,
            isVerified: true,
          );
        }
      }
    }
    return seen.values.toList();
  }

  /// Parse ISO 8601 duration string into formatted readable duration
  static String formatIsoDuration(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final match = RegExp(
              r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
          .firstMatch(isoString);
      if (match == null) return '';

      final hours = int.tryParse(match.group(4) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(5) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(6) ?? '') ?? 0;

      if (hours > 0) {
        return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

  /// Format raw view count into compact friendly string
  static String formatViewCount(int count) {
    if (count >= 1000000) {
      final m = (count / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M views';
    } else if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}K views';
    } else {
      return '$count view${count == 1 ? '' : 's'}';
    }
  }

  /// Format subscriber count into compact friendly string
  static String formatSubscriberCount(int count) {
    if (count >= 1000000) {
      final m = (count / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M subscribers';
    } else if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}K subscribers';
    } else {
      return '$count subscribers';
    }
  }

  /// Extract distinct teachers / channels from a list of video items
  static List<TeacherFilterItem> extractTeachers(List<VideoItem> items) {
    final Map<String, int> counts = {};
    final Map<String, String> channelIds = {};

    for (final item in items) {
      final name = item.channelTitle.trim();
      if (name.isNotEmpty) {
        counts[name] = (counts[name] ?? 0) + 1;
        if (item.channelId.isNotEmpty && !channelIds.containsKey(name)) {
          channelIds[name] = item.channelId;
        }
      }
    }

    final list = counts.entries.map((entry) {
      return TeacherFilterItem(
        name: entry.key,
        channelId: channelIds[entry.key] ?? '',
        videoCount: entry.value,
      );
    }).toList();

    list.sort((a, b) => b.videoCount.compareTo(a.videoCount));
    return list;
  }

  /// Main search method supporting strict teacher + subject resolution, channel locking,
  /// pagination, caching, and transparent demo fallback.
  static Future<SearchResult> searchClasses({
    required String query,
    String? category,
    ClassTypeFilter classType = ClassTypeFilter.all,
    ClassDurationFilter duration = ClassDurationFilter.any,
    ClassSortOrder sortOrder = ClassSortOrder.relevance,
    String? selectedTeacher,
    String? lockedChannelId,
    String? lockedChannelTitle,
    String? pageToken,
    bool requireChannelSelectionIfAmbiguous = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const SearchResult(items: [], totalResults: 0);
    }

    // 1. Parse search query into teacher and subject
    final parsed = parseTeacherAndSubject(cleanQuery);

    final effectiveTeacher =
        selectedTeacher ?? lockedChannelTitle ?? parsed.teacherTerm;
    final effectiveSubject =
        parsed.subjectTerm ?? (parsed.hasExplicitTeacher ? '' : cleanQuery);

    // Build cache key
    final cacheKey =
        '$cleanQuery|${category ?? ''}|${classType.name}|${duration.name}|${sortOrder.name}|${effectiveTeacher ?? ''}|${lockedChannelId ?? ''}|${pageToken ?? ''}';

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.result;
      }
      _cache.remove(cacheKey);
    }

    final apiKey = await getApiKey();

    SearchResult result;
    if (apiKey.isEmpty) {
      // Demo Mode: strictly enforce teacher and subject rules on the demo catalog
      result = _searchDemoCatalogStrict(
        rawQuery: cleanQuery,
        parsedTeacher: effectiveTeacher,
        parsedSubject: effectiveSubject,
        category: category,
        classType: classType,
        duration: duration,
        sortOrder: sortOrder,
        lockedChannelId: lockedChannelId,
        pageToken: pageToken,
      );
    } else {
      // Live YouTube Data API v3 Mode
      result = await _searchLiveYouTubeStrict(
        apiKey: apiKey,
        rawQuery: cleanQuery,
        parsedTeacher: effectiveTeacher,
        parsedSubject: effectiveSubject,
        classType: classType,
        duration: duration,
        sortOrder: sortOrder,
        lockedChannelId: lockedChannelId,
        lockedChannelTitle: lockedChannelTitle,
        pageToken: pageToken,
        requireChannelSelectionIfAmbiguous: requireChannelSelectionIfAmbiguous,
      );
    }

    // Cache valid result
    if (!result.hasError) {
      _cache[cacheKey] = CachedSearchResult(result);
    }

    return result;
  }

  /// Live YouTube Search with strict channel resolution and subject validation
  static Future<SearchResult> _searchLiveYouTubeStrict({
    required String apiKey,
    required String rawQuery,
    required String? parsedTeacher,
    required String? parsedSubject,
    required ClassTypeFilter classType,
    required ClassDurationFilter duration,
    required ClassSortOrder sortOrder,
    String? lockedChannelId,
    String? lockedChannelTitle,
    String? pageToken,
    bool requireChannelSelectionIfAmbiguous = false,
  }) async {
    try {
      String? targetChannelId = lockedChannelId;
      String? targetChannelTitle = lockedChannelTitle;
      List<ChannelCandidate> candidates = [];

      // Step A: If teacher is specified but channelId is not yet locked, resolve the channel
      if (parsedTeacher != null &&
          parsedTeacher.isNotEmpty &&
          targetChannelId == null) {
        candidates = await resolveChannels(
          apiKey: apiKey,
          teacherQuery: parsedTeacher,
        );

        if (candidates.length > 1 && requireChannelSelectionIfAmbiguous) {
          // Check if top candidate is an overwhelming exact match
          final top = candidates.first;
          final isExact =
              top.title.toLowerCase().contains(parsedTeacher.toLowerCase());
          if (!isExact) {
            return SearchResult(
              items: const [],
              channelCandidates: candidates,
              isChannelAmbiguous: true,
              parsedTeacher: parsedTeacher,
              parsedSubject: parsedSubject,
            );
          }
        }

        if (candidates.isNotEmpty) {
          targetChannelId = candidates.first.channelId;
          targetChannelTitle = candidates.first.title;
        }
      }

      // Step B: Formulate query
      String effectiveQuery = parsedSubject?.trim() ?? '';
      if (effectiveQuery.isEmpty && targetChannelId == null) {
        effectiveQuery = rawQuery;
      }
      if (classType != ClassTypeFilter.all) {
        effectiveQuery = effectiveQuery.isEmpty
            ? classType.searchKeyword
            : '$effectiveQuery ${classType.searchKeyword}';
      }

      final queryParams = <String, String>{
        'part': 'snippet',
        'type': 'video',
        'maxResults': '25',
        'key': apiKey,
        'order': sortOrder.apiValue,
      };

      if (effectiveQuery.isNotEmpty) {
        queryParams['q'] = effectiveQuery;
      }

      // Strict channel filtering via channelId
      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        queryParams['channelId'] = targetChannelId;
      }

      if (duration != ClassDurationFilter.any) {
        queryParams['videoDuration'] = duration.apiValue;
      }
      if (pageToken != null && pageToken.isNotEmpty) {
        queryParams['pageToken'] = pageToken;
      }

      final uri =
          Uri.parse('$_baseUrl/search').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final itemsJson = (data['items'] as List? ?? []);
        final nextPageToken = data['nextPageToken'] as String?;
        final pageInfo = data['pageInfo'] as Map<String, dynamic>?;
        final totalResults =
            (pageInfo?['totalResults'] as num?)?.toInt() ?? itemsJson.length;

        final videoIds = <String>[];
        final List<Map<String, dynamic>> rawItems = [];

        for (final item in itemsJson) {
          final idObj = item['id'];
          String videoId = '';
          if (idObj is Map) {
            videoId = idObj['videoId'] as String? ?? '';
          } else if (idObj is String) {
            videoId = idObj;
          }

          if (videoId.isNotEmpty) {
            videoIds.add(videoId);
            rawItems.add({
              'videoId': videoId,
              'snippet': item['snippet'] ?? {},
            });
          }
        }

        final detailsMap = await _fetchVideoDetails(apiKey, videoIds);
        final List<VideoItem> videoList = [];

        for (final raw in rawItems) {
          final vidId = raw['videoId'] as String;
          final snippet = raw['snippet'] as Map<String, dynamic>;
          final details = detailsMap[vidId];

          final thumbnails =
              snippet['thumbnails'] as Map<String, dynamic>? ?? {};
          final highThumb = thumbnails['high']?['url'] ??
              thumbnails['medium']?['url'] ??
              thumbnails['default']?['url'] ??
              'https://i.ytimg.com/vi/$vidId/hqdefault.jpg';

          final chTitle =
              snippet['channelTitle'] as String? ?? 'Educational Channel';
          final chId = snippet['channelId'] as String? ?? '';
          final title = snippet['title'] as String? ?? 'Untitled Class';
          final description = snippet['description'] as String? ?? '';
          final publishedAt =
              DateTime.tryParse(snippet['publishedAt'] as String? ?? '');

          videoList.add(VideoItem(
            id: vidId,
            title: _cleanHtmlEntities(title),
            description: description,
            channelTitle: chTitle,
            channelId: chId,
            thumbnailUrl: highThumb,
            publishedAt: publishedAt,
            duration: details?['duration'],
            viewCount: details?['viewCount'],
            isVerifiedTeacher: true,
          ));
        }

        // Step C: Strict Subject Relevance Validation when a teacher was explicitly searched
        if (targetChannelId != null &&
            parsedSubject != null &&
            parsedSubject.trim().isNotEmpty) {
          final subjectTokens = parsedSubject
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((t) => t.isNotEmpty)
              .toList();

          final matchedVideos = videoList.where((v) {
            final hay = '${v.title} ${v.description}'.toLowerCase();
            return subjectTokens.any((token) => hay.contains(token));
          }).toList();

          if (matchedVideos.isEmpty) {
            // Teacher channel has 0 videos covering this subject!
            // Do NOT fill with unrelated videos. Show strict empty state.
            return SearchResult(
              items: const [],
              totalResults: 0,
              isDemoMode: false,
              resolvedChannelTitle: targetChannelTitle ?? parsedTeacher,
              resolvedChannelId: targetChannelId,
              parsedTeacher: targetChannelTitle ?? parsedTeacher,
              parsedSubject: parsedSubject,
              noMatchingForTeacherSubject: true,
            );
          }

          final teachers = extractTeachers(matchedVideos);
          return SearchResult(
            items: matchedVideos,
            nextPageToken: nextPageToken,
            totalResults: matchedVideos.length,
            isDemoMode: false,
            availableTeachers: teachers,
            resolvedChannelTitle: targetChannelTitle ?? parsedTeacher,
            resolvedChannelId: targetChannelId,
            parsedTeacher: targetChannelTitle ?? parsedTeacher,
            parsedSubject: parsedSubject,
          );
        }

        final teachers = extractTeachers(videoList);
        return SearchResult(
          items: videoList,
          nextPageToken: nextPageToken,
          totalResults: totalResults,
          isDemoMode: false,
          availableTeachers: teachers,
          resolvedChannelTitle: targetChannelTitle,
          resolvedChannelId: targetChannelId,
          parsedTeacher: parsedTeacher,
          parsedSubject: parsedSubject,
        );
      } else if (response.statusCode == 403) {
        final body = response.body.toLowerCase();
        if (body.contains('quotaexceeded')) {
          return const SearchResult(
            items: [],
            isDemoMode: false,
            errorMessage:
                'YouTube API daily quota (10,000 units) exceeded for this key. Please switch to Demo Mode or configure a different API key in Settings.',
          );
        } else {
          return const SearchResult(
            items: [],
            isDemoMode: false,
            errorMessage:
                'Access denied by YouTube API (HTTP 403). Please verify that YouTube Data API v3 is enabled in your Google Cloud project.',
          );
        }
      } else if (response.statusCode == 400) {
        return const SearchResult(
          items: [],
          isDemoMode: false,
          errorMessage: 'Invalid YouTube API key or parameters.',
        );
      } else {
        return SearchResult(
          items: [],
          isDemoMode: false,
          errorMessage:
              'YouTube API returned HTTP status ${response.statusCode}',
        );
      }
    } on TimeoutException {
      return const SearchResult(
        items: [],
        errorMessage:
            'Network timeout connecting to YouTube. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('YouTube API exception: $e');
      return SearchResult(
        items: [],
        errorMessage: 'Unable to reach YouTube API: $e',
      );
    }
  }

  /// Batch fetch video duration and viewCount for up to 50 video IDs
  static Future<Map<String, Map<String, String>>> _fetchVideoDetails(
    String apiKey,
    List<String> videoIds,
  ) async {
    if (videoIds.isEmpty) return {};
    final Map<String, Map<String, String>> result = {};

    try {
      final idsParam = videoIds.join(',');
      final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
        'part': 'contentDetails,statistics',
        'id': idsParam,
        'key': apiKey,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];

        for (final item in items) {
          final id = item['id'] as String? ?? '';
          if (id.isEmpty) continue;

          final contentDetails =
              item['contentDetails'] as Map<String, dynamic>?;
          final statistics = item['statistics'] as Map<String, dynamic>?;

          String? durationStr;
          if (contentDetails != null &&
              contentDetails.containsKey('duration')) {
            durationStr =
                formatIsoDuration(contentDetails['duration'] as String? ?? '');
          }

          String? viewsStr;
          if (statistics != null && statistics.containsKey('viewCount')) {
            final count =
                int.tryParse(statistics['viewCount'] as String? ?? '');
            if (count != null) {
              viewsStr = formatViewCount(count);
            }
          }

          result[id] = {
            if (durationStr != null && durationStr.isNotEmpty)
              'duration': durationStr,
            if (viewsStr != null && viewsStr.isNotEmpty) 'viewCount': viewsStr,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching batch video details: $e');
    }

    return result;
  }

  /// Demo Catalog search implementing strict teacher + subject validation
  static SearchResult _searchDemoCatalogStrict({
    required String rawQuery,
    required String? parsedTeacher,
    required String? parsedSubject,
    String? category,
    ClassTypeFilter classType = ClassTypeFilter.all,
    ClassDurationFilter duration = ClassDurationFilter.any,
    ClassSortOrder sortOrder = ClassSortOrder.relevance,
    String? lockedChannelId,
    String? pageToken,
  }) {
    final lowerRaw = rawQuery.toLowerCase();
    final tokens =
        lowerRaw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // 1. If explicit teacher is requested
    if (parsedTeacher != null && parsedTeacher.isNotEmpty) {
      final lowerTeacher = parsedTeacher.toLowerCase();

      // Find all videos by this teacher in the demo catalog
      final teacherVideos = _demoCatalog.where((v) {
        if (lockedChannelId != null && lockedChannelId.isNotEmpty) {
          return v.channelId == lockedChannelId;
        }
        return v.channelTitle.toLowerCase().contains(lowerTeacher) ||
            v.channelId.toLowerCase().contains(lowerTeacher);
      }).toList();

      if (teacherVideos.isEmpty) {
        return SearchResult(
          items: const [],
          totalResults: 0,
          isDemoMode: true,
          parsedTeacher: parsedTeacher,
          parsedSubject: parsedSubject,
          noMatchingForTeacherSubject: true,
        );
      }

      // If a subject was also requested, strictly test subject relevance
      if (parsedSubject != null && parsedSubject.trim().isNotEmpty) {
        final subjectTokens = parsedSubject
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();

        final subjectMatches = teacherVideos.where((v) {
          final hay = '${v.title} ${v.description}'.toLowerCase();
          return subjectTokens.any((token) => hay.contains(token));
        }).toList();

        if (subjectMatches.isEmpty) {
          // Critical Requirement: Teacher exists, but has 0 videos for this subject!
          // NEVER silently fill with other videos.
          return SearchResult(
            items: const [],
            totalResults: 0,
            isDemoMode: true,
            resolvedChannelTitle: teacherVideos.first.channelTitle,
            resolvedChannelId: teacherVideos.first.channelId,
            parsedTeacher: teacherVideos.first.channelTitle,
            parsedSubject: parsedSubject,
            noMatchingForTeacherSubject: true,
          );
        }

        final teachers = extractTeachers(subjectMatches);
        return SearchResult(
          items: subjectMatches,
          totalResults: subjectMatches.length,
          isDemoMode: true,
          availableTeachers: teachers,
          resolvedChannelTitle: teacherVideos.first.channelTitle,
          resolvedChannelId: teacherVideos.first.channelId,
          parsedTeacher: teacherVideos.first.channelTitle,
          parsedSubject: parsedSubject,
        );
      }

      // Teacher only without subject
      final teachers = extractTeachers(teacherVideos);
      return SearchResult(
        items: teacherVideos,
        totalResults: teacherVideos.length,
        isDemoMode: true,
        availableTeachers: teachers,
        resolvedChannelTitle: teacherVideos.first.channelTitle,
        resolvedChannelId: teacherVideos.first.channelId,
        parsedTeacher: teacherVideos.first.channelTitle,
      );
    }

    // 2. Open search (no explicit teacher) -> matches multiple teachers
    var matches = _demoCatalog.where((video) {
      final hay =
          '${video.title} ${video.channelTitle} ${video.description} ${video.studyCategory}'
              .toLowerCase();

      final matchesQuery = tokens.any((tok) => hay.contains(tok));
      if (!matchesQuery) return false;

      if (classType != ClassTypeFilter.all) {
        final kw = classType.searchKeyword.toLowerCase();
        if (!hay.contains(kw)) return false;
      }

      return true;
    }).toList();

    // Fallback if no exact token matched: return top category items
    if (matches.isEmpty && category != null && category.isNotEmpty) {
      matches = getCuratedCatalogForCategory(category);
    }

    // Pagination in Demo Mode (6 per page)
    const pageSize = 6;
    int startIndex = 0;
    if (pageToken != null && pageToken.startsWith('demo_p_')) {
      startIndex = int.tryParse(pageToken.replaceFirst('demo_p_', '')) ?? 0;
    }

    final pagedItems = matches.skip(startIndex).take(pageSize).toList();
    final nextIndex = startIndex + pageSize;
    final nextToken = nextIndex < matches.length ? 'demo_p_$nextIndex' : null;

    final teachers = extractTeachers(matches);
    return SearchResult(
      items: pagedItems.isNotEmpty ? pagedItems : matches,
      nextPageToken: nextToken,
      totalResults: matches.length,
      isDemoMode: true,
      availableTeachers: teachers,
      parsedSubject: rawQuery,
    );
  }

  /// Get curated catalog items strictly for a given study category
  static List<VideoItem> getCuratedCatalogForCategory(String category) {
    final cat = category.toLowerCase();
    final list = _demoCatalog.where((v) {
      final vCat = v.studyCategory.toLowerCase();
      if (cat.contains('college') || cat.contains('university')) {
        return vCat.contains('college');
      }
      if (cat.contains('professional') || cat.contains('ca')) {
        return vCat.contains('professional');
      }
      if (cat.contains('competitive') ||
          cat.contains('jee') ||
          cat.contains('neet') ||
          cat.contains('upsc')) {
        return vCat.contains('competitive');
      }
      if (cat.contains('school')) {
        return vCat.contains('school');
      }
      if (cat.contains('certification')) {
        return vCat.contains('certification');
      }
      if (cat.contains('self-study')) {
        return vCat.contains('self-study');
      }
      return true;
    }).toList();

    return list.isNotEmpty ? list : _demoCatalog.take(6).toList();
  }

  /// Clean HTML entities commonly returned by YouTube API
  static String _cleanHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  // ==========================================
  // CURATED MULTI-TEACHER DEMO CATALOG
  // Covers all 6 study categories with multi-teacher options
  // ==========================================
  static final List<VideoItem> _demoCatalog = [
    // ----------------------------------------
    // PROFESSIONAL EXAM (CA Inter / CS / CMA)
    // ----------------------------------------
    const VideoItem(
      id: 'demo_as10_rishabh',
      title: 'AS 10 – Full Lecture | CA Inter Advanced Accounting',
      description:
          'Comprehensive coverage of AS 10 Property, Plant and Equipment. Covers recognition criteria, initial measurement, depreciation and derecognition with ICAI module illustrations.',
      channelTitle: 'CA Rishabh Jain',
      channelId: 'UC_rishabh_jain',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=600&auto=format&fit=crop&q=80',
      duration: '1:28:40',
      viewCount: '320K views',
      subscriberCount: '1.2M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_law_rishabh',
      title: 'Corporate Law: Preliminary & Incorporation Chapter 1 & 2',
      description:
          'In-depth conceptual analysis of Companies Act 2013 Preliminary concepts, types of companies, MoA and AoA provisions.',
      channelTitle: 'CA Rishabh Jain',
      channelId: 'UC_rishabh_jain',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=600&auto=format&fit=crop&q=80',
      duration: '1:50:20',
      viewCount: '190K views',
      subscriberCount: '1.2M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_as10_shruti',
      title: 'AS 10 – One Shot | Advanced Accounting',
      description:
          'Fast-track one-shot revision of AS 10 Property Plant & Equipment with summary charts and exam questions.',
      channelTitle: 'CA Shruti Kedia',
      channelId: 'UC_shruti_kedia',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=600&auto=format&fit=crop&q=80',
      duration: '2:05:16',
      viewCount: '280K views',
      subscriberCount: '750K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_as10_mayank',
      title: 'AS 10 – Revision Class | Important Questions',
      description:
          'High-yield practical problems and RTP/MTP questions for AS 10 Property, Plant and Equipment.',
      channelTitle: 'CA Mayank Agarwal',
      channelId: 'UC_mayank_agarwal',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600&auto=format&fit=crop&q=80',
      duration: '58:12',
      viewCount: '150K views',
      subscriberCount: '480K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_as10_tated',
      title: 'AS 10 – Detailed Concept & Questions',
      description:
          'In-depth conceptual framework of AS 10 including revaluation model, cost model, and component depreciation.',
      channelTitle: 'CA Amit Tated',
      channelId: 'UC_amit_tated',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=600&auto=format&fit=crop&q=80',
      duration: '1:42:10',
      viewCount: '95K views',
      subscriberCount: '620K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_audit_tated',
      title: 'CA Inter Audit – SA 200 Series Full Revision & Standards',
      description:
          'Standards on Auditing (SA 200, 210, 220, 230) detailed exam revision, audit evidence and documentation techniques.',
      channelTitle: 'CA Amit Tated',
      channelId: 'UC_amit_tated',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&auto=format&fit=crop&q=80',
      duration: '2:15:00',
      viewCount: '210K views',
      subscriberCount: '620K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_as10_aditya',
      title: 'AS 10 – Marathon Class | Complete Coverage',
      description:
          'Complete AS 10 Marathon lecture covering theory, journal entries, and past 5 examination papers.',
      channelTitle: 'CA Aditya Sharma',
      channelId: 'UC_aditya_sharma',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&auto=format&fit=crop&q=80',
      duration: '3:15:20',
      viewCount: '110K views',
      subscriberCount: '510K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_gst_vishal',
      title: 'GST Input Tax Credit (ITC) Full Lecture | Section 16 to 18',
      description:
          'Master GST Input Tax Credit eligibility, conditions, blocked credits under Section 17(5), and rule 42/43 apportionment.',
      channelTitle: 'CA Vishal Bhattad',
      channelId: 'UC_vishal_bhattad',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&auto=format&fit=crop&q=80',
      duration: '2:40:00',
      viewCount: '450K views',
      subscriberCount: '1.4M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),
    const VideoItem(
      id: 'demo_law_shubham',
      title: 'Corporate Law Chapter 7: Management & Administration One-Shot',
      description:
          'Sections 88 to 122 of Companies Act 2013: Register of members, annual returns, general meetings, voting & resolutions.',
      channelTitle: 'CA Shubham Singhal',
      channelId: 'UC_shubham_singhal',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600&auto=format&fit=crop&q=80',
      duration: '1:55:00',
      viewCount: '210K views',
      subscriberCount: '430K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Professional Exam',
    ),

    // ----------------------------------------
    // COMPETITIVE EXAM (JEE / NEET / UPSC / SSC)
    // ----------------------------------------
    const VideoItem(
      id: 'demo_calc_pw',
      title: 'Calculus One Shot (Class 12 / JEE)',
      description:
          'Complete Differential and Integral Calculus for JEE Main & Advanced with standard integration patterns and shortcut techniques.',
      channelTitle: 'Physics Wallah',
      channelId: 'UC_physics_wallah',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&auto=format&fit=crop&q=80',
      duration: '2:15:30',
      viewCount: '1.2M views',
      subscriberCount: '12M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Competitive Exam',
    ),
    const VideoItem(
      id: 'demo_physio_neha',
      title: 'Human Physiology NEET 2024 Chapter | Complete Biology',
      description:
          'Digestion, breathing, circulatory system, and neural coordination explained with NCERT line-by-line coverage for NEET.',
      channelTitle: 'Dr. Neha Taneja',
      channelId: 'UC_neha_taneja',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600&auto=format&fit=crop&q=80',
      duration: '1:05:12',
      viewCount: '856K views',
      subscriberCount: '950K subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Competitive Exam',
    ),
    const VideoItem(
      id: 'demo_electro_tyagi',
      title: 'Electrostatics Full Chapter JEE Main & Advanced',
      description:
          'Coulomb law, electric field, potential, Gauss law, dipoles and conductors with rigorous problem sets.',
      channelTitle: 'Mohit Tyagi',
      channelId: 'UC_mohit_tyagi',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1507668077129-56e32842fceb?w=600&auto=format&fit=crop&q=80',
      duration: '3:20:10',
      viewCount: '920K views',
      subscriberCount: '1.1M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Competitive Exam',
    ),
    const VideoItem(
      id: 'demo_history_studyiq',
      title: 'Modern Indian History Crash Course for UPSC CSE',
      description:
          'From the advent of Europeans to 1947 independence: British expansion, 1857 revolt, social reforms, and Gandhian national movement.',
      channelTitle: 'StudyIQ IAS',
      channelId: 'UC_studyiq',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=600&auto=format&fit=crop&q=80',
      duration: '4:10:00',
      viewCount: '1.5M views',
      subscriberCount: '16M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Competitive Exam',
    ),

    // ----------------------------------------
    // SCHOOL (Class 9 - 12)
    // ----------------------------------------
    const VideoItem(
      id: 'demo_trigo_dearsir',
      title: 'Class 10 Trigonometry Full Chapter | Concept & NCERT Solutions',
      description:
          'Trigonometric ratios, values table, trigonometric identities and applications of trigonometry made simple.',
      channelTitle: 'Dear Sir',
      channelId: 'UC_dearsir',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1596495578065-6e0763fa1178?w=600&auto=format&fit=crop&q=80',
      duration: '1:15:00',
      viewCount: '2.8M views',
      subscriberCount: '17M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'School',
    ),
    const VideoItem(
      id: 'demo_chem_vedantu',
      title: 'Chemical Reactions & Equations Class 10 Full Chapter',
      description:
          'Types of chemical reactions, balancing equations, oxidation-reduction, corrosion and rancidity.',
      channelTitle: 'Vedantu 9&10',
      channelId: 'UC_vedantu_class10',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=600&auto=format&fit=crop&q=80',
      duration: '1:02:00',
      viewCount: '780K views',
      subscriberCount: '3.2M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'School',
    ),
    const VideoItem(
      id: 'demo_cell_magnet',
      title: 'Cell: The Unit of Life Biology Class 11 Complete',
      description:
          'Prokaryotic vs Eukaryotic cells, cell organelles, endomembrane system, mitochondria, chloroplast and nucleus.',
      channelTitle: 'Magnet Brains',
      channelId: 'UC_magnet_brains',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=600&auto=format&fit=crop&q=80',
      duration: '1:40:00',
      viewCount: '950K views',
      subscriberCount: '10M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'School',
    ),

    // ----------------------------------------
    // COLLEGE / UNIVERSITY
    // ----------------------------------------
    const VideoItem(
      id: 'demo_dsa_abdul',
      title: 'Data Structures & Algorithms Masterclass: Trees & Graphs',
      description:
          'Binary trees, AVL trees, B-Trees, graph traversals BFS/DFS, Dijkstra shortest path algorithm and complexity proofs.',
      channelTitle: 'Abdul Bari',
      channelId: 'UC_abdul_bari',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=600&auto=format&fit=crop&q=80',
      duration: '2:45:00',
      viewCount: '2.1M views',
      subscriberCount: '1.2M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'College / University',
    ),
    const VideoItem(
      id: 'demo_os_gatesmashers',
      title:
          'Operating Systems Full Course: Process Synchronization & Deadlocks',
      description:
          'Critical section problem, Semaphores, Peterson algorithm, Producer-Consumer, and Banker deadlock avoidance algorithm.',
      channelTitle: 'Gate Smashers',
      channelId: 'UC_gate_smashers',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1629654297299-c8506221ca97?w=600&auto=format&fit=crop&q=80',
      duration: '3:10:00',
      viewCount: '1.8M views',
      subscriberCount: '1.7M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'College / University',
    ),
    const VideoItem(
      id: 'demo_linalg_3blue',
      title: 'Linear Algebra: Essence of Vectors, Matrices & Eigenvalues',
      description:
          'Geometric visual intuition behind linear transformations, determinants, dot products, cross products and eigenvectors.',
      channelTitle: '3Blue1Brown',
      channelId: 'UC_3blue1brown',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=600&auto=format&fit=crop&q=80',
      duration: '45:00',
      viewCount: '3.4M views',
      subscriberCount: '6.2M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'College / University',
    ),

    // ----------------------------------------
    // CERTIFICATION
    // ----------------------------------------
    const VideoItem(
      id: 'demo_aws_freecode',
      title: 'AWS Certified Solutions Architect (SAA-C03) Full Course',
      description:
          'Complete hands-on training for AWS SAA-C03: EC2, S3, VPC, RDS, DynamoDB, IAM, Lambda, and high-availability architecture patterns.',
      channelTitle: 'freeCodeCamp',
      channelId: 'UC_freecodecamp',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
      duration: '4:20:00',
      viewCount: '1.6M views',
      subscriberCount: '10M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Certification',
    ),
    const VideoItem(
      id: 'demo_python_mosh',
      title: 'Python for Beginners – Full Course [Programming Tutorial]',
      description:
          'Learn Python programming from scratch: variables, strings, arithmetic, loops, lists, tuples, functions, classes and packages.',
      channelTitle: 'Programming with Mosh',
      channelId: 'UC_programming_mosh',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=600&auto=format&fit=crop&q=80',
      duration: '6:14:00',
      viewCount: '4.2M views',
      subscriberCount: '3.9M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Certification',
    ),
    const VideoItem(
      id: 'demo_docker_nana',
      title: 'Docker & Kubernetes Complete Tutorial for Beginners',
      description:
          'Container fundamentals, Dockerfiles, images, Docker Compose, Kubernetes Pods, Services, Deployments and Helm charts.',
      channelTitle: 'TechWorld with Nana',
      channelId: 'UC_techworld_nana',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1607799279861-4dd421887fb3?w=600&auto=format&fit=crop&q=80',
      duration: '2:50:00',
      viewCount: '1.9M views',
      subscriberCount: '1.1M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Certification',
    ),

    // ----------------------------------------
    // SELF-STUDY
    // ----------------------------------------
    const VideoItem(
      id: 'demo_learn_ali',
      title:
          'How to Learn Any Skill Faster: The Science of Evidence-Based Study',
      description:
          'Active recall, spaced repetition, Feynman technique, interleaving, and how to build a friction-free study routine.',
      channelTitle: 'Ali Abdaal',
      channelId: 'UC_ali_abdaal',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=600&auto=format&fit=crop&q=80',
      duration: '18:40',
      viewCount: '2.4M views',
      subscriberCount: '5.4M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Self-Study',
    ),
    const VideoItem(
      id: 'demo_pandas_corey',
      title: 'Python Pandas Tutorial: Complete Data Analysis Masterclass',
      description:
          'DataFrames, Series, filtering, indexing, updating rows, grouping, aggregating, and handling missing data in real projects.',
      channelTitle: 'Corey Schafer',
      channelId: 'UC_corey_schafer',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&auto=format&fit=crop&q=80',
      duration: '1:35:00',
      viewCount: '1.7M views',
      subscriberCount: '1.3M subscribers',
      isVerifiedTeacher: true,
      studyCategory: 'Self-Study',
    ),
  ];

  static List<VideoItem> getCuratedCatalog() => List.unmodifiable(_demoCatalog);
}
