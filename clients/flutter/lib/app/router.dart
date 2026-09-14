import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/providers.dart';
import '../features/connection/connection_screen.dart';
import '../features/courses/courses_screen.dart';
import '../features/courses/course_detail_screen.dart';
import '../features/player/player_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/connect',
    redirect: (context, state) {
      final serverUrl = ref.read(serverUrlProvider);
      final onConnect = state.matchedLocation == '/connect';
      // If no URL saved, force to connect screen
      if ((serverUrl == null || serverUrl.isEmpty) && !onConnect) {
        return '/connect';
      }
      // If URL is saved and on connect, go to courses
      if (serverUrl != null && serverUrl.isNotEmpty && onConnect) {
        return '/courses';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/courses',
        builder: (context, state) => const CoursesScreen(),
      ),
      GoRoute(
        path: '/course/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return CourseDetailScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final extra = state.extra as PlayerArgs;
          return PlayerScreen(args: extra);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// Arguments passed to the player screen via go_router extra.
class PlayerArgs {
  final String lessonId;
  final String lessonTitle;
  final String mediaUrl;
  final int resumePosition; // seconds
  final String courseId;
  final String moduleId;

  const PlayerArgs({
    required this.lessonId,
    required this.lessonTitle,
    required this.mediaUrl,
    required this.resumePosition,
    required this.courseId,
    required this.moduleId,
  });
}
