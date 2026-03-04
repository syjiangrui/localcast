import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';

class DeviceProvider extends ChangeNotifier {
  final ApiService _api;
  final DeviceSseService _sse;

  List<DlnaDevice> _devices = [];
  int? _selectedIndex;
  bool _scanning = false;
  String? _error;
  StreamSubscription<List<DlnaDevice>>? _sseSubscription;

  DeviceProvider(this._api, this._sse);

  List<DlnaDevice> get devices => _devices;
  int? get selectedIndex => _selectedIndex;
  bool get scanning => _scanning;
  String? get error => _error;
  DlnaDevice? get selectedDevice =>
      _selectedIndex != null ? _devices[_selectedIndex!] : null;

  /// Fetch the current cached device list from backend.
  /// On first call this blocks until backend completes its first scan.
  Future<void> discover() async {
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      _devices = await _api.discover();
      _selectedIndex = null;
      _scanning = false;
      _subscribeSse();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _scanning = false;
      notifyListeners();
    }
  }

  /// Force a synchronous SSDP scan (~5s). Used for manual refresh button.
  Future<void> refresh() async {
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      _devices = await _api.discoverRefresh();
      _selectedIndex = null;
      _scanning = false;
      _subscribeSse();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _scanning = false;
      notifyListeners();
    }
  }

  void _subscribeSse() {
    _unsubscribeSse();
    _sseSubscription = _sse.deviceStream.listen(
      (devices) {
        _devices = devices;
        // If a device was selected, try to keep the selection valid
        if (_selectedIndex != null && _selectedIndex! >= _devices.length) {
          _selectedIndex = null;
        }
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
    _unsubscribeSse();
    _devices = [];
    _selectedIndex = null;
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
