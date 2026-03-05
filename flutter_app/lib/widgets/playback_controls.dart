import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../providers/playback_provider.dart';

class PlaybackControls extends StatelessWidget {
  final PlaybackProvider playback;

  const PlaybackControls({super.key, required this.playback});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Main controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Seek backward 5 min
            IconButton(
              icon: const Icon(Icons.fast_rewind),
              iconSize: 32,
              tooltip: s.seekBackward5Min,
              onPressed: playback.isStopped ? null : () => playback.seekRelative(-300),
            ),
            const SizedBox(width: 8),
            // Seek backward 30s
            IconButton(
              icon: const Icon(Icons.replay_30),
              iconSize: 36,
              tooltip: s.seekBackward30s,
              onPressed: playback.isStopped ? null : () => playback.seekRelative(-30),
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainerHigh,
              ),
            ),
            const SizedBox(width: 16),
            // Play / Pause / Replay
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
                elevation: 2,
                shadowColor: cs.shadow,
              ),
              onPressed: () => playback.togglePlayPause(),
              child: Icon(
                playback.isStopped
                    ? Icons.replay
                    : playback.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                size: 40,
              ),
            ),
            const SizedBox(width: 16),
            // Seek forward 30s
            IconButton(
              icon: const Icon(Icons.forward_30),
              iconSize: 36,
              tooltip: s.seekForward30s,
              onPressed: playback.isStopped ? null : () => playback.seekRelative(30),
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainerHigh,
              ),
            ),
            const SizedBox(width: 8),
            // Seek forward 5 min
            IconButton(
              icon: const Icon(Icons.fast_forward),
              iconSize: 32,
              tooltip: s.seekForward5Min,
              onPressed: playback.isStopped ? null : () => playback.seekRelative(300),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Stop / Replay button
        if (playback.isStopped)
          FilledButton.icon(
            onPressed: () => playback.cast(),
            icon: const Icon(Icons.replay),
            label: Text(s.replay),
          )
        else
          FilledButton.icon(
            onPressed: () => playback.stop(),
            icon: const Icon(Icons.stop),
            label: Text(s.stop),
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
          ),
      ],
    );
  }
}
