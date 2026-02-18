import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../l10n/app_localizations.dart';
import '../providers/file_provider.dart';
import 'device_list_screen.dart';

const _supportedExtensions = ['mp4', 'mkv', 'avi', 'webm'];

class FilePickerScreen extends StatefulWidget {
  const FilePickerScreen({super.key});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        centerTitle: true,
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragOver = true),
        onDragExited: (_) => setState(() => _isDragOver = false),
        onDragDone: (details) {
          setState(() => _isDragOver = false);
          _handleDrop(details);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: _isDragOver
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
            color: _isDragOver
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05)
                : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDragOver
                        ? Icons.file_download
                        : Icons.video_file_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isDragOver ? s.dropVideoHere : s.selectVideoTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.supportedFormats,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (fileProvider.hasFile) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.movie),
                        title: Text(fileProvider.fileName ?? ''),
                        subtitle:
                            Text(_formatSize(fileProvider.fileSize ?? 0)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => fileProvider.reset(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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
