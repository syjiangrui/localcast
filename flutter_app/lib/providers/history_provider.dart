import 'dart:io';

import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryService _service;
  List<HistoryEntry> _entries = [];

  HistoryProvider(this._service);

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _entries = await _service.getAll();
    notifyListeners();
    _checkFilesExist();
  }

  /// Check file existence in the background, then notify once done.
  Future<void> _checkFilesExist() async {
    bool changed = false;
    await Future.wait(_entries.map((entry) async {
      final exists = await File(entry.filePath).exists();
      if (!exists && entry.fileExists) {
        entry.fileExists = false;
        changed = true;
      }
    }));
    if (changed) notifyListeners();
  }

  Future<void> recordFileSelected(String filePath, String fileName) async {
    await _service.upsert(HistoryEntry(
      filePath: filePath,
      fileName: fileName,
      lastProgressSecs: 0,
      lastPlayedAt: DateTime.now(),
    ));
    await load();
  }

  Future<void> updateProgress(String filePath, int secs) async {
    await _service.updateProgress(filePath, secs);
    _entries = await _service.getAll();
    notifyListeners();
  }

  Future<void> deleteEntry(int id) async {
    await _service.delete(id);
    await load();
  }
}
