import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'config.dart';
import 'treadmill_control_db.dart';
import 'treadmill_health_connect_publisher.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';
import 'treadmill_models.dart';
import 'treadmill_protocol.dart';
import 'treadmill_gatt_resolver.dart';
import 'treadmill_sync_delegate.dart';

export 'treadmill_models.dart';

class TreadmillControlState extends ChangeNotifier {
  static const _syncToHealthConnectKey = 'sync_to_health_connect';
  static const _activeSessionKey = 'active_session';
  static const _savedTreadmillKey = 'saved_treadmill_device';
  static const _savedHrmKey = 'saved_hrm_device';

  /// How often the running session is written to disk, in ticks (= seconds).
  static const _snapshotEverySeconds = 10;

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

  // Remembered devices for auto-reconnect on app start.
  String? savedTreadmillId;
  String? savedTreadmillName;
  String? savedHrmId;
  String? savedHrmName;

  // Settings
  bool syncToHealthConnect = true;

  /// Outcome of the last Health Connect publish, for the UI to report on.
  TreadmillPublishResult? lastHealthConnectPublish;

  // Support flags determined on connection
  bool speedControlSupported = false;
  bool inclineControlSupported = false;

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

  // HRM In-Memory History (Tracked continuously as long as connected)
  final List<HeartRateHistoryPoint> hrmHistory = [];

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

  /// A session that was still recording when the app went away, restored from
  /// the on-disk snapshot. The page offers to continue, keep or drop it.
  TreadmillSession? recoveredSession;

  // Backend sync
  bool isSyncing = false;

  // Private Subscriptions & Helpers
  StreamSubscription<BleDevice>? _scanSubscription;
  Timer? _workoutTimer;
  Timer? _pitpatHeartbeatTimer;
  WakeLockLease? _wakeLockLease;
  bool _isControlRequested = false;

  // After a stop the treadmill coasts down and keeps sending speed>0 frames;
  // suppress auto-start until it has fully decelerated back to 0, so the
  // deceleration ramp can't spawn a fresh session on every frame.
  bool _awaitingSpeedZero = false;

  // Session keep-alive (CPU + foreground service) — independent of the
  // user-facing screen wake lock, so data stays reliable with the screen off.
  WakeLockLease? _sessionCpuLease;
  ForegroundRuntimeLease? _foregroundLease;

  // Foreground-service notification strings (localized by the page).
  String notificationTitle = 'Treadmill workout active';
  String notificationText = 'ToolLab keeps recording your session';

  // Characteristics that rejected WriteWithoutResponse — write with response.
  final Set<String> _noWriteWithoutResponse = {};

  // Aborts an in-flight connect retry loop (user cancelled / disconnected).
  bool _treadmillConnectAbort = false;

  AppLifecycleListener? _lifecycleListener;

  TreadmillControlState() {
    _init();
  }

