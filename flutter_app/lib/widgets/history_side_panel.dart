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
            child: Text(
              s.historyTitle,
              style: Theme.of(context).textTheme.titleMedium,
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
    final missing = !entry.fileExists;
    final subtitleParts = <String>[entry.filePath];
    if (missing) {
      subtitleParts.add(s.historyFileMissing);
    } else if (entry.lastProgressSecs > 0) {
      subtitleParts.add(_formatProgress(entry.lastProgressSecs));
    }

    return Opacity(
      opacity: missing ? 0.5 : 1.0,
      child: ListTile(
        dense: true,
        leading: Icon(
          missing ? Icons.broken_image_outlined : Icons.movie_outlined,
          size: 20,
        ),
        title: Text(
          entry.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitleParts.join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: missing
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
        onTap: missing ? null : onTap,
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
