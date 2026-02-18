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
  final _barKey = GlobalKey();
  bool _hovering = false;
  double _hoverX = 0;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackProvider>();
    final status = playback.status;
    final s = S.of(context);

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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStateChip(context, status.playbackState, s),
            const Spacer(flex: 1),
            // Progress bar (click to seek, hover to preview time)
            Column(
              children: [
                MouseRegion(
                  cursor: status.durationSecs > 0
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() {
                    _hovering = false;
                    _hoverX = 0;
                  }),
                  onHover: (event) {
                    final barBox = _barKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    if (barBox == null) return;
                    final local =
                        barBox.globalToLocal(event.position);
                    setState(() => _hoverX = local.dx);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: status.durationSecs > 0
                        ? (details) => _seekFromDetails(details, playback)
                        : null,
                    child: SizedBox(
                      key: _barKey,
                      height: 24,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(
                            child: LinearProgressIndicator(
                              value: status.progress.clamp(0.0, 1.0),
                              minHeight: _hovering ? 10 : 6,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          if (_hovering && status.durationSecs > 0)
                            Builder(builder: (context) {
                              final barBox = _barKey.currentContext
                                  ?.findRenderObject() as RenderBox?;
                              final barWidth = barBox?.size.width ?? 1;
                              final ratio =
                                  (_hoverX / barWidth).clamp(0.0, 1.0);
                              final secs =
                                  (ratio * status.durationSecs).round();
                              final label = _formatTime(secs);
                              return Positioned(
                                left: _hoverX - 28,
                                top: -32,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inverseSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onInverseSurface,
                                        ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
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

  void _seekFromDetails(
    TapDownDetails details,
    PlaybackProvider playback,
  ) {
    final barBox =
        _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (barBox == null) return;
    final localPos = barBox.globalToLocal(details.globalPosition);
    final ratio = (localPos.dx / barBox.size.width).clamp(0.0, 1.0);
    final targetSecs = (ratio * playback.status.durationSecs).round();
    playback.seek(targetSecs);
  }

  String _formatTime(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Widget _buildStateChip(BuildContext context, String state, S s) {
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
      label: Text(s.playbackStateLabel(state)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(color: color),
    );
  }
}
