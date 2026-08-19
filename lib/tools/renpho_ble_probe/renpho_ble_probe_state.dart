import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:universal_ble/universal_ble.dart';

import 'config.dart';
import 'renpho_measurement.dart';
import 'renpho_measurement_db.dart';

class RenphoBleProbeState extends ChangeNotifier {
  static const scaleMacAddress = '60:30:F2:74:22:06';
  static const _service = '00001a10-0000-1000-8000-00805f9b34fb';
  static const _write = '00002a11-0000-1000-8000-00805f9b34fb';
  final _devices = <String, BleDevice>{};
  final _frames = <Map<String, String>>[];
  final _fragments = <int, List<int>>{};
  StreamSubscription<BleDevice>? _scanSubscription;
  final _subscriptions = <StreamSubscription<Uint8List>>[];
  Timer? _stageTimer;
  WakeLockLease? _wakeLock;
  bool _scanning = false, _connecting = false, _ready = false, _saving = false;
  String? _deviceId, _error, _status;
  double? _liveWeightKg;
  RenphoMeasurement? _latest;
  RenphoProfile _profile = RenphoProfile(
    name: 'User',
    sex: 'male',
    heightCm: 173,
    birthDate: DateTime(1976, 1, 1),
  );
  List<RenphoMeasurement> _history = [];
  int _stage = 0;

  bool get scanning => _scanning;
  bool get connecting => _connecting;
  bool get ready => _ready;
  bool get saving => _saving;
  String? get error => _error;
  String get status => _status ?? 'Tap scan, then wake the scale.';
  double? get liveWeightKg => _liveWeightKg;
  RenphoMeasurement? get latest => _latest;
  RenphoProfile get profile => _profile;
  List<RenphoMeasurement> get history => List.unmodifiable(_history);

  Future<void> load() async {
    final raw = await DatabaseService.instance.getSetting(
      RenphoBleProbeTool.config.id,
      'profile',
    );
    if (raw != null)
      _profile = RenphoProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    _history = await RenphoMeasurementDb.instance.recent();
    notifyListeners();
  }

