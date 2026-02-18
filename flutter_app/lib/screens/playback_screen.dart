import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playback_provider.dart';
import '../widgets/playback_controls.dart';

class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackProvider>();
    final status = playback.status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await playback.stop();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 1),
            // File and device info
            Icon(
              Icons.cast_connected,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              status.fileName.isNotEmpty ? status.fileName : 'No file',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              status.deviceName.isNotEmpty
                  ? 'Casting to ${status.deviceName}'
                  : 'No device',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStateChip(context, status.playbackState),
            const Spacer(flex: 1),
            // Progress bar (click to seek)
            Column(
              children: [
                MouseRegion(
                  cursor: status.durationSecs > 0
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    onTapDown: status.durationSecs > 0
                        ? (details) {
                            _seekToTap(context, details, playback);
                          }
                        : null,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: 24,
                          child: Align(
                            alignment: Alignment.center,
                            child: LinearProgressIndicator(
                              value: status.progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status.elapsedDisplay,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      status.durationDisplay,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Controls
            PlaybackControls(playback: playback),
            const Spacer(flex: 2),
            // Error display
            if (playback.error != null)
              Text(
                playback.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  void _seekToTap(
    BuildContext context,
    TapDownDetails details,
    PlaybackProvider playback,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx;
    final width = box.size.width;
    final ratio = (localX / width).clamp(0.0, 1.0);
    final targetSecs = (ratio * playback.status.durationSecs).round();
    playback.seek(targetSecs);
  }

  Widget _buildStateChip(BuildContext context, String state) {
    Color color;
    switch (state) {
      case 'Playing':
        color = Colors.green;
        break;
      case 'Paused':
        color = Colors.orange;
        break;
      case 'Stopped':
        color = Colors.red;
        break;
      case 'Loading...':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(state),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(color: color),
    );
  }
}
