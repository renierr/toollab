import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:universal_ble/universal_ble.dart';

import 'config.dart';
import 'renpho_health_connect_publisher.dart';
import 'renpho_measurement.dart';
import 'renpho_measurement_db.dart';
import 'renpho_scale_protocol.dart';
import 'renpho_sync_delegate.dart';

enum RenphoScanPhase {
  /// Nothing running.
  idle,
  discovering,
  connecting,

  /// Connected, walking the B2/B3/B8/B7 setup handshake.
  preparing,

  /// Handshake done — the scale is waiting for the user to step on.
  ready,

  /// A result came in and is being written.
  saving,
}

class RenphoDiscoveredScale {
  final String id;
  final String name;
  final int rssi;

  const RenphoDiscoveredScale({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class RenphoBleProbeState extends ChangeNotifier {
  static const _profileKey = 'profile';
  static const _lastDeviceKey = 'last_device_id';
  static const _lastDeviceNameKey = 'last_device_name';

  /// Names the MorphoScan family advertises. Anything else has to be picked by
  /// hand, which is also the escape hatch for a relabelled unit.
  static const _knownNames = ['RT-MSC04', 'R-AMSC04'];

  // Discovery / connection
  bool _scanning = false;
  final _discovered = <String, RenphoDiscoveredScale>{};
  String? _deviceId;
  String? _deviceName;
  String? _lastDeviceId;
  String? _lastDeviceName;
  bool _autoConnect = true;
  bool _connectAborted = false;
  StreamSubscription<BleDevice>? _scanSubscription;

  // Resolved GATT handles
  String? _controlService;
  String? _writeCharacteristic;
  String? _notifyCharacteristic;
  String? _indicateCharacteristic;
  String? _resultService;
  String? _resultCharacteristic;
  final _subscriptions = <StreamSubscription<Uint8List>>[];

  // Session
  RenphoScanPhase _phase = RenphoScanPhase.idle;
  int _stage = 0;
  Timer? _stageTimer;
  bool _handshakeRetried = false;
  WakeLockLease? _wakeLock;
  final _assembler = RenphoFragmentAssembler();
  double? _liveWeightKg;
  String? _error;
  String? _statusOverride;
  int _importedStoredRecords = 0;

  // Data
  RenphoProfile _profile = RenphoProfile.empty;
  List<RenphoMeasurement> _history = const [];
  RenphoMeasurement? _latest;
  bool _loaded = false;
  bool _syncing = false;
  bool _healthConnectEnabled = false;
  RenphoPublishResult? _lastPublish;

  RenphoScanPhase get phase => _phase;
  bool get scanning => _scanning;
  bool get busy =>
      _phase == RenphoScanPhase.discovering ||
      _phase == RenphoScanPhase.connecting ||
      _phase == RenphoScanPhase.preparing ||
      _phase == RenphoScanPhase.saving;
  bool get connected => _deviceId != null;
  bool get ready => _phase == RenphoScanPhase.ready;
  String? get error => _error;
  String? get statusOverride => _statusOverride;
  double? get liveWeightKg => _liveWeightKg;
  String? get deviceName => _deviceName ?? _lastDeviceName;
  String? get deviceId => _deviceId;
  String? get rememberedDeviceId => _lastDeviceId;
  bool get autoConnect => _autoConnect;
  int get importedStoredRecords => _importedStoredRecords;
  List<RenphoDiscoveredScale> get discovered =>
      _discovered.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  RenphoProfile get profile => _profile;
  bool get profileConfigured => _profile.configured;
  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get healthConnectEnabled => _healthConnectEnabled;
  RenphoPublishResult? get lastPublish => _lastPublish;
  List<RenphoMeasurement> get history => List.unmodifiable(_history);
  RenphoMeasurement? get latest => _latest;

  RenphoMeasurement? get previous => _history.length < 2 ? null : _history[1];

  /// One value per day for the last seven days, newest last, so the trend chart
  /// can line up two series on the same axis. A day with several scans reports
  /// the latest one.
  List<double?> weeklySeries(double Function(RenphoMeasurement) pick) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final byDay = <int, RenphoMeasurement>{};
    for (final measurement in _history.reversed) {
      final day = DateTime(
        measurement.measuredAt.year,
        measurement.measuredAt.month,
        measurement.measuredAt.day,
      );
      final offset = midnight.difference(day).inDays;
      if (offset < 0 || offset > 6) continue;
      byDay[6 - offset] = measurement;
    }
    return [
      for (var index = 0; index < 7; index++)
        byDay[index] == null ? null : pick(byDay[index]!),
    ];
  }

  Future<void> load() async {
    if (_loaded) return;
    final settings = DatabaseService.instance;
    final toolId = RenphoBleProbeTool.config.id;
    final raw = await settings.getSetting(toolId, _profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _profile = RenphoProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (e) {
        errorLog('[RenphoScale] Profile load failed: $e');
      }
    }
    _lastDeviceId = await settings.getSetting(toolId, _lastDeviceKey);
    _lastDeviceName = await settings.getSetting(toolId, _lastDeviceNameKey);
    _healthConnectEnabled = await RenphoHealthConnectPublisher.instance
        .isEnabled();
    await refreshHistory();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    _history = await RenphoMeasurementDb.instance.all();
    _latest = _history.isEmpty ? null : _history.first;
    notifyListeners();
  }

  Future<void> saveProfile(RenphoProfile profile) async {
    _profile = profile.copyWith(configured: true);
    await DatabaseService.instance.setSetting(
      RenphoBleProbeTool.config.id,
      _profileKey,
      jsonEncode(_profile.toJson()),
    );
    notifyListeners();
  }

  Future<void> setHealthConnectEnabled(bool enabled) async {
    _healthConnectEnabled = enabled;
    notifyListeners();
    await RenphoHealthConnectPublisher.instance.setEnabled(enabled);
    if (enabled) {
      _lastPublish = await RenphoHealthConnectPublisher.instance.publishPending(
        force: true,
      );
      notifyListeners();
    }
  }

  Future<RenphoPublishResult> publishToHealthConnect() async {
    _lastPublish = await RenphoHealthConnectPublisher.instance.publishPending(
      force: true,
    );
    notifyListeners();
    return _lastPublish!;
  }

  Future<RenphoPublishResult> removeFromHealthConnect() async {
    final result = await RenphoHealthConnectPublisher.instance.removeAll();
    notifyListeners();
    return result;
  }

  void setAutoConnect(bool value) {
    _autoConnect = value;
    notifyListeners();
  }

  Future<void> forgetDevice() async {
    _lastDeviceId = null;
    _lastDeviceName = null;
    final settings = DatabaseService.instance;
    final toolId = RenphoBleProbeTool.config.id;
    await settings.deleteSetting(toolId, _lastDeviceKey);
    await settings.deleteSetting(toolId, _lastDeviceNameKey);
    notifyListeners();
  }

  Future<void> deleteMeasurement(String uid) async {
    await RenphoMeasurementDb.instance.softDelete(uid);
    await refreshHistory();
    unawaited(syncNow());
  }

  // Discovery ---------------------------------------------------------------

  Future<void> startScan() async {
    if (_scanning || _phase == RenphoScanPhase.connecting) return;
    _error = null;
    _importedStoredRecords = 0;
    _liveWeightKg = null;
    _discovered.clear();
    _phase = RenphoScanPhase.discovering;
    notifyListeners();
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      await _scanSubscription?.cancel();
      _scanSubscription = UniversalBle.scanStream.listen(
        _onDeviceFound,
        onError: (Object e) => _fail('Bluetooth scan failed: $e'),
      );
      await UniversalBle.startScan(
        platformConfig: PlatformConfig(
          android: AndroidOptions(scanMode: AndroidScanMode.lowLatency),
        ),
      );
      _scanning = true;
      notifyListeners();
    } catch (e) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _fail('Bluetooth is unavailable or permission was refused: $e');
      _phase = RenphoScanPhase.idle;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_scanning) return;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanning = false;
    if (_phase == RenphoScanPhase.discovering) _phase = RenphoScanPhase.idle;
    notifyListeners();
  }

