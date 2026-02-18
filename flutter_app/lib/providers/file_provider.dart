import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class FileProvider extends ChangeNotifier {
  final ApiService _api;

  String? _filePath;
  String? _fileName;
  int? _fileSize;
  String? _mimeType;
  bool _loading = false;
  String? _error;

  FileProvider(this._api);

  String? get filePath => _filePath;
  String? get fileName => _fileName;
  int? get fileSize => _fileSize;
  String? get mimeType => _mimeType;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasFile => _filePath != null;

  Future<bool> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'webm'],
    );

    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    return selectFile(path);
  }

  Future<bool> selectFile(String path) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final info = await _api.selectFile(path);
      _filePath = path;
      _fileName = info['file_name'] as String?;
      _fileSize = info['file_size'] as int?;
      _mimeType = info['mime_type'] as String?;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _filePath = null;
    _fileName = null;
    _fileSize = null;
    _mimeType = null;
    _error = null;
    notifyListeners();
  }
}