  Future<void> saveProfile(RenphoProfile profile) async {
    _profile = profile;
    await DatabaseService.instance.setSetting(
      RenphoBleProbeTool.config.id,
      'profile',
      jsonEncode(profile.toJson()),
    );
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_scanning || _connecting) return;
    _error = null;
    _status = 'Looking for MorphoScan Nova. Step on the scale to wake it.';
    notifyListeners();
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      _scanSubscription = UniversalBle.scanStream.listen((device) {
        _devices[device.deviceId] = device;
        if (_isScale(device) && _deviceId == null && !_connecting)
          unawaited(_connect(device.deviceId));
        notifyListeners();
      }, onError: (e) => _fail('Bluetooth scan failed: $e'));
      await UniversalBle.startScan(
        platformConfig: PlatformConfig(
          android: AndroidOptions(scanMode: AndroidScanMode.lowLatency),
        ),
      );
      _scanning = true;
      notifyListeners();
    } catch (e) {
      _fail('Bluetooth permission or scan failed: $e');
    }
  }

  Future<void> stop() async {
    _stageTimer?.cancel();
    _stageTimer = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanning = false;
    final id = _deviceId;
    _deviceId = null;
    _ready = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _wakeLock?.release();
    _wakeLock = null;
    if (id != null) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
    _status = 'Disconnected. Tap scan for another measurement.';
    notifyListeners();
  }

  Future<void> _connect(String id) async {
    _connecting = true;
    notifyListeners();
    try {
      await UniversalBle.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _scanning = false;
      _status = 'Connecting to scale...';
      notifyListeners();
      await UniversalBle.connect(id, timeout: const Duration(seconds: 15));
      _deviceId = id;
      _wakeLock = await PowerWakeLockService.acquireFull();
      final services = await UniversalBle.discoverServices(id);
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (!characteristic.properties.contains(
                CharacteristicProperty.notify,
              ) &&
              !characteristic.properties.contains(
                CharacteristicProperty.indicate,
              ))
            continue;
          final sub =
              UniversalBle.characteristicValueStream(
                id,
                characteristic.uuid,
              ).listen(
                (value) => _onFrame(characteristic.uuid, value),
                onError: (e) => _fail('Bluetooth receive failed: $e'),
              );
          _subscriptions.add(sub);
          try {
            await UniversalBle.subscribeNotifications(
              id,
              service.uuid,
              characteristic.uuid,
            );
          } catch (_) {
            await sub.cancel();
            _subscriptions.remove(sub);
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _stage = 1;
      await _writePacket([
        0x55,
        0xAA,
        0xB2,
        0,
        9,
        0,
        1,
        6,
        0xC2,
        0x19,
        0xAF,
        0xB2,
        1,
        2,
        0,
      ]);
      _status = 'Preparing local scan...';
      _armTimeout(
        'The scale did not acknowledge setup. Wake it and try again.',
      );
    } catch (e) {
      _fail('Could not connect to the scale: $e');
      await stop();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  void _onFrame(String uuid, List<int> value) {
    final bytes = List<int>.from(value);
    _frames.add({
      'at': DateTime.now().toIso8601String(),
      'characteristic': uuid,
      'hex': _hex(bytes),
    });
    if (_frames.length > 500) _frames.removeAt(0);
    if (bytes.length >= 4 &&
        (bytes[0] == 0xAD || bytes[0] == 0xAE || bytes[0] == 0xAF)) {
      _fragment(bytes);
      return;
    }
    if (bytes.length < 3 || bytes[0] != 0x55 || bytes[1] != 0xAA) return;
    if (bytes[2] == 0x21 && bytes.length >= 10)
      _liveWeightKg = _u16(bytes, 8) / 100;
    _advance(bytes[2]);
    notifyListeners();
  }

  void _fragment(List<int> fragment) {
    final sequence = fragment[1];
    if (fragment[0] == 0xAD) _fragments[sequence] = [];
    final pieces = _fragments[sequence];
    if (pieces == null) return;
    pieces.addAll(fragment.sublist(3));
    if (fragment[0] != 0xAF || fragment[2] != 0) return;
    _fragments.remove(sequence);
    if (pieces.length < 3 || pieces[0] != 0x55 || pieces[1] != 0xAA) return;
    if (pieces[2] == 0x26) {
      unawaited(_ack(sequence));
      return;
    }
    if (pieces[2] == 0x25 && pieces.length >= 42 && _validChecksum(pieces))
      unawaited(_saveResult(pieces));
  }

  void _advance(int type) {
    if (_stage == 1 && type == 0x20) {
      _stage = 2;
      _stageTimer?.cancel();
      final seconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      unawaited(
        _writePacket(
          _checksum([
            0x55,
            0xAA,
            0xB3,
            0,
            0x0B,
            1,
            7,
            1,
            1,
            (seconds >> 24) & 255,
            (seconds >> 16) & 255,
            (seconds >> 8) & 255,
            seconds & 255,
            0,
            0x78,
            0,
          ]),
        ),
      );
      _armTimeout(
        'The scale did not continue setup after B3. Disconnect and retry.',
      );
    } else if (_stage == 2 && type == 0x22) {
      _stage = 3;
      unawaited(
        _writePacket([
          0x55,
          0xAA,
          0xB8,
          0,
          0x0C,
          2,
          1,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0xC6,
        ]),
      );
      _armTimeout(
        'The scale did not continue setup after B8. Disconnect and retry.',
      );
    } else if (_stage == 3 && type == 0x23) {
      _stage = 4;
      final name = utf8.encode(_profile.name).take(20).toList();
      final packet = [
        0x55,
        0xAA,
        0xB7,
        0,
        6 + name.length,
        3,
        1,
        0,
        1,
        0,
        name.length,
        ...name,
      ];
      unawaited(_writePacket(_checksum(packet)));
      _ready = true;
      _status =
          'Ready. Stand barefoot, then hold both handles until the result appears.';
      _stageTimer?.cancel();
    }
  }

  Future<void> _saveResult(List<int> packet) async {
    if (_saving) return;
    _saving = true;
    notifyListeners();
    try {
      final impedance = <String, double>{
        'z20Body': packet[13] / 10,
        'z20HandL': _u16(packet, 14) / 10,
        'z20HandR': _u16(packet, 16) / 10,
        'z20FootL': _u16(packet, 18) / 10,
        'z20FootR': _u16(packet, 20) / 10,
        'z100Body': _u16(packet, 22) / 10,
        'z100HandL': _u16(packet, 24) / 10,
        'z100HandR': _u16(packet, 26) / 10,
        'z100FootL': _u16(packet, 28) / 10,
        'z100FootR': _u16(packet, 30) / 10,
      };
      final measurement = RenphoMeasurement(
        uid: RenphoMeasurementDb.instance.newUid(),
        measuredAt: DateTime.now(),
        weightKg: _u16(packet, 9) / 100,
        bmi: _u16(packet, 35) / 10,
        bodyFatPercent: packet[34] / 10,
        musclePercent: _u16(packet, 37) / 10,
        visceralFat: _u16(packet, 39),
        impedance: impedance,
        packetHex: _hex(packet),
      );
      await RenphoMeasurementDb.instance.save(measurement);
      _latest = measurement;
      _history = await RenphoMeasurementDb.instance.recent();
      _status = 'Measurement saved locally.';
    } catch (e) {
      _fail('Could not save measurement: $e');
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _ack(int sequence) =>
      _writePacket(_checksum([0x55, 0xAA, 0xB6, 0, 2, sequence, 1]));
  Future<void> _writePacket(List<int> packet) async {
    final id = _deviceId;
    if (id == null) return;
    await UniversalBle.write(id, _service, _write, Uint8List.fromList(packet));
  }

  void _armTimeout(String message) {
    _stageTimer?.cancel();
    _stageTimer = Timer(const Duration(seconds: 8), () {
      if (!_ready) _fail(message);
    });
  }

  void _fail(String message) {
    _error = message;
    _status = message;
    notifyListeners();
  }

  int _u16(List<int> value, int offset) =>
      (value[offset] << 8) | value[offset + 1];
  List<int> _checksum(List<int> value) => [
    ...value,
    value.fold(0, (sum, byte) => (sum + byte) & 255),
  ];
  bool _validChecksum(List<int> value) =>
      value.length > 1 &&
      value.sublist(0, value.length - 1).fold(0, (sum, byte) => sum + byte) &
              255 ==
          value.last;
  String _hex(List<int> bytes) => bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  bool _isScale(BleDevice device) =>
      device.deviceId.replaceAll('-', ':').toUpperCase() == scaleMacAddress ||
      (device.name ?? '').toUpperCase() == 'RT-MSC04';
  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
