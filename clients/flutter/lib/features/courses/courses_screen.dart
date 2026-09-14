import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    final serverUrl = ref.watch(serverUrlProvider) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OfflineAcademy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_off),
            tooltip: 'Change server',
            onPressed: () {
              ref.read(serverUrlProvider.notifier).state = null;
              context.go('/connect');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(coursesProvider),
          ),
        ],
      ),
      body: coursesAsync.when(
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
                onPressed: () => ref.invalidate(coursesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final courses = data.courses;
          if (courses.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text('No courses found', style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 8),
                  Text(
                    'Add courses to My_Courses/ and scan from the web UI.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseCard(course: course, serverUrl: serverUrl);
            },
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final String serverUrl;

  const _CourseCard({required this.course, required this.serverUrl});

  @override
  Widget build(BuildContext context) {
    final progress = course.progress;
    final percentage = progress?.percentage ?? 0;
    final total = progress?.totalLessons ?? course.count?.lessons ?? 0;
    final completed = progress?.completedLessons ?? 0;

    String? thumbUrl;
    final thumb = course.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      thumbUrl = thumb.startsWith('/') ? '$serverUrl$thumb' : thumb;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/course/${Uri.encodeComponent(course.slug)}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 56,
                  child: thumbUrl != null
                      ? Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              // Course info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed / $total lessons',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.white12,
                        minHeight: 3,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF2D2D2D),
        child: const Icon(Icons.school, color: Colors.white24),
      );
}
