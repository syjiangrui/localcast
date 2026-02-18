class PlaybackStatus {
  final String playbackState;
  final int elapsedSecs;
  final int durationSecs;
  final String elapsedDisplay;
  final String durationDisplay;
  final double progress;
  final String fileName;
  final String deviceName;

  PlaybackStatus({
    required this.playbackState,
    required this.elapsedSecs,
    required this.durationSecs,
    required this.elapsedDisplay,
    required this.durationDisplay,
    required this.progress,
    required this.fileName,
    required this.deviceName,
  });

  factory PlaybackStatus.fromJson(Map<String, dynamic> json) {
    return PlaybackStatus(
      playbackState: json['playback_state'] as String? ?? 'Stopped',
      elapsedSecs: json['elapsed_secs'] as int? ?? 0,
      durationSecs: json['duration_secs'] as int? ?? 0,
      elapsedDisplay: json['elapsed_display'] as String? ?? '00:00:00',
      durationDisplay: json['duration_display'] as String? ?? '00:00:00',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      fileName: json['file_name'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
    );
  }

  static PlaybackStatus empty() {
    return PlaybackStatus(
      playbackState: 'Stopped',
      elapsedSecs: 0,
      durationSecs: 0,
      elapsedDisplay: '00:00:00',
      durationDisplay: '00:00:00',
      progress: 0.0,
      fileName: '',
      deviceName: '',
    );
  }
}
