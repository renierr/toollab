import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'treadmill_control_db.dart';
import 'treadmill_session.dart';

enum WorkoutStatus { inactive, starting, running, paused, stopped }

enum TreadmillType { ftms, pitpat, none }

class DiscoveredBleDevice {
  final String id;
  final String name;
  final List<String> services;
  final int rssi;

  DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.services,
    required this.rssi,
  });
}

class TreadmillControlState extends ChangeNotifier {
  // Constants (GATT UUIDs)
  static const String ftmsService = '00001826-0000-1000-8000-00805f9b34fb';
  static const String ftmsDataChar = '00002acd-0000-1000-8000-00805f9b34fb';
  static const String ftmsFeatureChar = '00002acc-0000-1000-8000-00805f9b34fb';
  static const String ftmsControlPointChar =
      '00002ad9-0000-1000-8000-00805f9b34fb';

  static const String pitpatService = '0000fba0-0000-1000-8000-00805f9b34fb';
  static const String pitpatNotifyChar = '0000fba2-0000-1000-8000-00805f9b34fb';
  static const String pitpatWriteChar = '0000fba1-0000-1000-8000-00805f9b34fb';

  static const String rscService = '00001814-0000-1000-8000-00805f9b34fb';
  static const String rscChar = '00002a53-0000-1000-8000-00805f9b34fb';

  static const String hrService = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String hrChar = '00002a37-0000-1000-8000-00805f9b34fb';

  static const String batteryService = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String batteryChar = '00002a19-0000-1000-8000-00805f9b34fb';

  // Scanning & Connection Status
  bool isScanning = false;
  final List<DiscoveredBleDevice> discoveredTreadmills = [];
  final List<DiscoveredBleDevice> discoveredHrms = [];

  String? treadmillDeviceId;
  String? treadmillName;
  BleConnectionState treadmillConnection = BleConnectionState.disconnected;
  TreadmillType treadmillType = TreadmillType.none;

  String? hrmDeviceId;
  String? hrmName;
  BleConnectionState hrmConnection = BleConnectionState.disconnected;

  // Resolved BLE UUIDs from Discovery
  String? _actualTreadmillService;
  String? _actualTreadmillDataChar;
  String? _actualTreadmillControlPointChar;
  String? _actualTreadmillFeatureChar;
  String? _actualTreadmillWriteChar;

  String? _actualHrmService;
  String? _actualHrmChar;
  String? _actualBatteryService;
  String? _actualBatteryChar;

  // Active Telemetry (Metrics)
  double speed = 0.0;
  double incline = 0.0;
  int heartRate = 0;
  double distance = 0.0;
  int calories = 0;
  int steps = 0;
  int elapsedTime = 0;
  int? batteryLevel;

  // Workout state
  WorkoutStatus workoutStatus = WorkoutStatus.inactive;
  bool isSimulator = false;
  bool wakeLockEnabled = false;

  // Databases & Logs
  List<WorkoutDataPoint> dataPoints = [];
  List<TreadmillSession> pastSessions = [];
  TreadmillSession? activeSession;

  // Private Subscriptions & Helpers
  StreamSubscription<BleDevice>? _scanSubscription;
  Timer? _workoutTimer;
  Timer? _pitpatHeartbeatTimer;
  WakeLockLease? _wakeLockLease;
  bool _isControlRequested = false;

  TreadmillControlState() {
    _init();
  }

  void _init() {
    UniversalBle.onConnectionChange = _onConnectionChange;
    UniversalBle.onValueChange = _onValueChange;
    loadSessions();
  }

  Future<void> loadSessions() async {
    try {
      pastSessions = await TreadmillControlDb.instance.getActiveSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('[TreadmillControl] Load sessions failed: $e');
    }
  }

