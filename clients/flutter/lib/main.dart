import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/router.dart';
import 'core/config/providers.dart';

Future<void> main() async {
  // Must be called before any Flutter/plugin initialization.
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit requires global native backend initialization before runApp.
  // Calling this after widget binding but before runApp is the only safe order.
  MediaKit.ensureInitialized();

  // Load persisted server URL from shared_preferences before first frame.
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('server_url');

  runApp(
    ProviderScope(
      overrides: [
        // Pre-populate serverUrlProvider with the saved value so the router
        // can redirect correctly before the first build.
        if (savedUrl != null && savedUrl.isNotEmpty)
          serverUrlProvider.overrideWith((ref) => savedUrl),
      ],
      child: const OfflineAcademyApp(),
    ),
  );
}

class OfflineAcademyApp extends ConsumerWidget {
  const OfflineAcademyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'OfflineAcademy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
