import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/status.dart';

class SseService {
  static const String _baseUrl = 'http://127.0.0.1:8080';

  http.Client? _client;
  StreamController<PlaybackStatus>? _controller;

  Stream<PlaybackStatus> get statusStream {
    _controller ??= StreamController<PlaybackStatus>.broadcast();
    _connect();
    return _controller!.stream;
  }

  void _connect() async {
    _client?.close();
    _client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse('$_baseUrl/api/status/stream'));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String buffer = '';
      await for (final line in stream) {
        if (line.startsWith('data:')) {
          buffer = line.substring(5).trim();
        } else if (line.isEmpty && buffer.isNotEmpty) {
          try {
            final json = jsonDecode(buffer) as Map<String, dynamic>;
            final status = PlaybackStatus.fromJson(json);
            _controller?.add(status);
          } catch (_) {
            // Skip malformed events
          }
          buffer = '';
        }
      }
    } catch (e) {
      // Connection lost - will be retried by consumer
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
    _controller?.close();
    _controller = null;
  }
}
