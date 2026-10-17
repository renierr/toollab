import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiSample {
  WifiSample({
    required this.x,
    required this.y,
    required this.ssid,
    required this.bssid,
    required this.rssi,
  });

  final int x;
  final int y;
  final String ssid;
  final String bssid;
  final int rssi;
  final DateTime time = DateTime.now();
}

class WifiHeatmapState extends ChangeNotifier {
  WifiHeatmapState() {
    _supported = !kIsWeb && (Platform.isAndroid);
  }

  bool _supported = false;
  bool get isSupported => _supported;

  int cols = 12;
  int rows = 8;

  List<WiFiAccessPoint> scanned = const [];
  String? selectedSsid;
  bool scanning = false;
  String? error;

  final List<WifiSample> _samples = [];
  List<WifiSample> get samples => List.unmodifiable(_samples);

  bool showHeatmap = true;

  Future<void> scan() async {
    if (!_supported) {
      error = 'WiFi scanning is only supported on Android.';
      notifyListeners();
      return;
    }
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canStart != CanStartScan.yes) {
        error = _canStartMessage(canStart);
        scanning = false;
        notifyListeners();
        return;
      }
      await WiFiScan.instance.startScan();
      final canGet = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGet != CanGetScannedResults.yes) {
        error = _canGetMessage(canGet);
        scanning = false;
        notifyListeners();
        return;
      }
      final results = await WiFiScan.instance.getScannedResults();
      scanned = results;
      final keys = results
          .map((a) => a.ssid.isNotEmpty ? a.ssid : a.bssid)
          .toSet();
      if (selectedSsid == null || !keys.contains(selectedSsid)) {
        if (results.isNotEmpty) {
          final strongest = results.reduce(
            (a, b) => a.level > b.level ? a : b,
          );
          selectedSsid = strongest.ssid.isNotEmpty
              ? strongest.ssid
              : strongest.bssid;
        } else {
          selectedSsid = null;
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void selectNetwork(String ssid) {
    selectedSsid = ssid;
    notifyListeners();
  }

  Future<void> recordSample(int x, int y) async {
    if (scanned.isEmpty) await scan();
    if (scanned.isEmpty) return;
    WiFiAccessPoint? ap;
    if (selectedSsid != null) {
      for (final a in scanned) {
        final key = a.ssid.isNotEmpty ? a.ssid : a.bssid;
        if (key == selectedSsid) {
          ap = a;
          break;
        }
      }
    }
    ap ??= scanned.reduce((a, b) => a.level > b.level ? a : b);
    final ssid = ap.ssid.isNotEmpty ? ap.ssid : ap.bssid;
    selectedSsid ??= ssid;
    // Replace existing sample at same cell for same network.
    _samples.removeWhere((s) => s.x == x && s.y == y && s.ssid == ssid);
    _samples.add(
      WifiSample(x: x, y: y, ssid: ssid, bssid: ap.bssid, rssi: ap.level),
    );
    notifyListeners();
  }

  void clearSamples() {
    _samples.clear();
    notifyListeners();
  }

  void toggleHeatmap(bool v) {
    showHeatmap = v;
    notifyListeners();
  }

  void setGridSize(int c, int r) {
    cols = c.clamp(4, 24);
    rows = r.clamp(3, 16);
    _samples.clear();
    notifyListeners();
  }

  String _canStartMessage(CanStartScan c) {
    switch (c) {
      case CanStartScan.notSupported:
        return 'WiFi scanning not supported on this device.';
      case CanStartScan.noLocationPermissionRequired:
      case CanStartScan.noLocationPermissionDenied:
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return 'Location permission is required to scan Wi-Fi.';
      case CanStartScan.noLocationServiceDisabled:
        return 'Enable location services to scan Wi-Fi.';
      case CanStartScan.failed:
        return 'Failed to start scan.';
      case CanStartScan.yes:
        return '';
    }
  }

  String _canGetMessage(CanGetScannedResults c) {
    switch (c) {
      case CanGetScannedResults.notSupported:
        return 'WiFi scanning not supported on this device.';
      case CanGetScannedResults.noLocationPermissionRequired:
      case CanGetScannedResults.noLocationPermissionDenied:
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return 'Location permission is required to read Wi-Fi results.';
      case CanGetScannedResults.noLocationServiceDisabled:
        return 'Enable location services to read Wi-Fi results.';
      case CanGetScannedResults.yes:
        return '';
    }
  }
}
