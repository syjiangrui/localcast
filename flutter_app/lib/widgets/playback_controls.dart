import 'package:flutter/material.dart';
import '../providers/playback_provider.dart';

class PlaybackControls extends StatelessWidget {
  final PlaybackProvider playback;

  const PlaybackControls({super.key, required this.playback});

  @override
  Widget build(BuildContext context) {
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
              tooltip: '-5 min',
              onPressed: () => playback.seekRelative(-300),
            ),
            const SizedBox(width: 8),
            // Seek backward 30s
            IconButton(
              icon: const Icon(Icons.replay_30),
              iconSize: 36,
              tooltip: '-30s',
              onPressed: () => playback.seekRelative(-30),
            ),
            const SizedBox(width: 16),
            // Play / Pause
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => playback.togglePlayPause(),
              child: Icon(
                playback.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            // Seek forward 30s
            IconButton(
              icon: const Icon(Icons.forward_30),
              iconSize: 36,
              tooltip: '+30s',
              onPressed: () => playback.seekRelative(30),
            ),
            const SizedBox(width: 8),
            // Seek forward 5 min
            IconButton(
              icon: const Icon(Icons.fast_forward),
              iconSize: 32,
              tooltip: '+5 min',
              onPressed: () => playback.seekRelative(300),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Stop button
        OutlinedButton.icon(
          onPressed: () => playback.stop(),
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
      ],
    );
  }
}
