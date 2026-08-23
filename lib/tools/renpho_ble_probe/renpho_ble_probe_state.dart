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
import 'renpho_import.dart';
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

  /// A live measurement finished and the session was closed.
  complete,
}

/// Why a scan stopped. The message itself lives in the l10n bundle, so the
/// state never carries user-facing text.
enum RenphoFailure {
  bluetoothUnavailable,
  scanFailed,
  notFound,
  connectFailed,
  setupFailed,
  saveFailed,
}

/// Where a measurement stands, as the scale reports it. The two halves feel
/// like separate operations to the user — step on and stand still, then grab
/// the handles — so the UI names them instead of showing one blanket status.
enum RenphoMeasureStep { waiting, weighing, impedance, computing, done }

/// What an import did, for the message shown afterwards.
class RenphoImportOutcome {
  final int added;
  final int duplicates;
  final int skipped;

  const RenphoImportOutcome({
    required this.added,
    required this.duplicates,
    required this.skipped,
  });

  bool get isEmpty => added == 0 && duplicates == 0;
}

/// One month of history: enough to render a collapsed section header without
/// holding any of its measurements.
class RenphoHistoryMonth {
  final int year;
  final int month;
  final int count;

  const RenphoHistoryMonth({
    required this.year,
    required this.month,
    required this.count,
  });

  DateTime get start => DateTime(year, month);
  DateTime get end => DateTime(year, month + 1);
  String get key => '$year-$month';
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
  Timer? _discoveryTimer;

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
  int? _expectedAck;
  bool _setupDone = false;
  bool _frameSeen = false;
  bool _handshakeRetried = false;
  Timer? _stageTimer;
  Timer? _watchdog;
  Timer? _idleTimer;
  Duration _pacing = const Duration(milliseconds: 1200);
  WakeLockLease? _wakeLock;
  final _assembler = RenphoFragmentAssembler();
  double? _liveWeightKg;
  RenphoMeasureStep _step = RenphoMeasureStep.waiting;
  RenphoFailure? _error;
  String? _errorDetail;
  bool _retryingSetup = false;
  int _importedStoredRecords = 0;

  // Data
  RenphoProfile _profile = RenphoProfile.empty;
  RenphoMeasurement? _latest;
  RenphoMeasurement? _previous;
  List<RenphoMeasurement> _week = const [];
  List<RenphoHistoryMonth> _months = const [];
  final _monthRows = <String, List<RenphoMeasurement>>{};
  final _monthOrder = <String>[];
  final _monthsLoading = <String>{};
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
  bool get complete => _phase == RenphoScanPhase.complete;
  bool get connected => _deviceId != null;
  bool get ready => _phase == RenphoScanPhase.ready;
  RenphoFailure? get error => _error;
  String? get errorDetail => _errorDetail;
  bool get retryingSetup => _retryingSetup;
  double? get liveWeightKg => _liveWeightKg;
  RenphoMeasureStep get measureStep => _step;
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
  RenphoMeasurement? get latest => _latest;
  RenphoMeasurement? get previous => _previous;

  /// The months that hold scans, newest first. Only the index is kept in
  /// memory; a month's rows are read when its section is opened.
  List<RenphoHistoryMonth> get historyMonths => List.unmodifiable(_months);

  List<RenphoMeasurement>? monthRows(RenphoHistoryMonth month) =>
      _monthRows[month.key];

  bool isMonthLoading(RenphoHistoryMonth month) =>
      _monthsLoading.contains(month.key);

  /// Reads one month on demand and keeps only the most recently opened few, so
  /// scrolling back through years of scans does not accumulate every row.
  Future<void> loadMonth(RenphoHistoryMonth month) async {
    if (_monthRows.containsKey(month.key) || !_monthsLoading.add(month.key)) {
      return;
    }
    try {
      final rows = await RenphoMeasurementDb.instance.between(
        month.start,
        month.end,
      );
      _monthRows[month.key] = rows;
      _monthOrder.remove(month.key);
      _monthOrder.add(month.key);
      while (_monthOrder.length > _monthCacheLimit) {
        _monthRows.remove(_monthOrder.removeAt(0));
      }
    } finally {
      _monthsLoading.remove(month.key);
      notifyListeners();
    }
  }

  static const _monthCacheLimit = 6;

