import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart'
    as classic;
import 'package:tool_lab/services/database_service.dart';
import 'data/device_parser.dart';
import 'data/scanned_device.dart';

enum DeviceFilter { highConfidence, beacons, unknown, recent, strongSignal }

class DeviceHistoryEntry {
  DateTime firstSeen;
  DateTime lastSeen;
  int sightings;
  int? strongestRssi;
  double? averageRssi;
  int rssiSampleCount;

  DeviceHistoryEntry({
    required this.firstSeen,
    required this.lastSeen,
    this.sightings = 1,
    this.strongestRssi,
    this.averageRssi,
    this.rssiSampleCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'sightings': sightings,
    'strongestRssi': strongestRssi,
    'averageRssi': averageRssi,
    'rssiSampleCount': rssiSampleCount,
  };

  factory DeviceHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DeviceHistoryEntry(
        firstSeen: DateTime.parse(json['firstSeen'] as String),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        sightings: json['sightings'] as int? ?? 1,
        strongestRssi: json['strongestRssi'] as int?,
        averageRssi: (json['averageRssi'] as num?)?.toDouble(),
        rssiSampleCount: json['rssiSampleCount'] as int? ?? 0,
      );
}

class BluetoothScannerState extends ChangeNotifier {
  bool _isScanning = false;
  bool _isBluetoothOn = false;
  bool _permissionGranted = false;
  AvailabilityState _availability = AvailabilityState.unknown;
  final Map<String, ScannedDevice> _devices = {};
  final Map<String, DeviceHistoryEntry> _history = {};
  final Set<DeviceFilter> _activeFilters = {};
  final Set<String> _collapsedCategories = {};
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;
  String? _error;
  int _deviceCount = 0;

  final classic.FlutterBluetoothClassic _classicPlugin =
      classic.FlutterBluetoothClassic();
  Timer? _classicPollTimer;

  bool get isScanning => _isScanning;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get permissionGranted => _permissionGranted;
  AvailabilityState get availability => _availability;
  Map<String, ScannedDevice> get devices => Map.unmodifiable(_devices);
  Map<String, DeviceHistoryEntry> get history => Map.unmodifiable(_history);
  Set<DeviceFilter> get activeFilters => Set.unmodifiable(_activeFilters);
  Set<String> get collapsedCategories => Set.unmodifiable(_collapsedCategories);
  String? get error => _error;
  int get deviceCount => _deviceCount;

  BluetoothScannerState() {
    _init();
  }

  Future<void> _init() async {
    _availabilitySubscription = UniversalBle.availabilityStream.listen(
      _onAvailabilityChanged,
    );
    final state = await UniversalBle.getBluetoothAvailabilityState();
    _onAvailabilityChanged(state);
    await _loadHistory();
  }

  void _onAvailabilityChanged(AvailabilityState state) {
    _availability = state;
    _isBluetoothOn = state == AvailabilityState.poweredOn;
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      _permissionGranted = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Permission denied: $e';
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    if (!_permissionGranted) {
      await requestPermissions();
      if (!_permissionGranted) return;
    }

    if (!_isBluetoothOn) {
      _error = 'Bluetooth is not enabled';
      notifyListeners();
      return;
    }

    try {
      _scanSubscription?.cancel();
      _scanSubscription = UniversalBle.scanStream.listen(
        _onDeviceDiscovered,
        onError: (e) {
          _error = 'Scan error: $e';
          _stopScanInternal();
          notifyListeners();
        },
      );

      await UniversalBle.startScan(
        platformConfig: PlatformConfig(
          android: AndroidOptions(scanMode: AndroidScanMode.lowLatency),
        ),
      );

      await _startClassicScan();
      _isScanning = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start scan: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await _stopScanInternal();
  }

  Future<void> _stopScanInternal() async {
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await _stopClassicScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> _startClassicScan() async {
    await _loadClassicDevices();
    _classicPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadClassicDevices(),
    );
  }

  Future<void> _stopClassicScan() async {
    _classicPollTimer?.cancel();
    _classicPollTimer = null;
    try {
      await _classicPlugin.stopDiscovery();
    } catch (_) {}
  }

  Future<void> _loadClassicDevices() async {
    try {
      await _classicPlugin.startDiscovery();
      final paired = await _classicPlugin.getPairedDevices();
      for (final device in paired) {
        final parsed = DeviceParser.parseClassicDevice(device);
        _devices[parsed.id] = parsed;
      }
      _deviceCount = _devices.length;
      notifyListeners();
    } catch (_) {}
  }

  void _onDeviceDiscovered(BleDevice bleDevice) {
    final existing = _devices[bleDevice.deviceId];
    final device = DeviceParser.parseBleDevice(bleDevice, existing);

    _updateHistory(device);
    _devices[device.id] = device;
    _deviceCount = _devices.length;
    notifyListeners();
  }

  void _updateHistory(ScannedDevice device) {
    final now = DateTime.now();
    final existing = _history[device.fingerprint];

    if (existing == null) {
      _history[device.fingerprint] = DeviceHistoryEntry(
        firstSeen: now,
        lastSeen: now,
        strongestRssi: device.rssi,
        averageRssi: device.rssi.toDouble(),
        rssiSampleCount: 1,
      );
      return;
    }

    existing.lastSeen = now;
    if (now.difference(existing.lastSeen).inHours >= 8) {
      existing.sightings += 1;
    }

    if (existing.strongestRssi == null ||
        device.rssi > existing.strongestRssi!) {
      existing.strongestRssi = device.rssi;
    }

    final avg = existing.averageRssi ?? device.rssi.toDouble();
    existing.averageRssi =
        (avg * existing.rssiSampleCount + device.rssi) /
        (existing.rssiSampleCount + 1);
    existing.rssiSampleCount += 1;

    _persistHistory();
  }

  void clearDevices() {
    _devices.clear();
    _collapsedCategories.clear();
    _deviceCount = 0;
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    DatabaseService.instance.setSetting('bluetooth-scanner', 'history', '{}');
    notifyListeners();
  }

  void toggleFilter(DeviceFilter filter) {
    if (_activeFilters.contains(filter)) {
      _activeFilters.remove(filter);
    } else {
      _activeFilters.add(filter);
    }
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_collapsedCategories.contains(category)) {
      _collapsedCategories.remove(category);
    } else {
      _collapsedCategories.add(category);
    }
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await DatabaseService.instance.getSetting(
        'bluetooth-scanner',
        'history',
      );
      if (raw != null && raw.isNotEmpty) {
        final parsed = _parseHistoryJson(raw);
        _history.addAll(parsed);
      }
    } catch (_) {}
  }

  Map<String, DeviceHistoryEntry> _parseHistoryJson(String raw) {
    try {
      final map = Map<String, dynamic>.from(
        Uri.splitQueryString(raw.substring(1, raw.length - 1)),
      );
      return map.map(
        (k, v) =>
            MapEntry(k, DeviceHistoryEntry.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      try {
        final decoded = Uri.tryParse(raw);
        if (decoded != null) {
          return {};
        }
      } catch (_) {}
    }
    return {};
  }

  Future<void> _persistHistory() async {
    try {
      final json = _history.map((k, v) => MapEntry(k, v.toJson()));
      await DatabaseService.instance.setSetting(
        'bluetooth-scanner',
        'history',
        json.toString(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _availabilitySubscription?.cancel();
    _classicPollTimer?.cancel();
    UniversalBle.stopScan();
    super.dispose();
  }
}
