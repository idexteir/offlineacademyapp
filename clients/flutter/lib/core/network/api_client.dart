import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Low-level result wrapper — avoids throwing across async boundaries.
sealed class ApiResult<T> {}

final class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  ApiSuccess(this.data);
}

final class ApiError<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;
  ApiError(this.message, {this.statusCode});
}

/// HTTP client for the OfflineAcademy backend.
///
/// All methods are pure (no side effects on shared state).
/// URL encoding for media paths is handled in [buildMediaUrl].
class OfflineAcademyClient {
  final String baseUrl;
  final http.Client _http;

  static const _defaultTimeout = Duration(seconds: 15);

  OfflineAcademyClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Settings — used for server health/reachability check
  // ---------------------------------------------------------------------------

  /// GET /api/settings
  /// Returns a non-null map on success, or an ApiError with a message.
  Future<ApiResult<Map<String, dynamic>>> getSettings() async {
    return _get('/api/settings', (json) => json as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------------------

  /// GET /api/courses?page=1&limit=100
  Future<ApiResult<({List<Course> courses, Pagination pagination})>> getCourses({
    int page = 1,
    int limit = 100,
  }) async {
    final uri = Uri.parse('$baseUrl/api/courses').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    try {
      final response = await _http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode != 200) {
        return ApiError('Server returned ${response.statusCode}', statusCode: response.statusCode);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawCourses = json['courses'] as List<dynamic>? ?? [];
      final courses = rawCourses.map((c) => Course.fromJson(c as Map<String, dynamic>)).toList();
      final pagination = Pagination.fromJson(json['pagination'] as Map<String, dynamic>);
      return ApiSuccess((courses: courses, pagination: pagination));
    } on Exception catch (e) {
      return ApiError(_describeException(e));
    }
  }

  /// GET /api/courses/{slug}
  /// Returns full course with modules, lessons, and per-lesson progress.
  Future<ApiResult<CourseDetail>> getCourseBySlug(String slug) async {
    return _get(
      '/api/courses/${Uri.encodeComponent(slug)}',
      (json) => CourseDetail.fromJson(json as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Lesson
  // ---------------------------------------------------------------------------

  /// GET /api/lesson/{lessonId}
  /// Returns lesson + full course module tree + prev/next navigation.
  Future<ApiResult<Map<String, dynamic>>> getLesson(String lessonId) async {
    return _get(
      '/api/lesson/${Uri.encodeComponent(lessonId)}',
      (json) => json as Map<String, dynamic>,
    );
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// POST /api/progress
  Future<ApiResult<bool>> saveProgress({
    required String lessonId,
    required String courseId,
    required String moduleId,
    required int position,
    required bool completed,
  }) async {
    final uri = Uri.parse('$baseUrl/api/progress');
    try {
      final response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lessonId': lessonId,
              'courseId': courseId,
              'moduleId': moduleId,
              'position': position,
              'completed': completed,
            }),
          )
          .timeout(_defaultTimeout);
      if (response.statusCode == 200) return ApiSuccess(true);
      return ApiError('Server returned ${response.statusCode}', statusCode: response.statusCode);
    } on Exception catch (e) {
      return ApiError(_describeException(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Media URL construction
  // ---------------------------------------------------------------------------

  /// Constructs the media streaming URL from a lesson's filePath.
  ///
  /// The filePath from the database is relative to COURSES_ROOT and uses
  /// forward slashes, e.g.: "Test Course/Module 1/01 - Introduction.mp4"
  ///
  /// We encode each segment individually with [Uri.encodeComponent] so that
  /// spaces, parentheses, brackets, #, %, ?, & etc. are escaped correctly,
  /// while the / separators are preserved for Next.js's catch-all [...path] route.
  ///
  /// Example:
  ///   filePath = "Test Course/Module 1/01 - Introduction.mp4"
  ///   result   = "http://192.168.1.50:6969/api/files/Test%20Course/Module%201/01%20-%20Introduction.mp4"
  String buildMediaUrl(String filePath) {
    final encodedPath = filePath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return '$baseUrl/api/files/$encodedPath';
  }

  /// Builds a thumbnail URL from a relative path (same encoding as media).
  String? buildThumbnailUrl(String? thumbnail) {
    if (thumbnail == null || thumbnail.isEmpty) return null;
    // Thumbnails starting with / are served from Next.js public/ directly.
    if (thumbnail.startsWith('/')) return '$baseUrl$thumbnail';
    // Otherwise treat as a file-relative path.
    return buildMediaUrl(thumbnail);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<ApiResult<T>> _get<T>(String path, T Function(dynamic) parse) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 404) {
        return ApiError('Not found', statusCode: 404);
      }
      if (response.statusCode != 200) {
        return ApiError('Server returned ${response.statusCode}', statusCode: response.statusCode);
      }
      final dynamic json;
      try {
        json = jsonDecode(response.body);
      } catch (e) {
        return ApiError('Failed to parse server response as JSON');
      }
      try {
        return ApiSuccess(parse(json));
      } catch (e) {
        return ApiError('Failed to process server response: $e');
      }
    } on Exception catch (e) {
      return ApiError(_describeException(e));
    }
  }

  String _describeException(Exception e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'Cannot reach server';
    }
    if (s.contains('TimeoutException')) {
      return 'Connection timed out';
    }
    if (s.contains('HandshakeException') || s.contains('CertificateException')) {
      return 'TLS/certificate error';
    }
    if (s.contains('FormatException')) {
      return 'Invalid response format';
    }
    return 'Network error: $s';
  }

  void dispose() => _http.close();
}
