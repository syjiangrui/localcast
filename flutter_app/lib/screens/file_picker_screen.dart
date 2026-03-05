import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';
import '../models/history_entry.dart';
import '../providers/file_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/history_side_panel.dart';
import 'device_list_screen.dart';

const _supportedExtensions = ['mp4', 'mkv', 'avi', 'webm'];

class FilePickerScreen extends StatefulWidget {
  const FilePickerScreen({super.key});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  bool _isDragOver = false;
  bool? _showHistory;

  @override
  void initState() {
    super.initState();
    final history = context.read<HistoryProvider>();
    history.load().then((_) {
      if (mounted) {
        setState(() {
          _showHistory ??= false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.history),
          tooltip: s.historyToggle,
          isSelected: _showHistory ?? false,
          style: IconButton.styleFrom(
            backgroundColor: (_showHistory ?? false)
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
          ),
          onPressed: () => setState(() => _showHistory = !(_showHistory ?? false)),
        ),
        title: Text(s.appTitle),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      body: Row(
        children: [
          if (_showHistory ?? false) ...[
            HistorySidePanel(onSelect: _selectFromHistory),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragOver = true),
              onDragExited: (_) => setState(() => _isDragOver = false),
              onDragDone: (details) {
                setState(() => _isDragOver = false);
                _handleDrop(details);
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: _isDragOver
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      strokeWidth: _isDragOver ? 2.5 : 1.5,
                      borderRadius: 16,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: _isDragOver
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.05)
                            : null,
                      ),
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isDragOver
                                  ? Icons.file_download
                                  : Icons.video_file_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isDragOver ? s.dropVideoHere : s.selectVideoTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.supportedFormats,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 32),
                          if (fileProvider.hasFile) ...[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.movie,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileProvider.fileName ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatSize(fileProvider.fileSize ?? 0),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () => fileProvider.reset(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DeviceListScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(s.chooseDevice),
                            ),
                          ] else ...[
                            Text(
                              s.dragAndDropHint,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: fileProvider.loading
                                  ? null
                                  : () => _pickFile(context),
                              icon: fileProvider.loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.folder_open),
                              label: Text(s.selectVideoFile),
                            ),
                          ],
                          if (fileProvider.error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              fileProvider.error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDrop(DropDoneDetails details) {
    if (details.files.isEmpty) return;

    final file = details.files.first;
    final path = file.path;
    final ext = path.split('.').last.toLowerCase();

    if (!_supportedExtensions.contains(ext)) {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              s.unsupportedFileType(ext, _supportedExtensions.join(', '))),
        ),
      );
      return;
    }

    _selectAndNavigate(path);
  }

  Future<void> _selectAndNavigate(String path) async {
    final provider = context.read<FileProvider>();
    final success = await provider.selectFile(path);
    if (success && mounted) {
      final fileName = provider.fileName ?? p.basename(path);
      context.read<HistoryProvider>().recordFileSelected(path, fileName);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DeviceListScreen(),
        ),
      );
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    final provider = context.read<FileProvider>();
    final success = await provider.pickFile();
    if (success && context.mounted) {
      final path = provider.filePath!;
      final fileName = provider.fileName ?? p.basename(path);
      context.read<HistoryProvider>().recordFileSelected(path, fileName);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DeviceListScreen(),
        ),
      );
    }
  }

  Future<void> _selectFromHistory(HistoryEntry entry) async {
    final provider = context.read<FileProvider>();
    final success = await provider.selectFile(entry.filePath);
    if (success && mounted) {
      context
          .read<HistoryProvider>()
          .recordFileSelected(entry.filePath, entry.fileName);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DeviceListScreen(),
        ),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashLength = 8;
  final double dashGap = 5;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = min(distance + dashLength, metric.length);
        final extracted = metric.extractPath(distance, end);
        canvas.drawPath(extracted, paint);
        distance = end + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
