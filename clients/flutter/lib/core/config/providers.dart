import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

// ---------------------------------------------------------------------------
// Server URL storage
// ---------------------------------------------------------------------------

const _kServerUrlKey = 'server_url';

/// Holds the persisted server URL. Null = not configured yet.
final serverUrlProvider = StateProvider<String?>((ref) => null);

/// Initializes serverUrlProvider from SharedPreferences.
/// Call this once at startup before runApp.
Future<void> loadSavedServerUrl(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kServerUrlKey);
  if (saved != null && saved.isNotEmpty) {
    ref.read(serverUrlProvider.notifier).state = saved;
  }
}

/// Persists a server URL and updates the provider.
Future<void> saveServerUrl(WidgetRef ref, String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kServerUrlKey, url);
  ref.read(serverUrlProvider.notifier).state = url;
}

// ---------------------------------------------------------------------------
// API client
// ---------------------------------------------------------------------------

/// Provides an [OfflineAcademyClient] for the current serverUrl.
/// Automatically recreated when serverUrl changes.
final apiClientProvider = Provider<OfflineAcademyClient?>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null || url.isEmpty) return null;
  return OfflineAcademyClient(baseUrl: url.trimRight().replaceAll(RegExp(r'/+$'), ''));
});

// ---------------------------------------------------------------------------
// Courses
// ---------------------------------------------------------------------------

final coursesProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) throw StateError('No server configured');
  final result = await client.getCourses(limit: 100);
  return switch (result) {
    ApiSuccess(:final data) => data,
    ApiError(:final message) => throw Exception(message),
  };
});

// ---------------------------------------------------------------------------
// Course detail (by slug)
// ---------------------------------------------------------------------------

final courseDetailProvider = FutureProvider.autoDispose.family<dynamic, String>((ref, slug) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) throw StateError('No server configured');
  final result = await client.getCourseBySlug(slug);
  return switch (result) {
    ApiSuccess(:final data) => data,
    ApiError(:final message) => throw Exception(message),
  };
});
