import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/history_entry.dart';
import '../providers/history_provider.dart';

class HistorySidePanel extends StatefulWidget {
  final void Function(HistoryEntry entry) onSelect;

  const HistorySidePanel({super.key, required this.onSelect});

  @override
  State<HistorySidePanel> createState() => _HistorySidePanelState();
}

class _HistorySidePanelState extends State<HistorySidePanel> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<HistoryProvider>();
    final entries = provider.entries;

    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  s.historyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${entries.length})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      s.historyEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _HistoryTile(
                        entry: entry,
                        onTap: () => widget.onSelect(entry),
                        onDelete: () {
                          if (entry.id != null) {
                            provider.deleteEntry(entry.id!);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final missing = !entry.fileExists;

    String subtitle = entry.filePath;
    if (missing) {
      subtitle = s.historyFileMissing;
    } else if (entry.lastProgressSecs > 0) {
      subtitle = _formatProgress(entry.lastProgressSecs);
    }

    return InkWell(
      onTap: missing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: missing
                    ? cs.errorContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                missing ? Icons.broken_image_outlined : Icons.movie_outlined,
                size: 18,
                color: missing ? cs.onErrorContainer : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: missing ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: missing ? cs.error : cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                tooltip: 'Delete',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatProgress(int secs) {
    if (secs >= 3600) {
      final h = secs ~/ 3600;
      final m = (secs % 3600) ~/ 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