  void _init() {
    UniversalBle.onConnectionChange = _onConnectionChange;
    UniversalBle.onValueChange = _onValueChange;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleChange,
    );
    loadSessions();
    _loadSettings();
    _loadRecoveredSession();
  }

  bool get hasActiveSession =>
      workoutStatus == WorkoutStatus.running ||
      workoutStatus == WorkoutStatus.paused ||
      workoutStatus == WorkoutStatus.starting;

  void _onAppLifecycleChange(AppLifecycleState state) {
    // Losing the foreground is the last certain moment to write: a swipe-away
    // or a kill never comes back.
    if (state != AppLifecycleState.resumed && hasActiveSession) {
      unawaited(_saveSnapshot());
    }
  }

  /// Writes the running workout to disk so an app kill cannot lose it.
  Future<void> _saveSnapshot() async {
    if (dataPoints.isEmpty) return;
    try {
      final snapshot = TreadmillSession.fromWorkout(
        dataPoints: dataPoints,
        distance: distance,
        calories: calories,
        steps: steps,
        elapsedTime: elapsedTime,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      await DatabaseService.instance.setSetting(
        TreadmillControlTool.config.id,
        _activeSessionKey,
        jsonEncode(snapshot.toMap()),
      );
    } catch (e) {
      errorLog('[TreadmillControl] Snapshot save failed: $e');
    }
  }

  Future<void> _clearSnapshot() async {
    try {
      await DatabaseService.instance.deleteSetting(
        TreadmillControlTool.config.id,
        _activeSessionKey,
      );
    } catch (e) {
      errorLog('[TreadmillControl] Snapshot clear failed: $e');
    }
  }

  Future<void> _loadRecoveredSession() async {
    try {
      final raw = await DatabaseService.instance.getSetting(
        TreadmillControlTool.config.id,
        _activeSessionKey,
      );
      if (raw == null || raw.isEmpty) return;
      final session = TreadmillSession.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.elapsedTime <= 0 || session.dataPoints.isEmpty) {
        await _clearSnapshot();
        return;
      }
      recoveredSession = session;
      notifyListeners();
    } catch (e) {
      errorLog('[TreadmillControl] Snapshot load failed: $e');
      await _clearSnapshot();
    }
  }

  /// Puts the interrupted workout back as a paused session, so resuming adds to
  /// it instead of starting from zero.
  void resumeRecoveredSession() {
    final session = recoveredSession;
    if (session == null) return;
    recoveredSession = null;
    dataPoints = List.of(session.dataPoints);
    elapsedTime = session.elapsedTime;
    distance = session.distance;
    calories = session.calories;
    steps = session.steps;
    workoutStatus = WorkoutStatus.paused;
    notifyListeners();
  }

  /// Files the interrupted workout in the history as it was.
  Future<void> saveRecoveredSession() async {
    final session = recoveredSession;
    if (session == null) return;
    recoveredSession = null;
    notifyListeners();
    await TreadmillControlDb.instance.saveSession(session);
    await _clearSnapshot();
    await loadSessions();
    _backgroundSync();
  }

  Future<void> discardRecoveredSession() async {
    recoveredSession = null;
    notifyListeners();
    await _clearSnapshot();
  }

  Future<void> _loadSettings() async {
    try {
      final val = await DatabaseService.instance.getSetting(
        TreadmillControlTool.config.id,
        _syncToHealthConnectKey,
      );
      // Unset means on: the health dashboard reads treadmill workouts only via
      // Health Connect, so publishing has to be the default.
      syncToHealthConnect = val != 'false';
      notifyListeners();
    } catch (e) {
      errorLog('[TreadmillControl] Load settings failed: $e');
    }
    await _loadSavedDevices();
  }

  Future<void> _loadSavedDevices() async {
    try {
      final rawTreadmill = await DatabaseService.instance.getSetting(
        TreadmillControlTool.config.id,
        _savedTreadmillKey,
      );
      final treadmillMap = _decodeSavedDevice(rawTreadmill);
      savedTreadmillId = treadmillMap?['id'];
      savedTreadmillName = treadmillMap?['name'];

      final rawHrm = await DatabaseService.instance.getSetting(
        TreadmillControlTool.config.id,
        _savedHrmKey,
      );
      final hrmMap = _decodeSavedDevice(rawHrm);
      savedHrmId = hrmMap?['id'];
      savedHrmName = hrmMap?['name'];
      notifyListeners();
    } catch (e) {
      errorLog('[TreadmillControl] Load saved devices failed: $e');
    }
  }

  Map<String, String>? _decodeSavedDevice(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return {'id': id, 'name': (map['name'] as String?) ?? ''};
  }

  Future<void> _persistSavedDevice(String key, String? id, String? name) async {
    try {
      if (id == null) {
        await DatabaseService.instance.deleteSetting(
          TreadmillControlTool.config.id,
          key,
        );
      } else {
        await DatabaseService.instance.setSetting(
          TreadmillControlTool.config.id,
          key,
          jsonEncode({'id': id, 'name': name ?? ''}),
        );
      }
    } catch (e) {
      errorLog('[TreadmillControl] Persist saved device failed: $e');
    }
  }

  /// Reconnects to previously connected devices. Best-effort: without
  /// Bluetooth permissions yet or with the device powered off this fails
  /// silently and the user connects manually via the sheet. Called when the
  /// tool page opens — never at app start, where other tools may not want
  /// BLE radio activity.
  void autoConnectSavedDevices() {
    if (!isSimulator &&
        savedTreadmillId != null &&
        treadmillDeviceId == null &&
        _autoConnectTried.add(savedTreadmillId!)) {
      unawaited(
        connectTreadmill(
          savedTreadmillId!,
          savedTreadmillName,
          stopScanning: false,
        ),
      );
    }
    if (savedHrmId != null &&
        hrmDeviceId == null &&
        _autoConnectTried.add(savedHrmId!)) {
      unawaited(connectHrm(savedHrmId!, savedHrmName, stopScanning: false));
    }
  }

  // Device ids an auto-connect was already attempted for; refilled on every
  // scan so discovery gets a fresh chance after a failed direct attempt.
  final Set<String> _autoConnectTried = {};

  /// Connects a discovered device if it is one of the remembered ones and no
  /// connection attempt is running yet. Runs while the scan stays active so
  /// the other device kind can still be found.
  void _maybeAutoConnectDiscovered(String deviceId) {
    final isSavedTreadmill =
        deviceId == savedTreadmillId &&
        treadmillDeviceId == null &&
        !isSimulator;
    final isSavedHrm = deviceId == savedHrmId && hrmDeviceId == null;
    if (!isSavedTreadmill && !isSavedHrm) return;
    if (!_autoConnectTried.add(deviceId)) return;
    if (isSavedTreadmill) {
      unawaited(
        connectTreadmill(deviceId, savedTreadmillName, stopScanning: false),
      );
    } else {
      unawaited(connectHrm(deviceId, savedHrmName, stopScanning: false));
    }
  }

  Future<void> setSyncToHealthConnect(bool value) async {
    syncToHealthConnect = value;
    notifyListeners();
    try {
      await DatabaseService.instance.setSetting(
        TreadmillControlTool.config.id,
        _syncToHealthConnectKey,
        value ? 'true' : 'false',
      );
      if (value) {
        lastHealthConnectPublish = await TreadmillHealthConnectPublisher
            .instance
            .publishPendingSessions(force: true);
        notifyListeners();
      }
    } catch (e) {
      errorLog('[TreadmillControl] Update Health Connect setting failed: $e');
    }
  }

  /// Publishes pending workouts on demand, bypassing the throttle. The result
  /// is kept so the settings sheet and the history screen can report it.
  Future<TreadmillPublishResult> publishToHealthConnect() async {
    final result = await TreadmillHealthConnectPublisher.instance
        .publishPendingSessions(force: true);
    lastHealthConnectPublish = result;
    notifyListeners();
    return result;
  }

  /// Deletes everything this app wrote to Health Connect and clears the publish
  /// markers, so the next publish recreates it.
  Future<TreadmillPublishResult> removeFromHealthConnect() async {
    final result = await TreadmillHealthConnectPublisher.instance
        .removeAllFromHealthConnect();
    lastHealthConnectPublish = null;
    notifyListeners();
    return result;
  }

  Future<void> loadSessions() async {
    try {
      pastSessions = await TreadmillControlDb.instance.getActiveSessions();
      notifyListeners();
    } catch (e) {
      errorLog('[TreadmillControl] Load sessions failed: $e');
    }
  }

  void _backgroundSync() {
    // A workout just ended, so this run must not be throttled away.
    TreadmillHealthConnectPublisher.instance
        .publishPendingSessions(force: true)
        .then((result) => lastHealthConnectPublish = result)
        .catchError((Object e) {
          errorLog('[TreadmillControl] Health Connect publish error: $e');
          return const TreadmillPublishResult(TreadmillPublishOutcome.ran);
        });
    syncNow().catchError((e) {
      errorLog('[TreadmillControl] Background sync failed: $e');
      return null;
    });
  }

  /// Runs a two-way sync of the workout history with the backend. Returns the
  /// pulled/pushed/deleted counts, `null` if sync is disabled/unconfigured or
  /// already running. Throws on network/backend failures so a manual trigger
  /// can surface the error.
  Future<Map<String, int>?> syncNow({bool force = false}) async {
    // Publishing to Health Connect is a one-way push and runs independently of
    // the backend cloud sync, which may well be switched off.
    lastHealthConnectPublish = await TreadmillHealthConnectPublisher.instance
        .publishPendingSessions(force: force);

    if (isSyncing) return null;
    final syncEnabled = await DatabaseService.instance.getSetting(
      '_app',
      'sync_enabled',
    );
    if (syncEnabled != 'true') return null;
    final serverUrl = await DatabaseService.instance.getSetting(
      '_app',
      'sync_server_url',
    );
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final userId =
        await DatabaseService.instance.getSetting('_app', 'sync_user_id') ?? '';

    isSyncing = true;
    notifyListeners();
    try {
      final result = await SyncService.sync(
        baseUrl: serverUrl,
        userId: userId,
        delegate: TreadmillSyncDelegate(),
      );
      await loadSessions();
      return result;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // Scanning Controls
  Future<void> startScan() async {
    if (isScanning) return;
    discoveredTreadmills.clear();
    discoveredHrms.clear();
    _autoConnectTried.clear();

    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      _scanSubscription?.cancel();
      _scanSubscription = UniversalBle.scanStream.listen(_onDeviceDiscovered);
      await UniversalBle.startScan();
      isScanning = true;
      notifyListeners();
    } catch (e) {
      errorLog('[TreadmillControl] Start scan failed: $e');
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
      _maybeAutoConnectDiscovered(dev.id);
      notifyListeners();
    }

    if (isHrmDevice) {
      final idx = discoveredHrms.indexWhere((d) => d.id == dev.id);
      if (idx == -1) {
        discoveredHrms.add(dev);
      } else {
        discoveredHrms[idx] = dev;
      }
      _maybeAutoConnectDiscovered(dev.id);
      notifyListeners();
    }
  }

  // Connection Controls
  Future<void> connectTreadmill(
    String deviceId,
    String? name, {
    bool stopScanning = true,
  }) async {
    treadmillDeviceId = deviceId;
    treadmillName = name;
    treadmillConnection = BleConnectionState.connecting;
    _treadmillConnectAbort = false;
    notifyListeners();
    if (stopScanning) await stopScan();

    const int maxAttempts = 4;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // Stop retrying if the user cancelled, switched target, or the OS
      // already reported a real connection via _onConnectionChange.
      if (_treadmillConnectAbort ||
          treadmillDeviceId != deviceId ||
          treadmillConnection == BleConnectionState.connected) {
        return;
      }
      try {
        await UniversalBle.connect(deviceId);
        // A successful return only means the request was accepted; the green
        // "connected" state is set by _onConnectionChange when the link is up.
        return;
      } catch (e) {
        errorLog(
          '[TreadmillControl] Connect attempt $attempt/$maxAttempts failed: $e',
        );
        // The link can still come up via the callback shortly after a throw.
        if (treadmillConnection == BleConnectionState.connected ||
            _treadmillConnectAbort ||
            treadmillDeviceId != deviceId) {
          return;
        }
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }

    // Exhausted retries — only downgrade if no real connection arrived.
    if (treadmillConnection != BleConnectionState.connected &&
        treadmillDeviceId == deviceId &&
        !_treadmillConnectAbort) {
      treadmillConnection = BleConnectionState.disconnected;
      treadmillDeviceId = null;
      treadmillName = null;
      notifyListeners();
      errorLog(
        '[TreadmillControl] Connection failed after $maxAttempts attempts',
      );
    }
  }

  Future<void> disconnectTreadmill({bool notify = true}) async {
    _treadmillConnectAbort = true;
    if (treadmillDeviceId == null) return;
    final deviceId = treadmillDeviceId;

    if (workoutStatus == WorkoutStatus.running ||
        workoutStatus == WorkoutStatus.paused) {
      await stopWorkout();
    }

    // The remembered device is kept, so the next tool visit reconnects.

    treadmillConnection = BleConnectionState.disconnected;
    treadmillDeviceId = null;
    treadmillName = null;
    treadmillType = TreadmillType.none;
    _isControlRequested = false;
    _noWriteWithoutResponse.clear();
    _stopPitPatHeartbeat();

    speed = 0.0;
    incline = 0.0;
    distance = 0.0;
    calories = 0;
    steps = 0;
    elapsedTime = 0;
    hrmHistory.clear();
    speedControlSupported = false;
    inclineControlSupported = false;

    if (notify) notifyListeners();

    if (deviceId != null) {
      try {
        await UniversalBle.disconnect(deviceId);
      } catch (_) {}
    }
  }

  Future<void> connectHrm(
    String deviceId,
    String? name, {
    bool stopScanning = true,
  }) async {
    hrmDeviceId = deviceId;
    hrmName = name;
    hrmConnection = BleConnectionState.connecting;
    notifyListeners();
    if (stopScanning) await stopScan();
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      hrmConnection = BleConnectionState.disconnected;
      notifyListeners();
      errorLog('[TreadmillControl] HRM Connection failed: $e');
    }
  }

  Future<void> disconnectHrm({bool notify = true}) async {
    if (hrmDeviceId == null) return;
    final deviceId = hrmDeviceId;

    hrmConnection = BleConnectionState.disconnected;
    hrmDeviceId = null;
    hrmName = null;
    batteryLevel = null;
    heartRate = 0;
    hrmHistory.clear();

    if (notify) notifyListeners();

    if (deviceId != null) {
      try {
        await UniversalBle.disconnect(deviceId);
      } catch (_) {}
    }
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
        savedTreadmillId = deviceId;
        savedTreadmillName = treadmillName;
        unawaited(
          _persistSavedDevice(_savedTreadmillKey, deviceId, treadmillName),
        );
        _isControlRequested = false;
        final services = await UniversalBle.discoverServices(deviceId);

        // Android keeps the ATT MTU at 23 (20-byte notifications) until asked;
        // PitPat telemetry frames are 31 bytes and would arrive truncated.
        // Best-effort on Windows, which already negotiates a large MTU.
        try {
          await UniversalBle.requestMtu(deviceId, 247);
        } catch (_) {}

        final profile = resolveTreadmillGatt(services);
        _actualTreadmillService = profile.service;
        _actualTreadmillDataChar = profile.dataChar;
        _actualTreadmillControlPointChar = profile.controlPointChar;
        _actualTreadmillFeatureChar = profile.featureChar;
        _actualTreadmillWriteChar = profile.writeChar;
        treadmillType = profile.type;

        errorLog(
          '[TreadmillControl] Connected $deviceId type=$treadmillType '
          'svc=$_actualTreadmillService data=$_actualTreadmillDataChar '
          'write=$_actualTreadmillWriteChar cp=$_actualTreadmillControlPointChar',
        );

        _actualTreadmillService ??= treadmillType == TreadmillType.pitpat
            ? pitpatService
            : ftmsService;
        _actualTreadmillDataChar ??= treadmillType == TreadmillType.pitpat
            ? pitpatNotifyChar
            : ftmsDataChar;
        _actualTreadmillControlPointChar ??= ftmsControlPointChar;
        _actualTreadmillWriteChar ??= pitpatWriteChar;

        if (treadmillType == TreadmillType.pitpat) {
          speedControlSupported = true;
          inclineControlSupported = false;
          try {
            await UniversalBle.subscribeNotifications(
              deviceId,
              _actualTreadmillService!,
              _actualTreadmillDataChar!,
            );
            errorLog('[TreadmillControl] PitPat notify subscribed OK');
          } catch (e) {
            errorLog('[TreadmillControl] PitPat notify subscribe FAILED: $e');
          }
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
            final featBytes = await UniversalBle.read(
              deviceId,
              _actualTreadmillService!,
              _actualTreadmillFeatureChar ?? ftmsFeatureChar,
            );
            _parseFeatures(featBytes);
          } catch (_) {
            speedControlSupported = true;
            inclineControlSupported = true;
            notifyListeners();
          }
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
        _noWriteWithoutResponse.clear();

        treadmillDeviceId = null;
        treadmillName = null;

        if (workoutStatus == WorkoutStatus.running ||
            workoutStatus == WorkoutStatus.paused) {
          stopWorkout();
        }

        speed = 0.0;
        incline = 0.0;
        distance = 0.0;
        calories = 0;
        steps = 0;
        elapsedTime = 0;
        hrmHistory.clear();
        speedControlSupported = false;
        inclineControlSupported = false;
      }
      notifyListeners();
    } else if (deviceId == hrmDeviceId) {
      hrmConnection = state;
      if (state == BleConnectionState.connected) {
        savedHrmId = deviceId;
        savedHrmName = hrmName;
        unawaited(_persistSavedDevice(_savedHrmKey, deviceId, hrmName));
        final services = await UniversalBle.discoverServices(deviceId);

        final hrmProfile = resolveHrmGatt(services);
        _actualHrmService = hrmProfile.hrService;
        _actualHrmChar = hrmProfile.hrChar;
        _actualBatteryService = hrmProfile.batteryService;
        _actualBatteryChar = hrmProfile.batteryChar;

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
        hrmDeviceId = null;
        hrmName = null;
        heartRate = 0;
        hrmHistory.clear();
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
    final hr = decodeHeartRate(value);
    if (hr > 0) {
      heartRate = hr;
      hrmHistory.add(
        HeartRateHistoryPoint(timestamp: DateTime.now(), heartRate: hr),
      );
      notifyListeners();
    }
  }

  void _parseRscData(Uint8List value) {
    final stepsVal = decodeRscSteps(value);
    if (stepsVal == null) return;
    steps = stepsVal;
    notifyListeners();
  }

  void _parseFtmsData(Uint8List value) {
    final t = decodeFtmsTelemetry(value);
    if (t == null) return;

    speed = t.speed;
    if (speed <= 0.0) _awaitingSpeedZero = false;
    if (t.distance != null) distance = t.distance!;
    if (t.incline != null) incline = t.incline!;
    if (t.calories != null) calories = t.calories!;

    if (t.heartRate != null && hrmConnection != BleConnectionState.connected) {
      heartRate = t.heartRate!;
      if (t.heartRate! > 0) {
        hrmHistory.add(
          HeartRateHistoryPoint(
            timestamp: DateTime.now(),
            heartRate: t.heartRate!,
          ),
        );
      }
    }

    // Elapsed time from the treadmill only overrides while a workout runs.
    if (t.elapsedTimeSec != null && workoutStatus == WorkoutStatus.running) {
      elapsedTime = t.elapsedTimeSec!;
    }

    if (speed > 0.0) {
      _autoStartIfNeeded();
    }
    notifyListeners();
  }

  void _parsePitPatData(Uint8List value) {
    final frame = decodePitPatTelemetry(value);
    if (frame == null) {
      errorLog(
        '[TreadmillControl] PitPat packet too short (${value.length}<31), ignored',
      );
      return;
    }

    speed = frame.speed;
    if (speed <= 0.0) _awaitingSpeedZero = false;
    distance = frame.distance;
    calories = frame.calories;
    steps = frame.steps;
    if (workoutStatus == WorkoutStatus.running) {
      elapsedTime = (frame.durationMs / 1000).round();
    }

    // PitPat is state-driven: the running-state bits are authoritative, so the
    // session transitions follow them (never raw speed, which also ramps up
    // during deceleration after a stop).
    if (frame.runningStateBits == pitpatStateStarting) {
      workoutStatus = WorkoutStatus.starting;
    } else if (frame.runningStateBits == pitpatStateRunning) {
      if (workoutStatus == WorkoutStatus.paused) {
        // Resume from pause: keep accumulated metrics, restart data sampling.
        workoutStatus = WorkoutStatus.running;
        _startTimer();
      } else {
        // inactive / stopped / starting → begin a fresh session. Must run
        // through _autoStartIfNeeded so the timer, wake locks and data buffer
        // are actually initialised, not just the status flag.
        _autoStartIfNeeded();
      }
    } else if (frame.runningStateBits == pitpatStatePaused) {
      if (workoutStatus == WorkoutStatus.running) {
        workoutStatus = WorkoutStatus.paused;
        _workoutTimer?.cancel();
      }
    } else {
      if (workoutStatus == WorkoutStatus.running ||
          workoutStatus == WorkoutStatus.paused) {
        stopWorkout();
      } else {
        // Idle bits on an already-ended session mean the treadmill has settled,
        // so the coast-down guard can go even if no zero-speed frame ever
        // arrived - otherwise the next run on the treadmill itself records
        // nothing.
        _awaitingSpeedZero = false;
      }
    }

    notifyListeners();
  }

  void _autoStartIfNeeded() {
    // Don't relaunch while the treadmill is still coasting down from a stop.
    if (_awaitingSpeedZero) return;
    if (workoutStatus == WorkoutStatus.inactive ||
        workoutStatus == WorkoutStatus.stopped ||
        workoutStatus == WorkoutStatus.starting) {
      workoutStatus = WorkoutStatus.running;
      elapsedTime = 0;
      distance = 0.0;
      calories = 0;
      steps = 0;
      dataPoints.clear();
      _setWakeLock(true);
      _setSessionKeepAlive(true);
      _startTimer();
    }
  }

  Future<void> _writeTreadmill(
    String service,
    String characteristic,
    Uint8List value, {
    bool withoutResponse = false,
  }) async {
    if (treadmillDeviceId == null) return;
    final bool tryWithoutResponse =
        withoutResponse && !_noWriteWithoutResponse.contains(characteristic);
    try {
      await UniversalBle.write(
        treadmillDeviceId!,
        service,
        characteristic,
        value,
        withoutResponse: tryWithoutResponse,
      );
    } catch (e) {
      if (tryWithoutResponse) {
        // Characteristic only supports WriteWithResponse — remember and retry.
        _noWriteWithoutResponse.add(characteristic);
        try {
          await UniversalBle.write(
            treadmillDeviceId!,
            service,
            characteristic,
            value,
            withoutResponse: false,
          );
        } catch (e2) {
          errorLog('[TreadmillControl] write failed on $characteristic: $e2');
        }
      } else {
        errorLog('[TreadmillControl] write failed on $characteristic: $e');
      }
    }
  }

  // Android silently drops Write-Without-Response to a characteristic lacking
  // the no-response property (no throw), so the self-healing retry in
  // _writeTreadmill never triggers. Use Write-With-Response on Android.
  bool get _pitPatWithoutResponse =>
      defaultTargetPlatform != TargetPlatform.android;

  // Sends a PitPat control packet (START / PAUSE / STOP / SPEED).
  Future<void> _writePitPatCommand(String action, double speedKph) {
    return _writeTreadmill(
      _actualTreadmillService ?? pitpatService,
      _actualTreadmillWriteChar ?? pitpatWriteChar,
      makePitPatPacket(action, speedKph),
      withoutResponse: _pitPatWithoutResponse,
    );
  }

  // Workout Controls (Start, Incline, Speed)
  Future<void> startWorkout() async {
    // Resuming a paused session must keep what it already recorded.
    final resuming = workoutStatus == WorkoutStatus.paused;
    workoutStatus = WorkoutStatus.running;
    _awaitingSpeedZero = false;
    if (!resuming) {
      elapsedTime = 0;
      distance = 0.0;
      calories = 0;
      steps = 0;
      dataPoints.clear();
    }

    // Automatically trigger WakeLock
    _setWakeLock(true);
    _setSessionKeepAlive(true);
    _syncSessionChronometer(running: true);

    if (isSimulator) {
      speed = 3.0;
      incline = 0.0;
      _startTimer();
    } else {
      if (treadmillConnection == BleConnectionState.connected &&
          treadmillDeviceId != null) {
        if (treadmillType == TreadmillType.pitpat) {
          await _writePitPatCommand('START', speed > 0 ? speed : 1.0);
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
    _syncSessionChronometer(running: false);
    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType == TreadmillType.pitpat) {
        await _writePitPatCommand('PAUSE', speed);
      } else {
        await _sendFtmsControl(0x08, [0x02]); // Pause stop command
      }
    }
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> stopWorkout() async {
    workoutStatus = WorkoutStatus.stopped;
    _awaitingSpeedZero = true;
    _workoutTimer?.cancel();
    _workoutTimer = null;

    // Disable WakeLock
    _setWakeLock(false);
    _setSessionKeepAlive(false);

    if (!isSimulator &&
        treadmillConnection == BleConnectionState.connected &&
        treadmillDeviceId != null) {
      if (treadmillType == TreadmillType.pitpat) {
        await _writePitPatCommand('STOP', speed);
      } else {
        await _sendFtmsControl(0x08, [0x01]); // Stop command
      }
    }

    // Save session to DB
    if (dataPoints.isNotEmpty) {
      final session = TreadmillSession.fromWorkout(
        dataPoints: dataPoints,
        distance: distance,
        calories: calories,
        steps: steps,
        elapsedTime: elapsedTime,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );

      await TreadmillControlDb.instance.saveSession(session);
      await loadSessions();
      _backgroundSync();
    }
    await _clearSnapshot();

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
        await _writePitPatCommand('SPEED', targetSpeed);
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

  // Keeps the CPU and process alive while a session is active, so telemetry
  // keeps flowing even if the user lets the screen turn off. Held only for a
  // running/paused session; released on stop, reset, and dispose.
  Future<void> _setSessionKeepAlive(bool enable) async {
    if (enable) {
      _sessionCpuLease ??= await PowerWakeLockService.acquirePartial();
      _foregroundLease ??= await ForegroundRuntimeService.acquire(
        title: notificationTitle,
        text: notificationText,
        chronometerSinceMs:
            DateTime.now().millisecondsSinceEpoch - elapsedTime * 1000,
      );
    } else {
      final cpu = _sessionCpuLease;
      _sessionCpuLease = null;
      if (cpu != null) unawaited(cpu.release());
      final fg = _foregroundLease;
      _foregroundLease = null;
      if (fg != null) unawaited(fg.release());
    }
  }

  /// Re-arms or freezes the notification's ticking chronometer. The elapsed
  /// offset keeps the shown time correct across pause/resume of an
  /// accumulated session.
  void _syncSessionChronometer({required bool running}) {
    final ForegroundRuntimeLease? fg = _foregroundLease;
    if (fg == null) return;
    unawaited(
      fg.update(
        title: notificationTitle,
        text: notificationText,
        chronometerSinceMs: running
            ? DateTime.now().millisecondsSinceEpoch - elapsedTime * 1000
            : null,
      ),
    );
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
        if (heartRate > 0) {
          hrmHistory.add(
            HeartRateHistoryPoint(
              timestamp: DateTime.now(),
              heartRate: heartRate,
            ),
          );
        }
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

      if (elapsedTime % _snapshotEverySeconds == 0) unawaited(_saveSnapshot());

      notifyListeners();
    });
  }

  void toggleSimulator(bool enable) {
    isSimulator = enable;
    if (enable) {
      speedControlSupported = true;
      inclineControlSupported = true;
      disconnectTreadmill();
    } else {
      speedControlSupported = false;
      inclineControlSupported = false;
      if (workoutStatus == WorkoutStatus.running) {
        stopWorkout();
      }
    }
    notifyListeners();
  }

  // PitPat Commands & Heartbeats
  void _startPitPatHeartbeat() {
    _pitpatHeartbeatTimer?.cancel();
    _pitpatHeartbeatTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (treadmillConnection == BleConnectionState.connected &&
          treadmillDeviceId != null) {
        await _writeTreadmill(
          _actualTreadmillService ?? pitpatService,
          _actualTreadmillWriteChar ?? pitpatWriteChar,
          pitpatHeartbeatPacket,
          withoutResponse: _pitPatWithoutResponse,
        );
      } else {
        _stopPitPatHeartbeat();
      }
    });
  }

  void _stopPitPatHeartbeat() {
    _pitpatHeartbeatTimer?.cancel();
    _pitpatHeartbeatTimer = null;
  }

  Future<void> _sendFtmsControl(int command, List<int> params) async {
    if (treadmillDeviceId == null) return;
    final service = _actualTreadmillService ?? ftmsService;
    final cpChar = _actualTreadmillControlPointChar ?? ftmsControlPointChar;

    if (!_isControlRequested) {
      await _writeTreadmill(
        service,
        cpChar,
        Uint8List.fromList([0x00]),
        withoutResponse: false,
      );
      _isControlRequested = true;
    }

    final payload = Uint8List.fromList([command, ...params]);
    await _writeTreadmill(service, cpChar, payload, withoutResponse: false);
  }

  // Delete / Clear Logs
  Future<void> deleteSession(int id) async {
    await TreadmillControlDb.instance.softDeleteSession(id);
    await loadSessions();
    _backgroundSync();
  }

  Future<int> importSessions(List<TreadmillSession> sessions) async {
    final importedCount = await TreadmillControlDb.instance.importSessions(
      sessions,
    );
    await loadSessions();
    _backgroundSync();
    return importedCount;
  }

  void _parseFeatures(Uint8List value) {
    final support = decodeFtmsFeatures(value);
    if (support == null) return;
    speedControlSupported = support.speed;
    inclineControlSupported = support.incline;
    notifyListeners();
  }

  void resetState({bool notify = true}) {
    stopScan();
    disconnectTreadmill(notify: notify);
    disconnectHrm(notify: notify);
    _setSessionKeepAlive(false);
    _setWakeLock(false);

    speed = 0.0;
    incline = 0.0;
    heartRate = 0;
    distance = 0.0;
    calories = 0;
    steps = 0;
    elapsedTime = 0;
    batteryLevel = null;
    workoutStatus = WorkoutStatus.inactive;
    dataPoints.clear();
    discoveredTreadmills.clear();
    discoveredHrms.clear();
    isScanning = false;
    hrmHistory.clear();
    speedControlSupported = false;
    inclineControlSupported = false;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _workoutTimer?.cancel();
    _pitpatHeartbeatTimer?.cancel();
    _scanSubscription?.cancel();
    _setWakeLock(false);
    _setSessionKeepAlive(false);
    super.dispose();
  }
}
