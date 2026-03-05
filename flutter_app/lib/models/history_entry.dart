class HistoryEntry {
  final int? id;
  final String filePath;
  final String fileName;
  final int lastProgressSecs;
  final DateTime lastPlayedAt;
  bool fileExists;

  HistoryEntry({
    this.id,
    required this.filePath,
    required this.fileName,
    this.lastProgressSecs = 0,
    required this.lastPlayedAt,
    this.fileExists = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'last_progress_secs': lastProgressSecs,
      'last_played_at': lastPlayedAt.toIso8601String(),
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int?,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      lastProgressSecs: map['last_progress_secs'] as int? ?? 0,
      lastPlayedAt: DateTime.parse(map['last_played_at'] as String),
    );
  }
}
