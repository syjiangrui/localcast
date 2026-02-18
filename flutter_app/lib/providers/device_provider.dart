import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_service.dart';

class DeviceProvider extends ChangeNotifier {
  final ApiService _api;

  List<DlnaDevice> _devices = [];
  int? _selectedIndex;
  bool _scanning = false;
  String? _error;

  DeviceProvider(this._api);

  List<DlnaDevice> get devices => _devices;
  int? get selectedIndex => _selectedIndex;
  bool get scanning => _scanning;
  String? get error => _error;
  DlnaDevice? get selectedDevice =>
      _selectedIndex != null ? _devices[_selectedIndex!] : null;

  Future<void> discover() async {
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      _devices = await _api.discover();
      _selectedIndex = null;
      _scanning = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _scanning = false;
      notifyListeners();
    }
  }

  Future<bool> selectDevice(int index) async {
    _error = null;
    notifyListeners();

    try {
      await _api.selectDevice(index);
      _selectedIndex = index;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _devices = [];
    _selectedIndex = null;
    _error = null;
    notifyListeners();
  }
}