  // Scanning Controls
  Future<void> startScan() async {
    if (isScanning) return;
    discoveredTreadmills.clear();
    discoveredHrms.clear();

    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      _scanSubscription?.cancel();
      _scanSubscription = UniversalBle.scanStream.listen(_onDeviceDiscovered);
      await UniversalBle.startScan();
      isScanning = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[TreadmillControl] Start scan failed: $e');
    }
  }

  Future<void> stopScan() async {
    if (!isScanning) return;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning = false;
    notifyListeners();
  }

  void _onDeviceDiscovered(BleDevice device) {
    final name = device.name ?? '';
    final services = device.services.map((s) => s.toLowerCase()).toList();

    bool isTread =
        services.contains(ftmsService) ||
        services.contains(pitpatService) ||
        name.toLowerCase().contains('treadmill') ||
        name.toLowerCase().contains('walkingpad') ||
        name.toLowerCase().contains('pitpat');

    bool isHrmDevice =
        services.contains(hrService) ||
        name.toLowerCase().contains('polar') ||
        name.toLowerCase().contains('coospo') ||
        name.toLowerCase().contains('hrm') ||
        name.toLowerCase().contains('heart rate');

    final dev = DiscoveredBleDevice(
      id: device.deviceId,
      name: name.isNotEmpty ? name : 'Unknown Device',
      services: device.services,
      rssi: device.rssi ?? 0,
    );

    if (isTread) {
      final idx = discoveredTreadmills.indexWhere((d) => d.id == dev.id);
      if (idx == -1) {
        discoveredTreadmills.add(dev);
      } else {
        discoveredTreadmills[idx] = dev;
      }
      notifyListeners();
    }

    if (isHrmDevice) {
      final idx = discoveredHrms.indexWhere((d) => d.id == dev.id);
      if (idx == -1) {
        discoveredHrms.add(dev);
      } else {
        discoveredHrms[idx] = dev;
      }
      notifyListeners();
    }
  }

  // Connection Controls
  Future<void> connectTreadmill(String deviceId, String name) async {
    treadmillDeviceId = deviceId;
    treadmillName = name;
    treadmillConnection = BleConnectionState.connecting;
    notifyListeners();
    await stopScan();
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      treadmillConnection = BleConnectionState.disconnected;
      notifyListeners();
      debugPrint('[TreadmillControl] Connection failed: $e');
    }
  }

  Future<void> disconnectTreadmill() async {
    if (treadmillDeviceId == null) return;
    try {
      _stopPitPatHeartbeat();
      await UniversalBle.disconnect(treadmillDeviceId!);
    } catch (_) {}
  }

  Future<void> connectHrm(String deviceId, String name) async {
    hrmDeviceId = deviceId;
    hrmName = name;
    hrmConnection = BleConnectionState.connecting;
    notifyListeners();
    await stopScan();
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      hrmConnection = BleConnectionState.disconnected;
      notifyListeners();
      debugPrint('[TreadmillControl] HRM Connection failed: $e');
    }
  }

  Future<void> disconnectHrm() async {
    if (hrmDeviceId == null) return;
    try {
      await UniversalBle.disconnect(hrmDeviceId!);
    } catch (_) {}
  }

  void _onConnectionChange(
    String deviceId,
    bool isConnected,
    String? error,
  ) async {
    final state = isConnected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
    if (deviceId == treadmillDeviceId) {
      treadmillConnection = state;
      if (state == BleConnectionState.connected) {
        _isControlRequested = false;
        final services = await UniversalBle.discoverServices(deviceId);

        bool hasPitPat = false;
        bool hasFtms = false;

        _actualTreadmillService = null;
        _actualTreadmillDataChar = null;
        _actualTreadmillControlPointChar = null;
        _actualTreadmillFeatureChar = null;
        _actualTreadmillWriteChar = null;

        for (final s in services) {
          final uuid = s.uuid.toLowerCase();
          if (uuid.contains('fba0')) {
            hasPitPat = true;
            _actualTreadmillService = s.uuid;
            for (final c in s.characteristics) {
              final cUuid = c.uuid.toLowerCase();
              if (cUuid.contains('fba2')) {
                _actualTreadmillDataChar = c.uuid;
              }
              if (cUuid.contains('fba1')) {
                _actualTreadmillWriteChar = c.uuid;
              }
            }
          }
          if (uuid.contains('1826')) {
            hasFtms = true;
            _actualTreadmillService = s.uuid;
            for (final c in s.characteristics) {
              final cUuid = c.uuid.toLowerCase();
              if (cUuid.contains('2acd')) {
                _actualTreadmillDataChar = c.uuid;
              }
              if (cUuid.contains('2ad9')) {
                _actualTreadmillControlPointChar = c.uuid;
              }
              if (cUuid.contains('2acc')) {
                _actualTreadmillFeatureChar = c.uuid;
              }
            }
          }
        }

        treadmillType = hasPitPat && !hasFtms
            ? TreadmillType.pitpat
            : TreadmillType.ftms;

        _actualTreadmillService ??= treadmillType == TreadmillType.pitpat
            ? pitpatService
            : ftmsService;
        _actualTreadmillDataChar ??= treadmillType == TreadmillType.pitpat
            ? pitpatNotifyChar
            : ftmsDataChar;
        _actualTreadmillControlPointChar ??= ftmsControlPointChar;
        _actualTreadmillWriteChar ??= pitpatWriteChar;

        if (treadmillType == TreadmillType.pitpat) {
          await UniversalBle.subscribeNotifications(
            deviceId,
            _actualTreadmillService!,
            _actualTreadmillDataChar!,
          );
          _startPitPatHeartbeat();
        } else {
          await UniversalBle.subscribeNotifications(
            deviceId,
            _actualTreadmillService!,
            _actualTreadmillDataChar!,
          );

          if (_actualTreadmillControlPointChar != null) {
            try {
              await UniversalBle.subscribeIndications(
                deviceId,
                _actualTreadmillService!,
                _actualTreadmillControlPointChar!,
              );
            } catch (_) {}
          }

          try {
            await UniversalBle.read(
              deviceId,
              _actualTreadmillService!,
              _actualTreadmillFeatureChar ?? ftmsFeatureChar,
            );
          } catch (_) {}
        }

        // Check if RSC service is also available for cadence
        if (services.any((s) => s.uuid.toLowerCase().contains('1814'))) {
          try {
            final rscServiceDiscovered = services.firstWhere(
              (s) => s.uuid.toLowerCase().contains('1814'),
            );
            final rscCharDiscovered = rscServiceDiscovered.characteristics
                .firstWhere((c) => c.uuid.toLowerCase().contains('2a53'));
            await UniversalBle.subscribeNotifications(
              deviceId,
              rscServiceDiscovered.uuid,
              rscCharDiscovered.uuid,
            );
          } catch (_) {}
        }
      } else if (state == BleConnectionState.disconnected) {
        _stopPitPatHeartbeat();
        treadmillType = TreadmillType.none;
        _isControlRequested = false;
      }
      notifyListeners();
    } else if (deviceId == hrmDeviceId) {
      hrmConnection = state;
      if (state == BleConnectionState.connected) {
        final services = await UniversalBle.discoverServices(deviceId);

        _actualHrmService = null;
        _actualHrmChar = null;
        _actualBatteryService = null;
        _actualBatteryChar = null;

        for (final s in services) {
          final uuid = s.uuid.toLowerCase();
          if (uuid.contains('180d')) {
            _actualHrmService = s.uuid;
            for (final c in s.characteristics) {
              if (c.uuid.toLowerCase().contains('2a37')) {
                _actualHrmChar = c.uuid;
              }
            }
          }
          if (uuid.contains('180f')) {
            _actualBatteryService = s.uuid;
            for (final c in s.characteristics) {
              if (c.uuid.toLowerCase().contains('2a19')) {
                _actualBatteryChar = c.uuid;
              }
            }
          }
        }

        _actualHrmService ??= hrService;
        _actualHrmChar ??= hrChar;
        _actualBatteryService ??= batteryService;
        _actualBatteryChar ??= batteryChar;

        await UniversalBle.subscribeNotifications(
          deviceId,
          _actualHrmService!,
          _actualHrmChar!,
        );
        try {
          await UniversalBle.subscribeNotifications(
            deviceId,
            _actualBatteryService!,
            _actualBatteryChar!,
          );
          final bat = await UniversalBle.read(
            deviceId,
            _actualBatteryService!,
            _actualBatteryChar!,
          );
          if (bat.isNotEmpty) {
            batteryLevel = bat[0];
          }
        } catch (_) {}
      } else if (state == BleConnectionState.disconnected) {
        batteryLevel = null;
      }
      notifyListeners();
    }
  }

  // Incoming GATT Data Parsing
  void _onValueChange(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  ) {
    final charId = characteristicId.toLowerCase();
    if (deviceId == treadmillDeviceId) {
      if (charId.contains('2acd')) {
        _parseFtmsData(value);
      } else if (charId.contains('fba2')) {
        _parsePitPatData(value);
      } else if (charId.contains('2a53')) {
        _parseRscData(value);
      }
    } else if (deviceId == hrmDeviceId) {
      if (charId.contains('2a37')) {
        _parseHrmData(value);
      } else if (charId.contains('2a19') && value.isNotEmpty) {
        batteryLevel = value[0];
        notifyListeners();
      }
    }
  }

  void _parseHrmData(Uint8List value) {
    if (value.isEmpty) return;
    final flags = value[0];
    final is16bit = (flags & 0x01) == 1;
    int hr = 0;
    if (is16bit && value.length >= 3) {
      hr = ByteData.sublistView(value).getUint16(1, Endian.little);
    } else if (value.length >= 2) {
      hr = value[1];
    }
    if (hr > 0) {
      heartRate = hr;
      notifyListeners();
    }
  }

  void _parseRscData(Uint8List value) {
    if (value.length < 4) return;
    try {
      final flags = value[0];
      int offset = 3;

      offset += 1; // skip cadence

      if ((flags & 0x01) != 0 && value.length >= offset + 2) {
        offset += 2;
      }

      if ((flags & 0x02) != 0 && value.length >= offset + 4) {
        offset += 4;
      }

      final remaining = value.length - offset;
      if (remaining >= 4) {
        steps = ByteData.sublistView(value).getUint32(offset, Endian.little);
      } else if (remaining >= 2) {
        steps = ByteData.sublistView(value).getUint16(offset, Endian.little);
      }
      notifyListeners();
    } catch (_) {}
  }

  void _parseFtmsData(Uint8List value) {
    if (value.length < 4) return;
    final flags = ByteData.sublistView(value).getUint16(0, Endian.little);
    int offset = 2;

    speed =
        ByteData.sublistView(value).getUint16(offset, Endian.little) / 100.0;
    offset += 2;

    if ((flags & (1 << 1)) != 0 && value.length >= offset + 2) {
      offset += 2;
    }

    if ((flags & (1 << 2)) != 0 && value.length >= offset + 3) {
      final d1 = value[offset];
      final d2 = value[offset + 1];
      final d3 = value[offset + 2];
      distance = (d1 | (d2 << 8) | (d3 << 16)) / 1000.0;
      offset += 3;
    }

    if ((flags & (1 << 3)) != 0 && value.length >= offset + 2) {
      incline =
          ByteData.sublistView(value).getInt16(offset, Endian.little) / 10.0;
      offset += 4; // Skip inclination + suspension
    }

    if ((flags & (1 << 4)) != 0 && value.length >= offset + 4) {
      offset += 4;
    }

    if ((flags & (1 << 5)) != 0 && value.length >= offset + 1) {
      offset += 1;
    }

    if ((flags & (1 << 6)) != 0 && value.length >= offset + 1) {
      offset += 1;
    }

    if ((flags & (1 << 7)) != 0 && value.length >= offset + 5) {
      calories = ByteData.sublistView(value).getUint16(offset, Endian.little);
      offset += 5;
    }

    if ((flags & (1 << 8)) != 0 && value.length >= offset + 1) {
      // If treadmill has handgrip sensor, use it as fallback heart rate if no dedicated HRM
      if (hrmConnection != BleConnectionState.connected) {
        heartRate = value[offset];
      }
      offset += 1;
    }

    if ((flags & (1 << 9)) != 0 && value.length >= offset + 1) {
      offset += 1;
    }

    if ((flags & (1 << 10)) != 0 && value.length >= offset + 2) {
      // elapsed time from treadmill, only override if workout is running
      if (workoutStatus == WorkoutStatus.running) {
        elapsedTime = ByteData.sublistView(
          value,
        ).getUint16(offset, Endian.little);
      }
    }
    notifyListeners();
  }

  void _parsePitPatData(Uint8List value) {
    if (value.length < 31) return;
    int rawSpeed = (value[3] << 8) | value[4];
    int rawDist =
        (value[7] << 24) | (value[8] << 16) | (value[9] << 8) | value[10];
    int stepsVal =
        (value[14] << 24) | (value[15] << 16) | (value[16] << 8) | value[17];
    int cals = (value[18] << 8) | value[19];
    int durationMs =
        (value[20] << 24) | (value[21] << 16) | (value[22] << 8) | value[23];

    int flags = value[26];
    int runningStateBits = flags & 24;

    speed = rawSpeed / 1000.0;
    distance = rawDist / 1000.0;
    calories = cals;
    steps = stepsVal;
    if (workoutStatus == WorkoutStatus.running) {
      elapsedTime = (durationMs / 1000).round();
    }

    if (runningStateBits == 24) {
      workoutStatus = WorkoutStatus.starting;
    } else if (runningStateBits == 8) {
      workoutStatus = WorkoutStatus.running;
    } else if (runningStateBits == 16) {
      workoutStatus = WorkoutStatus.paused;
    } else {
      workoutStatus = WorkoutStatus.inactive;
    }

    notifyListeners();
  }

  // Workout Controls (Start, Incline, Speed)
  Future<void> startWorkout() async {
    workoutStatus = WorkoutStatus.running;
    elapsedTime = 0;
    distance = 0.0;
    calories = 0;
    steps = 0;
    dataPoints.clear();

    // Automatically trigger WakeLock
    _setWakeLock(true);

    if (isSimulator) {
      speed = 3.0;
      incline = 0.0;
      _startTimer();
    } else {
      if (treadmillConnection == BleConnectionState.connected &&
          treadmillDeviceId != null) {
        if (treadmillType == TreadmillType.pitpat) {
          final pkt = makePitPatPacket('START', speed > 0 ? speed : 1.0);
          await UniversalBle.write(
            treadmillDeviceId!,
            _actualTreadmillService ?? pitpatService,
            _actualTreadmillWriteChar ?? pitpatWriteChar,
            pkt,
            withoutResponse: true,
          );
        } else {
          await _sendFtmsControl(0x07, []); // Start command
        }
      }
      _startTimer();
    }
    notifyListeners();
  }

  Future<void> pauseWorkout() async {
    workoutStatus = WorkoutStatus.paused;
    _workoutTimer?.cancel();
    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType == TreadmillType.pitpat) {
        final pkt = makePitPatPacket('PAUSE', speed);
        await UniversalBle.write(
          treadmillDeviceId!,
          _actualTreadmillService ?? pitpatService,
          _actualTreadmillWriteChar ?? pitpatWriteChar,
          pkt,
          withoutResponse: true,
        );
      } else {
        await _sendFtmsControl(0x08, [0x02]); // Pause stop command
      }
    }
    notifyListeners();
  }

  Future<void> stopWorkout() async {
    workoutStatus = WorkoutStatus.stopped;
    _workoutTimer?.cancel();
    _workoutTimer = null;

    // Disable WakeLock
    _setWakeLock(false);

    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType == TreadmillType.pitpat) {
        final pkt = makePitPatPacket('STOP', speed);
        await UniversalBle.write(
          treadmillDeviceId!,
          _actualTreadmillService ?? pitpatService,
          _actualTreadmillWriteChar ?? pitpatWriteChar,
          pkt,
          withoutResponse: true,
        );
      } else {
        await _sendFtmsControl(0x08, [0x01]); // Stop command
      }
    }

    // Save session to DB
    if (dataPoints.isNotEmpty) {
      final double maxSpd = dataPoints.isEmpty
          ? 0.0
          : dataPoints.map((d) => d.speed).reduce(max);
      final double avgSpd = dataPoints.isEmpty
          ? 0.0
          : dataPoints.map((d) => d.speed).reduce((a, b) => a + b) /
                dataPoints.length;
      final double avgHr = dataPoints.isEmpty
          ? 0.0
          : dataPoints.map((d) => d.heartRate).reduce((a, b) => a + b) /
                dataPoints.length;
      final double maxHr = dataPoints.isEmpty
          ? 0.0
          : dataPoints.map((d) => d.heartRate).reduce(max).toDouble();

      final session = TreadmillSession(
        uid: '',
        startTime: DateTime.now().millisecondsSinceEpoch - (elapsedTime * 1000),
        endTime: DateTime.now().millisecondsSinceEpoch,
        avgSpeed: avgSpd,
        maxSpeed: maxSpd,
        distance: distance,
        calories: calories,
        steps: steps,
        avgHeartRate: avgHr,
        maxHeartRate: maxHr,
        elapsedTime: elapsedTime,
        dataPoints: List.from(dataPoints),
        synced: false,
        deleted: false,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await TreadmillControlDb.instance.saveSession(session);
      await loadSessions();
    }

    workoutStatus = WorkoutStatus.inactive;
    speed = 0.0;
    incline = 0.0;
    notifyListeners();
  }

  Future<void> adjustSpeed(double delta) async {
    final double targetSpeed = (speed + delta).clamp(0.0, 20.0);
    speed = targetSpeed;
    notifyListeners();

    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType == TreadmillType.pitpat) {
        final pkt = makePitPatPacket('SPEED', targetSpeed);
        await UniversalBle.write(
          treadmillDeviceId!,
          _actualTreadmillService ?? pitpatService,
          _actualTreadmillWriteChar ?? pitpatWriteChar,
          pkt,
          withoutResponse: true,
        );
      } else {
        final speedUint16 = (targetSpeed * 100).round();
        await _sendFtmsControl(0x02, [
          speedUint16 & 0xff,
          (speedUint16 >> 8) & 0xff,
        ]);
      }
    }
  }

  Future<void> adjustIncline(double delta) async {
    final double targetIncline = (incline + delta).clamp(-3.0, 15.0);
    incline = targetIncline;
    notifyListeners();

    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType != TreadmillType.pitpat) {
        final inclineInt16 = (targetIncline * 10).round();
        await _sendFtmsControl(0x03, [
          inclineInt16 & 0xff,
          (inclineInt16 >> 8) & 0xff,
        ]);
      }
    }
  }

  // WakeLock Helper
  Future<void> _setWakeLock(bool enable) async {
    if (enable) {
      if (_wakeLockLease == null) {
        try {
          _wakeLockLease = await PowerWakeLockService.acquireFull();
          wakeLockEnabled = true;
          notifyListeners();
        } catch (_) {}
      }
    } else {
      if (_wakeLockLease != null) {
        await _wakeLockLease!.release();
        _wakeLockLease = null;
        wakeLockEnabled = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleWakeLock() async {
    await _setWakeLock(!wakeLockEnabled);
  }

  // Timer Tick & Simulator Mode
  void _startTimer() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedTime++;
      if (isSimulator) {
        distance += speed / 3600.0;
        calories += ((speed / 6.0) * (1 + incline.abs() / 10.0)).round();
        steps += (speed > 0 ? (80 + speed * 10) / 60.0 : 0.0).round();
        heartRate = (70 + speed * 6 + Random().nextInt(6)).round();
      }

      dataPoints.add(
        WorkoutDataPoint(
          timestamp: elapsedTime,
          speed: speed,
          incline: incline,
          heartRate: heartRate,
          distance: distance,
          calories: calories,
          steps: steps,
        ),
      );

      notifyListeners();
    });
  }

  void toggleSimulator(bool enable) {
    isSimulator = enable;
    if (enable) {
      disconnectTreadmill();
    } else {
      if (workoutStatus == WorkoutStatus.running) {
        stopWorkout();
      }
    }
    notifyListeners();
  }

  // PitPat Commands & Heartbeats
  void _startPitPatHeartbeat() {
    _pitpatHeartbeatTimer?.cancel();
    final heartbeatPacket = Uint8List.fromList([0x6a, 0x05, 0xfd, 0xf8, 0x43]);
    _pitpatHeartbeatTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (treadmillConnection == BleConnectionState.connected &&
          treadmillDeviceId != null) {
        try {
          await UniversalBle.write(
            treadmillDeviceId!,
            _actualTreadmillService ?? pitpatService,
            _actualTreadmillWriteChar ?? pitpatWriteChar,
            heartbeatPacket,
            withoutResponse: true,
          );
        } catch (_) {}
      } else {
        _stopPitPatHeartbeat();
      }
    });
  }

  void _stopPitPatHeartbeat() {
    _pitpatHeartbeatTimer?.cancel();
    _pitpatHeartbeatTimer = null;
  }

  Uint8List makePitPatPacket(String action, double speedKph) {
    final arr = Uint8List(23);
    arr[0] = 0x6a;
    arr[1] = 0x17;

    final int speedUnit = (speedKph * 1000).round();
    arr[6] = (speedUnit >> 8) & 0xff;
    arr[7] = speedUnit & 0xff;

    arr[8] = action == 'SPEED' ? 0x05 : 0x01;
    arr[9] = 0x00;
    arr[10] = 80;
    arr[11] = 0x00;

    int cmd = action == 'PAUSE' ? 2 : (action == 'STOP' ? 0 : 4);
    arr[12] = cmd & 0xf7;

    const int userId = 58965456623;
    for (int i = 0; i < 8; ++i) {
      arr[13 + i] = (userId >> (56 - i * 8)) & 0xff;
    }

    int checksum = 0;
    for (int i = 1; i <= 20; ++i) {
      checksum ^= arr[i];
    }
    arr[21] = checksum;
    arr[22] = 0x43;

    return arr;
  }

  Future<void> _sendFtmsControl(int command, List<int> params) async {
    if (treadmillDeviceId == null) return;
    final service = _actualTreadmillService ?? ftmsService;
    final cpChar = _actualTreadmillControlPointChar ?? ftmsControlPointChar;

    if (!_isControlRequested) {
      try {
        await UniversalBle.write(
          treadmillDeviceId!,
          service,
          cpChar,
          Uint8List.fromList([0x00]),
        );
        _isControlRequested = true;
      } catch (_) {}
    }

    final payload = Uint8List.fromList([command, ...params]);
    try {
      await UniversalBle.write(treadmillDeviceId!, service, cpChar, payload);
    } catch (_) {}
  }

  // Delete / Clear Logs
  Future<void> deleteSession(int id) async {
    await TreadmillControlDb.instance.softDeleteSession(id);
    await loadSessions();
  }

  Future<void> importSessions(List<TreadmillSession> sessions) async {
    await TreadmillControlDb.instance.importSessions(sessions);
    await loadSessions();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _pitpatHeartbeatTimer?.cancel();
    _scanSubscription?.cancel();
    _setWakeLock(false);
    super.dispose();
  }
}
