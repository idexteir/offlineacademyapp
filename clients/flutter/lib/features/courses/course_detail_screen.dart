import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../app/router.dart';

class CourseDetailScreen extends ConsumerWidget {
  final String slug;
  const CourseDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(courseDetailProvider(slug));
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                err.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(courseDetailProvider(slug)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rawData) {
          final detail = rawData as CourseDetail;
          return _CourseDetailBody(detail: detail, client: client);
        },
      ),
    );
  }
}

class _CourseDetailBody extends StatelessWidget {
  final CourseDetail detail;
  final OfflineAcademyClient? client;

  const _CourseDetailBody({required this.detail, required this.client});

  @override
  Widget build(BuildContext context) {
    final course = detail.course;
    final modules = detail.modules;
    final stats = detail.stats;

    return CustomScrollView(
      slivers: [
        // Course header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.displayTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${stats.completedLessons} / ${stats.totalLessons} lessons',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${stats.percentage}%',
                      style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (stats.totalLessons > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: stats.percentage / 100,
                    backgroundColor: Colors.white12,
                    minHeight: 4,
                  ),
                ],
                if (course.description != null && course.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    course.description!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: Divider(height: 1, color: Colors.white12),
        ),

        // Module / lesson tree
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final module = modules[index];
              return _ModuleSection(
                module: module,
                client: client,
                courseId: detail.course.id,
              );
            },
            childCount: modules.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _ModuleSection extends StatelessWidget {
  final CourseModule module;
  final OfflineAcademyClient? client;
  final String courseId;

  const _ModuleSection({
    required this.module,
    required this.client,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            module.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...module.lessons.map((lesson) => _LessonTile(
              lesson: lesson,
              client: client,
              courseId: courseId,
              moduleId: module.id,
            )),
        const Divider(height: 1, color: Colors.white12),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final OfflineAcademyClient? client;
  final String courseId;
  final String moduleId;

  const _LessonTile({
    required this.lesson,
    required this.client,
    required this.courseId,
    required this.moduleId,
  });

  IconData get _typeIcon {
    return switch (lesson.type) {
      'VIDEO' => Icons.play_circle_outline,
      'AUDIO' => Icons.audiotrack_outlined,
      'PDF' => Icons.picture_as_pdf_outlined,
      'MARKDOWN' => Icons.article_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = lesson.progress;
    final isCompleted = progress?.completed ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        isCompleted ? Icons.check_circle : _typeIcon,
        color: isCompleted
            ? Colors.green.shade400
            : lesson.isVideo
                ? const Color(0xFF6C63FF)
                : Colors.white38,
        size: 22,
      ),
      title: Text(
        lesson.title,
        style: TextStyle(
          fontSize: 14,
          color: lesson.isVideo ? Colors.white : Colors.white70,
        ),
      ),
      subtitle: lesson.duration != null
          ? Text(
              _formatDuration(lesson.duration!),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            )
          : null,
      onTap: lesson.isVideo && client != null
          ? () {
              final mediaUrl = client!.buildMediaUrl(lesson.filePath);
              context.push(
                '/player',
                extra: PlayerArgs(
                  lessonId: lesson.id,
                  lessonTitle: lesson.title,
                  mediaUrl: mediaUrl,
                  resumePosition: progress?.position ?? 0,
                  courseId: courseId,
                  moduleId: moduleId,
                ),
              );
            }
          : null,
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}