  /// One value per day for the last seven days, newest last, so the trend chart
  /// can line up two series on the same axis. A day with several scans reports
  /// the latest one.
  List<double?> weeklySeries(double Function(RenphoMeasurement) pick) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final byDay = <int, RenphoMeasurement>{};
    for (final measurement in _week.reversed) {
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

  /// Reloads the dashboard's own data plus the month index. The history itself
  /// stays out of memory: the newest two rows cover the headline and its delta,
  /// and one week covers the trend charts.
  Future<void> refreshHistory() async {
    final db = RenphoMeasurementDb.instance;
    final newest = await db.all(limit: 2);
    _latest = newest.isEmpty ? null : newest.first;
    _previous = newest.length < 2 ? null : newest[1];

    final today = DateTime.now();
    final from = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    _week = await db.between(from, today.add(const Duration(days: 1)));

    _months = _monthIndex(await db.timestamps());
    // A month already on screen has to be re-read; anything else is dropped.
    final open = _monthRows.keys.toList();
    _monthRows.clear();
    _monthOrder.clear();
    notifyListeners();
    for (final month in _months) {
      if (open.contains(month.key)) await loadMonth(month);
    }
  }

  List<RenphoHistoryMonth> _monthIndex(List<int> timestamps) {
    final counts = <String, RenphoHistoryMonth>{};
    for (final value in timestamps) {
      final at = DateTime.fromMillisecondsSinceEpoch(value);
      final key = '${at.year}-${at.month}';
      final existing = counts[key];
      counts[key] = RenphoHistoryMonth(
        year: at.year,
        month: at.month,
        count: (existing?.count ?? 0) + 1,
      );
    }
    final months = counts.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return months;
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

  /// Reads a Renpho export and adds what is not already there. Duplicates are
  /// rejected by the same window that keeps the scale's replayed records out,
  /// so re-importing the same file changes nothing.
  Future<RenphoImportOutcome> importFromJson(String source) async {
    final RenphoImportParse parsed;
    try {
      parsed = parseRenphoImport(source, _profile);
    } catch (e) {
      errorLog('[RenphoScale] Import failed: $e');
      return const RenphoImportOutcome(added: 0, duplicates: 0, skipped: 0);
    }
    var added = 0;
    var duplicates = 0;
    for (final measurement in parsed.measurements) {
      final saved = await RenphoMeasurementDb.instance.insert(measurement);
      if (saved == null) {
        duplicates++;
      } else {
        added++;
      }
    }
    if (added > 0) {
      await refreshHistory();
      backgroundSync();
    }
    return RenphoImportOutcome(
      added: added,
      duplicates: duplicates,
      skipped: parsed.skipped,
    );
  }

  // Discovery ---------------------------------------------------------------

  Future<void> startScan() async {
    if (_scanning || _phase == RenphoScanPhase.connecting) return;
    // A session left open by the previous run keeps the link up, and a
    // connected scale stops advertising — so it would never show up again.
    if (_deviceId != null) await disconnect();
    _error = null;
    _errorDetail = null;
    _importedStoredRecords = 0;
    _liveWeightKg = null;
    _step = RenphoMeasureStep.waiting;
    _discovered.clear();
    _phase = RenphoScanPhase.discovering;
    notifyListeners();
    // The user is standing in front of the scale from the moment they press
    // search, so the screen stays on for the whole session, not just the part
    // after a link is up.
    _wakeLock ??= await PowerWakeLockService.acquireFull();
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      if (await _connectSystemDevice()) return;
      await _scanSubscription?.cancel();
      _scanSubscription = UniversalBle.scanStream.listen(
        _onDeviceFound,
        onError: (Object e) => _fail(RenphoFailure.scanFailed, '$e'),
      );
      await UniversalBle.startScan(
        platformConfig: PlatformConfig(
          android: AndroidOptions(scanMode: AndroidScanMode.lowLatency),
        ),
      );
      _scanning = true;
      _armDiscoveryTimeout();
      notifyListeners();
    } catch (e) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _fail(RenphoFailure.bluetoothUnavailable, '$e');
      _phase = RenphoScanPhase.idle;
      notifyListeners();
    }
  }

  /// A scale the OS already holds a link to never appears in a scan. Windows in
  /// particular keeps the connection alive across app restarts, which looks
  /// exactly like the scale having vanished.
  Future<bool> _connectSystemDevice() async {
    if (!_autoConnect) return false;
    List<BleDevice> devices;
    try {
      devices = await UniversalBle.getSystemDevices();
    } catch (e) {
      debugLog('[RenphoScale] System device lookup failed: $e');
      return false;
    }
    for (final device in devices) {
      final name = (device.name ?? '').trim();
      if (!_looksLikeScale(device.deviceId, name)) continue;
      debugLog('[RenphoScale] Reusing system device ${device.deviceId}');
      await connect(
        device.deviceId,
        name.isEmpty ? (_lastDeviceName ?? 'Scale') : name,
      );
      return true;
    }
    return false;
  }

