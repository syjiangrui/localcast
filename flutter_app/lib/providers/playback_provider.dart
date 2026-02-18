import 'dart:async';
import 'package:flutter/material.dart';
import '../models/status.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';

class PlaybackProvider extends ChangeNotifier {
  final ApiService _api;
  final SseService _sse;

  PlaybackStatus _status = PlaybackStatus.empty();
  bool _casting = false;
  String? _error;
  StreamSubscription<PlaybackStatus>? _sseSubscription;

  PlaybackProvider(this._api, this._sse);

  PlaybackStatus get status => _status;
  bool get casting => _casting;
  String? get error => _error;
  bool get isPlaying => _status.playbackState == 'Playing';
  bool get isPaused => _status.playbackState == 'Paused';
  bool get isStopped => _status.playbackState == 'Stopped';

  Future<bool> cast() async {
    _casting = true;
    _error = null;
    notifyListeners();

    try {
      await _api.cast();
      _casting = false;
      _subscribeSse();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _casting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> play() async {
    try {
      await _api.play();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    try {
      await _api.pause();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    try {
      await _api.stop();
      _unsubscribeSse();
      _status = PlaybackStatus.empty();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> seek(int positionSecs) async {
    try {
      await _api.seek(positionSecs);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> seekRelative(int deltaSecs) async {
    int target = _status.elapsedSecs + deltaSecs;
    if (target < 0) target = 0;
    if (_status.durationSecs > 0 && target > _status.durationSecs) {
      target = _status.durationSecs;
    }
    await seek(target);
  }

  void _subscribeSse() {
    _unsubscribeSse();
    _sseSubscription = _sse.statusStream.listen(
      (status) {
        _status = status;
        notifyListeners();
      },
      onError: (_) {
        // SSE connection error - will be retried
      },
    );
  }

  void _unsubscribeSse() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
  }

  void reset() {
    _unsubscribeSse();
    _status = PlaybackStatus.empty();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribeSse();
    _sse.dispose();
    super.dispose();
  }
}
