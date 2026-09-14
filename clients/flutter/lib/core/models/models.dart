// Core data models for OfflineAcademy Flutter client.
// Models match the actual JSON shapes from the backend contract.

class Lesson {
  final String id;
  final String title;
  final String slug;
  final int order;
  final String moduleId;
  final String filePath;
  final String fileName;
  final String mimeType;
  final int? duration;
  final String? thumbnail;
  final String type; // VIDEO, AUDIO, PDF, MARKDOWN, etc.
  final String? subtitlePath;
  final LessonProgress? progress;

  const Lesson({
    required this.id,
    required this.title,
    required this.slug,
    required this.order,
    required this.moduleId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    this.duration,
    this.thumbnail,
    required this.type,
    this.subtitlePath,
    this.progress,
  });

  bool get isVideo => type == 'VIDEO';

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      order: (json['order'] as num).toInt(),
      moduleId: json['moduleId'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      duration: json['duration'] != null ? (json['duration'] as num).toInt() : null,
      thumbnail: json['thumbnail'] as String?,
      type: json['type'] as String? ?? 'VIDEO',
      subtitlePath: json['subtitlePath'] as String?,
      progress: json['progress'] != null
          ? LessonProgress.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LessonProgress {
  final int position;
  final bool completed;
  final String? lastWatched;

  const LessonProgress({
    required this.position,
    required this.completed,
    this.lastWatched,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      position: (json['position'] as num).toInt(),
      completed: json['completed'] as bool? ?? false,
      lastWatched: json['lastWatched'] as String?,
    );
  }
}

class CourseModule {
  final String id;
  final String name;
  final String slug;
  final int order;
  final String courseId;
  final List<Lesson> lessons;

  const CourseModule({
    required this.id,
    required this.name,
    required this.slug,
    required this.order,
    required this.courseId,
    required this.lessons,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as List<dynamic>? ?? [];
    return CourseModule(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      order: (json['order'] as num).toInt(),
      courseId: json['courseId'] as String,
      lessons: rawLessons.map((l) => Lesson.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}

class CourseStats {
  final int totalLessons;
  final int completedLessons;
  final int percentage;

  const CourseStats({
    required this.totalLessons,
    required this.completedLessons,
    required this.percentage,
  });

  factory CourseStats.fromJson(Map<String, dynamic> json) {
    return CourseStats(
      totalLessons: (json['totalLessons'] as num).toInt(),
      completedLessons: (json['completedLessons'] as num).toInt(),
      percentage: (json['percentage'] as num).toInt(),
    );
  }
}

class Course {
  final String id;
  final String name;
  final String? displayName;
  final String slug;
  final String? thumbnail;
  final String? description;
  final bool hidden;
  final bool favorited;
  final String createdAt;
  final String updatedAt;
  final CourseCount? count;
  final CourseProgressSummary? progress;

  const Course({
    required this.id,
    required this.name,
    this.displayName,
    required this.slug,
    this.thumbnail,
    this.description,
    required this.hidden,
    required this.favorited,
    required this.createdAt,
    required this.updatedAt,
    this.count,
    this.progress,
  });

  /// Prefer displayName, fall back to name.
  String get displayTitle => (displayName != null && displayName!.isNotEmpty) ? displayName! : name;

  factory Course.fromJson(Map<String, dynamic> json) {
    final rawCount = json['_count'] as Map<String, dynamic>?;
    final rawProgress = json['progress'] as Map<String, dynamic>?;
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      slug: json['slug'] as String,
      thumbnail: json['thumbnail'] as String?,
      description: json['description'] as String?,
      hidden: json['hidden'] as bool? ?? false,
      favorited: json['favorited'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      count: rawCount != null ? CourseCount.fromJson(rawCount) : null,
      progress: rawProgress != null ? CourseProgressSummary.fromJson(rawProgress) : null,
    );
  }
}

class CourseCount {
  final int modules;
  final int lessons;

  const CourseCount({required this.modules, required this.lessons});

  factory CourseCount.fromJson(Map<String, dynamic> json) {
    return CourseCount(
      modules: (json['modules'] as num? ?? 0).toInt(),
      lessons: (json['lessons'] as num? ?? 0).toInt(),
    );
  }
}

class CourseProgressSummary {
  final int completedLessons;
  final int totalLessons;
  final int percentage;
  final String? lastWatched;

  const CourseProgressSummary({
    required this.completedLessons,
    required this.totalLessons,
    required this.percentage,
    this.lastWatched,
  });

  factory CourseProgressSummary.fromJson(Map<String, dynamic> json) {
    return CourseProgressSummary(
      completedLessons: (json['completedLessons'] as num? ?? 0).toInt(),
      totalLessons: (json['totalLessons'] as num? ?? 0).toInt(),
      percentage: (json['percentage'] as num? ?? 0).toInt(),
      lastWatched: json['lastWatched'] as String?,
    );
  }
}

class CourseDetail {
  final Course course;
  final List<CourseModule> modules;
  final CourseStats stats;

  const CourseDetail({
    required this.course,
    required this.modules,
    required this.stats,
  });

  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'] as List<dynamic>? ?? [];
    return CourseDetail(
      course: Course.fromJson(json),
      modules: rawModules.map((m) => CourseModule.fromJson(m as Map<String, dynamic>)).toList(),
      stats: json['stats'] != null
          ? CourseStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const CourseStats(totalLessons: 0, completedLessons: 0, percentage: 0),
    );
  }

  /// First video lesson across all modules, for quick-start playback.
  Lesson? get firstVideoLesson {
    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (lesson.isVideo) return lesson;
      }
    }
    return null;
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      hasNext: json['hasNext'] as bool? ?? false,
      hasPrev: json['hasPrev'] as bool? ?? false,
    );
  }
}