  void _onDeviceFound(BleDevice device) {
    final name = (device.name ?? '').trim();
    final id = device.deviceId;
    if (!_looksLikeScale(id, name)) return;
    _discovered[id] = RenphoDiscoveredScale(
      id: id,
      name: name.isEmpty ? 'Unnamed scale' : name,
      rssi: device.rssi ?? 0,
    );
    notifyListeners();
    if (_autoConnect &&
        _deviceId == null &&
        _phase == RenphoScanPhase.discovering &&
        (_lastDeviceId == null || _lastDeviceId == id)) {
      unawaited(connect(id, _discovered[id]!.name));
    }
  }

  /// The scale is only recognised by its advertised name or by having been
  /// paired here before — no MAC address is baked into the app, because that
  /// only ever matches one person's unit.
  bool _looksLikeScale(String id, String name) {
    if (_lastDeviceId != null && id == _lastDeviceId) return true;
    final upper = name.toUpperCase();
    if (upper.isEmpty) return false;
    return _knownNames.contains(upper) ||
        upper.contains('MSC04') ||
        upper.contains('MORPHOSCAN') ||
        upper.contains('RENPHO');
  }

  // Connection --------------------------------------------------------------

  Future<void> connect(String id, String name) async {
    if (_phase == RenphoScanPhase.connecting || _deviceId != null) return;
    _connectAborted = false;
    _phase = RenphoScanPhase.connecting;
    _deviceName = name;
    _error = null;
    notifyListeners();
    await stopScan();

    // The scale advertises for a few seconds after it wakes and then sleeps
    // again; a single connect attempt loses that race often enough to look
    // broken.
    const attempts = 4;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (_connectAborted) return;
      try {
        await UniversalBle.connect(id, timeout: const Duration(seconds: 15));
      } catch (e) {
        errorLog('[RenphoScale] Connect attempt $attempt/$attempts: $e');
        if (_connectAborted) return;
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        }
        continue;
      }
      // The link is up. A failure past this point is about the device, not the
      // connection, so it is reported instead of retried.
      _deviceId = id;
      try {
        await _rememberDevice(id, name);
        await _prepare(id);
      } catch (e) {
        _fail('$e');
        await disconnect();
      }
      return;
    }
    _fail('Could not connect to the scale. Wake it and try again.');
    await disconnect();
  }

  Future<void> _rememberDevice(String id, String name) async {
    _lastDeviceId = id;
    _lastDeviceName = name;
    final settings = DatabaseService.instance;
    final toolId = RenphoBleProbeTool.config.id;
    await settings.setSetting(toolId, _lastDeviceKey, id);
    await settings.setSetting(toolId, _lastDeviceNameKey, name);
  }

  Future<void> _prepare(String id) async {
    _phase = RenphoScanPhase.preparing;
    _statusOverride = null;
    notifyListeners();

    _wakeLock = await PowerWakeLockService.acquireFull();
    // Android holds the ATT MTU at 23 until asked. Result fragments are larger
    // than that and would arrive truncated.
    try {
      await UniversalBle.requestMtu(id, 247);
    } catch (_) {}

    final services = await UniversalBle.discoverServices(id);
    final control = services
        .where(
          (service) => _sameUuid(service.uuid, RenphoScaleUuids.controlService),
        )
        .firstOrNull;
    if (control == null) {
      throw StateError(
        'This device does not expose the 1A10 control service. '
        'Found: ${services.map((service) => service.uuid).join(', ')}',
      );
    }
    _controlService = control.uuid;
    _writeCharacteristic = _find(control, RenphoScaleUuids.controlWrite);
    _notifyCharacteristic = _find(control, RenphoScaleUuids.controlNotify);
    _indicateCharacteristic = _find(control, RenphoScaleUuids.controlIndicate);
    final missing = [
      if (_writeCharacteristic == null) '2A11 write',
      if (_notifyCharacteristic == null) '2A10 notify',
      if (_indicateCharacteristic == null) '2A12 indicate',
    ];
    if (missing.isNotEmpty) {
      throw StateError('The 1A10 service is missing ${missing.join(', ')}.');
    }

    // Body-composition results travel on their own transport characteristic,
    // which lives outside the control service. Without this subscription the
    // handshake completes and no result ever arrives.
    for (final service in services) {
      final characteristic = _find(service, RenphoScaleUuids.resultTransport);
      if (characteristic != null) {
        _resultService = service.uuid;
        _resultCharacteristic = characteristic;
        break;
      }
    }

    await _listen(
      id,
      _controlService!,
      _notifyCharacteristic!,
      indicate: false,
    );
    // The capture proves 2A10 notifies and 2A12 indicates. Subscribing 2A12 as
    // a notification leaves its CCCD in the wrong mode and the scale never
    // sends the B2 acknowledgement.
    await _listen(
      id,
      _controlService!,
      _indicateCharacteristic!,
      indicate: true,
    );
    if (_resultCharacteristic != null) {
      await _listen(
        id,
        _resultService!,
        _resultCharacteristic!,
        indicate: false,
      );
    } else {
      errorLog('[RenphoScale] No 0003 result transport found on this device');
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    _stage = 1;
    _handshakeRetried = false;
    await _write(RenphoScaleCommands.handshake());
    _armTimeout();
  }

  Future<void> _listen(
    String id,
    String service,
    String characteristic, {
    required bool indicate,
  }) async {
    _subscriptions.add(
      UniversalBle.characteristicValueStream(id, characteristic).listen(
        (value) => _onFrame(value),
        onError: (Object e) => errorLog('[RenphoScale] Receive failed: $e'),
      ),
    );
    if (indicate) {
      await UniversalBle.subscribeIndications(id, service, characteristic);
    } else {
      await UniversalBle.subscribeNotifications(id, service, characteristic);
    }
  }

  Future<void> disconnect() async {
    _connectAborted = true;
    _stageTimer?.cancel();
    _stageTimer = null;
    await stopScan();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _assembler.clear();
    await _wakeLock?.release();
    _wakeLock = null;
    final id = _deviceId;
    _deviceId = null;
    _controlService = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _indicateCharacteristic = null;
    _resultService = null;
    _resultCharacteristic = null;
    _stage = 0;
    _liveWeightKg = null;
    if (_phase != RenphoScanPhase.saving) _phase = RenphoScanPhase.idle;
    if (id != null) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
    notifyListeners();
  }

  // Frames ------------------------------------------------------------------

  void _onFrame(List<int> value) {
    final bytes = List<int>.from(value);
    if (kDebugMode) debugLog('[RenphoScale] RX ${renphoHex(bytes)}');

    if (RenphoFragmentAssembler.isFragment(bytes)) {
      final packet = _assembler.add(bytes);
      // The acknowledgement carries the transport's fragment sequence, not the
      // sequence byte inside the reassembled packet.
      if (packet != null) {
        _onPacket(packet, fragmented: true, fragmentSequence: bytes[1]);
      }
      return;
    }
    _onPacket(bytes, fragmented: false);
  }

  void _onPacket(
    List<int> packet, {
    required bool fragmented,
    int? fragmentSequence,
  }) {
    if (packet.length < 3 || packet[0] != 0x55 || packet[1] != 0xAA) return;
    final type = packet[2];

    final live = decodeRenphoLiveWeight(packet);
    if (live != null) {
      _liveWeightKg = live;
      notifyListeners();
      return;
    }

    if (type == 0x24 || type == 0x25 || type == 0x26) {
      // A truncated or corrupted result would decode into a plausible-looking
      // body composition, so a bad checksum drops the packet.
      if (fragmented && !renphoChecksumValid(packet)) {
        errorLog('[RenphoScale] Dropped result with bad checksum');
        return;
      }
      final result = decodeRenphoResult(packet);
      // The scale expects each complete stored record to be acknowledged
      // before it moves on to the next one.
      if (type == 0x26 && packet.length > 5) {
        unawaited(
          _write(
            RenphoScaleCommands.acknowledge(fragmentSequence ?? packet[5]),
          ),
        );
      }
      if (result == null) {
        if (type == 0x24) {
          // 0x24 is the settled weight without body composition; keep it on
          // screen but do not store a scan for it.
          final weight = _weightOnly(packet);
          if (weight != null) {
            _liveWeightKg = weight;
            notifyListeners();
          }
        }
        return;
      }
      if (!result.hasBodyComposition) {
        _liveWeightKg = result.weightKg;
        notifyListeners();
        return;
      }
      unawaited(_store(result));
      return;
    }

    _advanceSetup(type);
  }

  double? _weightOnly(List<int> packet) {
    if (packet.length < 11) return null;
    return ((packet[7] << 24) |
            (packet[8] << 16) |
            (packet[9] << 8) |
            packet[10]) /
        100;
  }

  void _advanceSetup(int type) {
    if (_stage == 1 && type == 0x20) {
      _stage = 2;
      unawaited(_write(RenphoScaleCommands.setClock(DateTime.now())));
      _armTimeout();
    } else if (_stage == 2 && type == 0x22) {
      _stage = 3;
      unawaited(_write(RenphoScaleCommands.requestStoredRecords()));
      _armTimeout();
    } else if (_stage == 3 && type == 0x23) {
      _stage = 4;
      unawaited(_write(RenphoScaleCommands.selectUser(_profile.name)));
      _stageTimer?.cancel();
      _stageTimer = null;
      _phase = RenphoScanPhase.ready;
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _store(RenphoScaleResult result) async {
    _phase = RenphoScanPhase.saving;
    notifyListeners();
    try {
      final receivedAt = DateTime.now();
      final measuredAt = result.measuredAt(receivedAt);
      final measurement = RenphoMeasurement(
        uid: RenphoMeasurementDb.instance.newUid(),
        measuredAt: measuredAt,
        weightKg: result.weightKg,
        bmi: result.bmi,
        bodyFatPercent: result.bodyFatPercent,
        musclePercent: result.musclePercent,
        visceralFat: result.visceralFat,
        impedance: result.impedance,
        stored: result.isStored,
        packetHex: result.packetHex,
        profileName: _profile.name,
        profileSex: _profile.sex,
        profileHeightCm: _profile.heightCm,
        profileAge: _profile.ageAt(measuredAt),
      );
      final saved = await RenphoMeasurementDb.instance.insert(measurement);
      if (saved == null) {
        // A stored record the scale replays on every connect.
        _phase = _deviceId == null
            ? RenphoScanPhase.idle
            : RenphoScanPhase.ready;
        notifyListeners();
        return;
      }
      if (result.isStored) {
        _importedStoredRecords++;
      } else {
        _liveWeightKg = saved.weightKg;
      }
      await refreshHistory();
      _phase = _deviceId == null ? RenphoScanPhase.idle : RenphoScanPhase.ready;
      notifyListeners();
      _backgroundSync();
    } catch (e) {
      _fail('Could not save the measurement: $e');
    }
  }

  void _backgroundSync() {
    // Publishing to Health Connect is a one-way push and runs independently of
    // the backend sync, which may well be switched off.
    unawaited(
      RenphoHealthConnectPublisher.instance
          .publishPending()
          .then((result) {
            _lastPublish = result;
            notifyListeners();
          })
          .catchError((Object e) {
            errorLog('[RenphoScale] Health Connect publish error: $e');
          }),
    );
    unawaited(
      syncNow().catchError((Object e) {
        errorLog('[RenphoScale] Background sync failed: $e');
        return null;
      }),
    );
  }

  /// Two-way sync of the measurement history with the backend. Returns the
  /// pulled/pushed/deleted counts, or null when sync is off, unconfigured, or
  /// already running.
  Future<Map<String, int>?> syncNow() async {
    if (_syncing) return null;
    final settings = DatabaseService.instance;
    if (await settings.getSetting('_app', 'sync_enabled') != 'true') {
      return null;
    }
    final serverUrl = await settings.getSetting('_app', 'sync_server_url');
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final userId = await settings.getSetting('_app', 'sync_user_id') ?? '';

    _syncing = true;
    notifyListeners();
    try {
      final result = await SyncService.sync(
        baseUrl: serverUrl,
        userId: userId,
        delegate: RenphoSyncDelegate(),
      );
      await refreshHistory();
      return result;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // Plumbing ----------------------------------------------------------------

  Future<void> _write(Uint8List packet) async {
    final id = _deviceId;
    final service = _controlService;
    final characteristic = _writeCharacteristic;
    if (id == null || service == null || characteristic == null) return;
    try {
      if (kDebugMode) debugLog('[RenphoScale] TX ${renphoHex(packet)}');
      await UniversalBle.write(
        id,
        service,
        characteristic,
        packet,
        withoutResponse: false,
      );
    } catch (e) {
      errorLog('[RenphoScale] Write failed: $e');
    }
  }

  /// The handshake is the one step that reliably stalls when the scale drifted
  /// back to sleep between advertising and connecting, so it gets one silent
  /// retry before the failure is reported.
  void _armTimeout() {
    _stageTimer?.cancel();
    _stageTimer = Timer(const Duration(seconds: 8), () {
      if (_phase == RenphoScanPhase.ready) return;
      if (_stage == 1 && !_handshakeRetried) {
        _handshakeRetried = true;
        _statusOverride = 'The scale did not answer. Retrying setup...';
        notifyListeners();
        unawaited(_write(RenphoScaleCommands.handshake()));
        _armTimeout();
        return;
      }
      _fail(
        'The scale stopped responding during setup (step $_stage). '
        'Step on it to wake it, then scan again.',
      );
      unawaited(disconnect());
    });
  }

  void _fail(String message) {
    _error = message;
    _statusOverride = null;
    notifyListeners();
  }

  String? _find(BleService service, String uuid) => service.characteristics
      .where((characteristic) => _sameUuid(characteristic.uuid, uuid))
      .map((characteristic) => characteristic.uuid)
      .firstOrNull;

  bool _sameUuid(String left, String right) =>
      _shortUuid(left) == _shortUuid(right);

  String _shortUuid(String value) {
    final normalized = value.toLowerCase().replaceAll('-', '');
    return normalized.length >= 8 ? normalized.substring(4, 8) : normalized;
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