  /// The scale advertises only for a few seconds after it is woken, so a scan
  /// that finds nothing is the normal outcome of a sleeping unit — say so
  /// instead of spinning forever.
  void _armDiscoveryTimeout() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(seconds: 20), () {
      if (_phase != RenphoScanPhase.discovering) return;
      unawaited(stopScan());
      if (_discovered.isEmpty) _fail(RenphoFailure.notFound);
    });
  }

  Future<void> stopScan() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    if (!_scanning) return;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanning = false;
    if (_phase == RenphoScanPhase.discovering) _phase = RenphoScanPhase.idle;
    // Only the scan held the screen awake; a connected session releases it in
    // disconnect instead.
    if (_deviceId == null) await _releaseWakeLock();
    notifyListeners();
  }

  Future<void> _releaseWakeLock() async {
    await _wakeLock?.release();
    _wakeLock = null;
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
    _errorDetail = null;
    notifyListeners();
    // The scan deliberately keeps running. Stopping it first lets the platform
    // drop the freshly seen advertisement, and Windows then answers the connect
    // with "Unreachable" even though the scale is sitting right there.
    _discoveryTimer?.cancel();

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
        // An unreachable device is one that went back to sleep. Leaving the
        // scan up means the next advertisement re-registers it before the
        // retry, which is the difference between working and not.
        try {
          await UniversalBle.disconnect(id);
        } catch (_) {}
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
        }
        continue;
      }
      // The link is up. A failure past this point is about the device, not the
      // connection, so it is reported instead of retried.
      _deviceId = id;
      await stopScan();
      try {
        await _rememberDevice(id, name);
        await _prepare(id);
      } catch (e) {
        _fail(RenphoFailure.connectFailed, '$e');
        await disconnect();
      }
      return;
    }
    await stopScan();
    _fail(RenphoFailure.connectFailed);
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
    notifyListeners();

    _wakeLock ??= await PowerWakeLockService.acquireFull();
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
    _startSetup();
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
    _watchdog?.cancel();
    _watchdog = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    await stopScan();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _assembler.clear();
    await _releaseWakeLock();
    final id = _deviceId;
    _deviceId = null;
    _controlService = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _indicateCharacteristic = null;
    _resultService = null;
    _resultCharacteristic = null;
    _stage = 0;
    _setupDone = false;
    _expectedAck = null;
    _retryingSetup = false;
    if (_phase != RenphoScanPhase.saving &&
        _phase != RenphoScanPhase.complete) {
      _phase = RenphoScanPhase.idle;
    }
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
    _frameSeen = true;
    _armIdleDisconnect();
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
      _stepTo(RenphoMeasureStep.weighing);
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
          // screen but do not store a scan for it. It also means the user is
          // already standing there, so the setup cannot dawdle any longer.
          final weight = _weightOnly(packet);
          if (weight != null) {
            _liveWeightKg = weight;
            notifyListeners();
          }
          _stepTo(RenphoMeasureStep.impedance);
          _hurrySetup();
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

    switch (renphoBroadcastState(packet)) {
      case _impedancePhaseState:
        _stepTo(RenphoMeasureStep.impedance);
        _hurrySetup();
        return;
      case _computingState:
        _stepTo(RenphoMeasureStep.computing);
        return;
    }
    _advanceSetup(type);
  }

  /// The 0x20 states the scale broadcasts: 0x09 when it starts driving the
  /// handles, 0x11 once it has everything and is computing.
  static const _impedancePhaseState = 0x09;
  static const _computingState = 0x11;

  /// The measurement only ever moves forward within a session, so a stray live
  /// weight arriving after the handles are gripped cannot drag it back.
  void _stepTo(RenphoMeasureStep step) {
    if (step.index <= _step.index) return;
    _step = step;
    notifyListeners();
  }

  double? _weightOnly(List<int> packet) {
    if (packet.length < 11) return null;
    return ((packet[7] << 24) |
            (packet[8] << 16) |
            (packet[9] << 8) |
            packet[10]) /
        100;
  }

  // Setup handshake ---------------------------------------------------------

  /// The four setup writes, in order. The scale will not compute a body
  /// composition until it has seen all of them.
  Uint8List _setupPacket(int step) => switch (step) {
    0 => RenphoScaleCommands.handshake(
      lastWeightKg: _liveWeightKg ?? _latest?.weightKg,
    ),
    1 => RenphoScaleCommands.setClock(DateTime.now()),
    2 => RenphoScaleCommands.requestStoredRecords(),
    _ => RenphoScaleCommands.selectUser(_profile.name),
  };

  void _startSetup() {
    _stage = 0;
    _setupDone = false;
    _frameSeen = false;
    _handshakeRetried = false;
    _pacing = const Duration(milliseconds: 1200);
    _sendSetupStep(0);
    _armWatchdog();
  }

  void _sendSetupStep(int step) {
    if (step >= 4) {
      _completeSetup();
      return;
    }
    _stage = step;
    final packet = _setupPacket(step);
    _expectedAck = renphoAckFor(packet[2]);
    unawaited(_write(packet));
    _stageTimer?.cancel();
    // Waiting for an acknowledgement that never comes is worse than sending the
    // next packet unprompted: the scale answers different frames on different
    // firmware, and an unfinished sequence leaves it in weight-only mode. The
    // spacing still matters — writing all four at once makes it drop the
    // profile entirely.
    _stageTimer = Timer(_pacing, () {
      if (_setupDone || _stage != step) return;
      if (kDebugMode) {
        debugLog('[RenphoScale] No ack for setup step $step, continuing');
      }
      _sendSetupStep(step + 1);
    });
  }

  void _advanceSetup(int type) {
    if (_setupDone) {
      // The scale re-announces its state during the measurement; nothing to do
      // unless it dropped back to needing the profile again.
      return;
    }
    // A 0x20 broadcast arrives unprompted on connect and again when the
    // impedance phase starts, so it only counts when it is the frame this step
    // was actually waiting for.
    if (renphoIsStateBroadcast(type) && type != _expectedAck) return;
    final step = _stage;
    _stageTimer?.cancel();
    _sendSetupStep(step + 1);
  }

  /// The scale started the impedance phase before the sequence finished. It
  /// needs the rest of the setup now, so the pacing drops to the minimum.
  void _hurrySetup() {
    if (_setupDone) return;
    _pacing = const Duration(milliseconds: 250);
    _stageTimer?.cancel();
    _sendSetupStep(_stage + 1);
  }

  void _completeSetup() {
    _setupDone = true;
    _expectedAck = null;
    _stageTimer?.cancel();
    _stageTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    _phase = RenphoScanPhase.ready;
    _error = null;
    _errorDetail = null;
    _retryingSetup = false;
    _armIdleDisconnect();
    notifyListeners();
  }

  /// A link left open keeps the scale from advertising, so the next scan finds
  /// nothing at all. An idle session is dropped rather than held forever.
  void _armIdleDisconnect() {
    if (_deviceId == null) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 5), () {
      if (_phase == RenphoScanPhase.saving) return;
      unawaited(disconnect());
    });
  }

  /// Covers the case the per-step timer cannot: a scale that answers nothing at
  /// all. One silent retry, because the unit often drifts back to sleep between
  /// advertising and the first write.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 8), () {
      if (_setupDone) return;
      if (!_frameSeen && !_handshakeRetried) {
        _handshakeRetried = true;
        _retryingSetup = true;
        notifyListeners();
        _sendSetupStep(0);
        _armWatchdog();
        return;
      }
      _fail(RenphoFailure.setupFailed);
      unawaited(disconnect());
    });
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
      if (result.isStored) {
        _phase = _deviceId == null
            ? RenphoScanPhase.idle
            : RenphoScanPhase.ready;
        notifyListeners();
      } else {
        unawaited(_closeSession(saved.weightKg));
      }
      backgroundSync(publishImmediately: true);
    } catch (e) {
      _fail(RenphoFailure.saveFailed, '$e');
    }
  }

  /// A live measurement ends the session: the official app re-sends B2 with the
  /// weight it just received, and holding the link open afterwards only stops
  /// the scale from advertising for the next scan.
  Future<void> _closeSession(double weightKg) async {
    _step = RenphoMeasureStep.done;
    _phase = RenphoScanPhase.complete;
    notifyListeners();
    if (_deviceId != null) {
      await _write(
        RenphoScaleCommands.handshake(sequence: 0x04, lastWeightKg: weightKg),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await disconnect();
    }
    _phase = RenphoScanPhase.complete;
    notifyListeners();
  }

  /// Pushes what is pending to Health Connect and runs the backend sync. Both
  /// halves check their own switch, so this is safe to fire on tool open.
  void backgroundSync({bool publishImmediately = false}) {
    // Publishing to Health Connect is a one-way push and runs independently of
    // the backend sync, which may well be switched off.
    unawaited(
      RenphoHealthConnectPublisher.instance
          .publishPending(skipThrottle: publishImmediately)
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
    final toolId = RenphoBleProbeTool.config.id;
    if (!DatabaseService.isToolSyncEnabled(
      await settings.getSetting(toolId, DatabaseService.toolSyncEnabledKey),
    )) {
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

  void _fail(RenphoFailure failure, [String? detail]) {
    _error = failure;
    _errorDetail = detail;
    _retryingSetup = false;
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
