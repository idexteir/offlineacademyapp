import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/router.dart';
import '../../core/config/providers.dart';

/// Riverpod provider for the player + controller pair.
/// family keyed on PlayerArgs so each lesson gets its own isolated player.
final _playerProvider = Provider.autoDispose.family<({Player player, VideoController controller}), PlayerArgs>(
  (ref, args) {
    final player = Player(
      configuration: const PlayerConfiguration(
        // Prefer libmpv's network stack — supports HTTP 206 range requests natively.
        // No buffering policy changes needed; the /api/files route handles Range headers.
        title: 'OfflineAcademy',
      ),
    );
    final controller = VideoController(player);

    ref.onDispose(() {
      player.dispose();
    });

    return (player: player, controller: controller);
  },
);

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayerArgs args;
  const PlayerScreen({super.key, required this.args});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _seekApplied = false;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    final notifier = ref.read(_playerProvider(widget.args));
    final player = notifier.player;

    // Open the media URL. media_kit/libmpv automatically sends Range requests
    // to the server, so the /api/files endpoint's 206 support is exercised here.
    await player.open(Media(widget.args.mediaUrl), play: false);

    // Listen for when the player is ready before applying resume position.
    // Seeking before the media is loaded causes a no-op or crash.
    player.stream.duration.listen((duration) {
      if (!_seekApplied && duration.inSeconds > 0 && widget.args.resumePosition > 0) {
        _seekApplied = true;
        player.seek(Duration(seconds: widget.args.resumePosition));
      }
    });

    // Delay play until after seek is applied (or immediately if no resume).
    if (widget.args.resumePosition == 0) {
      await player.play();
    } else {
      // Wait briefly for the stream.duration listener to trigger.
      await Future.delayed(const Duration(milliseconds: 300));
      await player.play();
    }

    // Save progress periodically via POST /api/progress.
    _startProgressSaving(player);
  }

  void _startProgressSaving(Player player) {
    player.stream.position.listen((position) async {
      // Save every 10 seconds of playback.
      if (position.inSeconds % 10 == 0 && position.inSeconds > 0) {
        final client = ref.read(apiClientProvider);
        if (client == null) return;
        await client.saveProgress(
          lessonId: widget.args.lessonId,
          courseId: widget.args.courseId,
          moduleId: widget.args.moduleId,
          position: position.inSeconds,
          completed: false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(_playerProvider(widget.args));
    final player = notifier.player;
    final controller = notifier.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.args.lessonTitle,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // Video surface — fills available width, 16:9 aspect ratio.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: controller),
          ),

          // Playback controls.
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, posSnap) {
              return StreamBuilder<Duration>(
                stream: player.stream.duration,
                builder: (context, durSnap) {
                  final position = posSnap.data ?? Duration.zero;
                  final duration = durSnap.data ?? Duration.zero;

                  return Column(
                    children: [
                      // Seek slider.
                      Slider(
                        value: duration.inSeconds > 0
                            ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: duration.inSeconds > 0
                            ? (value) {
                                final target = Duration(
                                  seconds: (value * duration.inSeconds).round(),
                                );
                                player.seek(target);
                              }
                            : null,
                      ),

                      // Position / duration text + play/pause button.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const Spacer(),
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              builder: (context, playSnap) {
                                final playing = playSnap.data ?? false;
                                return Row(
                                  children: [
                                    // Seek back 10 s
                                    IconButton(
                                      icon: const Icon(Icons.replay_10, color: Colors.white),
                                      onPressed: () => player.seek(
                                        Duration(seconds: (position.inSeconds - 10).clamp(0, duration.inSeconds)),
                                      ),
                                    ),
                                    // Play / Pause
                                    IconButton(
                                      iconSize: 36,
                                      icon: Icon(
                                        playing ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => playing ? player.pause() : player.play(),
                                    ),
                                    // Seek forward 30 s
                                    IconButton(
                                      icon: const Icon(Icons.forward_30, color: Colors.white),
                                      onPressed: () => player.seek(
                                        Duration(seconds: (position.inSeconds + 30).clamp(0, duration.inSeconds)),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Spacer(),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
