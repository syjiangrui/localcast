import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/status.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8080';

  Future<Map<String, dynamic>> selectFile(String filePath) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/select-file'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'file_path': filePath}),
    );
    return _handleResponse(response);
  }

  Future<List<DlnaDevice>> discover() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/discover'));
    final data = _handleResponse(response);
    final devices = (data['devices'] as List)
        .map((d) => DlnaDevice.fromJson(d as Map<String, dynamic>))
        .toList();
    return devices;
  }

  Future<void> selectDevice(int deviceIndex) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/select-device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_index': deviceIndex}),
    );
    _handleResponse(response);
  }

  Future<void> cast() async {
    final response = await http.post(Uri.parse('$_baseUrl/api/cast'));
    _handleResponse(response);
  }

  Future<void> play() async {
    final response = await http.post(Uri.parse('$_baseUrl/api/play'));
    _handleResponse(response);
  }

  Future<void> pause() async {
    final response = await http.post(Uri.parse('$_baseUrl/api/pause'));
    _handleResponse(response);
  }

  Future<void> stop() async {
    final response = await http.post(Uri.parse('$_baseUrl/api/stop'));
    _handleResponse(response);
  }

  Future<void> seek(int positionSecs) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/seek'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'position_secs': positionSecs}),
    );
    _handleResponse(response);
  }

  Future<PlaybackStatus> getStatus() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/status'));
    final data = _handleResponse(response);
    return PlaybackStatus.fromJson(data);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? 'Unknown error');
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
