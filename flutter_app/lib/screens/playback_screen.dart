import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/playback_provider.dart';
import '../widgets/playback_controls.dart';

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({super.key});

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackProvider>();
    final status = playback.status;
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.nowPlaying),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await playback.stop();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(flex: 1),
                // File and device info
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cast_connected,
                    size: 40,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  status.fileName.isNotEmpty ? status.fileName : s.noFile,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  status.deviceName.isNotEmpty
                      ? s.castingTo(status.deviceName)
                      : s.noDevice,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                _buildStateChip(context, status.playbackState, s),
                const Spacer(flex: 1),
                // Progress bar (Slider for drag-to-seek)
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: cs.primary,
                        inactiveTrackColor: cs.surfaceContainerHighest,
                        thumbColor: cs.primary,
                        overlayColor: cs.primary.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: status.durationSecs > 0
                            ? status.progress.clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: status.durationSecs > 0
                            ? (value) {
                                final targetSecs =
                                    (value * status.durationSecs).round();
                                playback.seek(targetSecs);
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            status.elapsedDisplay,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFeatures: [const FontFeature.tabularFigures()],
                                ),
                          ),
                          Text(
                            status.durationDisplay,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFeatures: [const FontFeature.tabularFigures()],
                                ),
                          ),
                        ],
                      ),
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
                    style: TextStyle(color: cs.error),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateChip(BuildContext context, String state, S s) {
    final cs = Theme.of(context).colorScheme;
    Color chipColor;
    IconData iconData;

    switch (state) {
      case 'Playing':
        chipColor = cs.primary;
        iconData = Icons.play_arrow;
        break;
      case 'Paused':
        chipColor = cs.tertiary;
        iconData = Icons.pause;
        break;
      case 'Stopped':
        chipColor = cs.error;
        iconData = Icons.stop;
        break;
      case 'Loading...':
        chipColor = cs.secondary;
        iconData = Icons.hourglass_top;
        break;
      default:
        chipColor = cs.outline;
        iconData = Icons.info_outline;
    }

    return Chip(
      avatar: Icon(iconData, size: 16, color: chipColor),
      label: Text(s.playbackStateLabel(state)),
      backgroundColor: chipColor.withValues(alpha: 0.12),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
      labelStyle: TextStyle(color: chipColor, fontWeight: FontWeight.w500),
    );
  }
}
