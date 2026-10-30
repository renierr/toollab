import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/tool_vault_crypto.dart';
import 'package:tool_lab/services/database_service.dart';

class ExistingToolPasswordMismatch implements Exception {}

class ToolLockSession {
  const ToolLockSession(this.key, this.password);
  final SecretKey key;
  final String password;
}

class ToolLockController extends ChangeNotifier {
  ToolLockController({required this.toolId, required this.envelopeSetting});

  static final Map<String, ToolLockSession> _sessions = {};
  static ToolLockSession? sessionFor(String toolId) => _sessions[toolId];

  final String toolId;
  final String envelopeSetting;
  final _storage = const FlutterSecureStorage();
  static const _biometricChannel = MethodChannel(
    'de.renier.tool_lab/tool_biometric_storage',
  );
  String get _preferenceKey => 'tool_lock_${toolId}_automatic';
  String get _attemptKey => 'tool_lock_${toolId}_attempts';
  String get _biometricKey => 'tool_lock_${toolId}_biometric';
  String get _biometricTimeoutKey => 'tool_lock_${toolId}_biometric_timeout';
  AndroidOptions get _biometricOptions => AndroidOptions.biometric(
    storageNamespace: 'tool_lock_$toolId',
    enforceBiometrics: true,
    resetOnError: false,
  );

  Future<T?> _biometricOperation<T>(String operation, {String? value}) =>
      _biometricChannel.invokeMethod<T>(operation, {
        'key': toolId,
        'options': _biometricOptions.toMap(),
        'minutes': biometricTimeoutMinutes,
        'value': ?value,
      });

  String? _envelope;
  int attempts = 0;
  bool automatic = false;
  bool biometric = false;
  static const biometricTimeouts = [0, 1, 5, 15, 30, 60];
  int biometricTimeoutMinutes = 5;
  bool initialized = false;
  int _generation = 0;
  int get generation => _generation;
  bool get configured => _envelope != null;
  bool get unlocked => _sessions.containsKey(toolId);
  bool get canReset => attempts >= 5;
  bool get supportsBiometric => !kIsWeb && Platform.isAndroid;

  Future<void> initialize() async {
    initialized = false;
    notifyListeners();
    _envelope = await DatabaseService.instance.getSetting(
      toolId,
      envelopeSetting,
    );
    attempts = int.tryParse(await _storage.read(key: _attemptKey) ?? '') ?? 0;
    automatic = await _storage.read(key: _preferenceKey) != null;
    biometric = (await _storage.read(key: _biometricKey)) == 'true';
    final timeout = int.tryParse(
      await _storage.read(key: _biometricTimeoutKey) ?? '',
    );
    biometricTimeoutMinutes = biometricTimeouts.contains(timeout)
        ? timeout!
        : 5;
    initialized = true;
    notifyListeners();
  }

  Future<void> setup(
    String password,
    Future<void> Function(SecretKey key, String wrappedKey) migrate,
  ) async {
    if (configured) throw StateError('Vault already exists');
    final generation = _generation;
    final key = await ToolVaultCrypto.newDataKey();
    final envelope = await ToolVaultCrypto.wrapKey(key, password);
    try {
      await migrate(key, envelope);
    } catch (_) {
      _envelope = await DatabaseService.instance.getSetting(
        toolId,
        envelopeSetting,
      );
      notifyListeners();
      rethrow;
    }
    _envelope = envelope;
    attempts = 0;
    await _storage.delete(key: _attemptKey);
    if (generation == _generation) {
      _sessions[toolId] = ToolLockSession(key, password);
    }
    notifyListeners();
  }

  Future<bool> unlock(String password, {bool countFailure = true}) async {
    final envelope = _envelope;
    if (envelope == null) throw StateError('Vault is not configured');
    final generation = _generation;
    try {
      final key = await ToolVaultCrypto.unwrapKey(envelope, password);
      if (generation != _generation) return false;
      _sessions[toolId] = ToolLockSession(key, password);
      attempts = 0;
      await _storage.delete(key: _attemptKey);
      notifyListeners();
      return true;
    } on SecretBoxAuthenticationError {
      if (generation != _generation) return false;
      if (countFailure) {
        await recordFailure();
      }
      return false;
    }
  }

  Future<void> recordFailure() async {
    attempts++;
    await _storage.write(key: _attemptKey, value: attempts.toString());
    notifyListeners();
  }

  Future<bool> unlockBiometric() async {
    if (!supportsBiometric || !biometric) return false;
    final generation = _generation;
    final password = await _biometricOperation<String>('read');
    if (generation != _generation) return false;
    return password != null && await unlock(password, countFailure: false);
  }

  Future<bool> unlockAutomatically() async {
    if (!automatic || !configured) return false;
    if (unlocked) return true;
    final generation = _generation;
    final password = await _storage.read(key: _preferenceKey);
    if (generation != _generation) return false;
    return password != null && await unlock(password, countFailure: false);
  }

  Future<void> setAutomatic(bool enabled) async {
    final session = _sessions[toolId];
    if (session == null) throw StateError('Vault is locked');
    if (enabled) {
      await _storage.write(key: _preferenceKey, value: session.password);
    } else {
      await _storage.delete(key: _preferenceKey);
    }
    automatic = enabled;
    notifyListeners();
  }

  Future<void> setBiometric(bool enabled) async {
    if (!supportsBiometric) throw UnsupportedError('Biometrics unavailable');
    final session = _sessions[toolId];
    if (session == null) throw StateError('Vault is locked');
    if (enabled) {
      await _biometricOperation<void>('write', value: session.password);
      await _storage.write(key: _biometricKey, value: 'true');
    } else {
      await _biometricOperation<void>('delete');
      await _storage.delete(key: _biometricKey);
    }
    biometric = enabled;
    notifyListeners();
  }

  Future<void> setBiometricTimeout(int minutes) async {
    if (!biometricTimeouts.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await _storage.write(key: _biometricTimeoutKey, value: '$minutes');
    biometricTimeoutMinutes = minutes;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required Future<void> Function(String oldEnvelope, String newEnvelope)
    commit,
  }) async {
    if (newPassword.length < 8) throw ArgumentError('Password too short');
    final oldEnvelope = _envelope;
    final session = _sessions[toolId];
    if (session == null || oldEnvelope == null) {
      throw StateError('Vault is locked');
    }
    final generation = _generation;
    await ToolVaultCrypto.unwrapKey(oldEnvelope, currentPassword);
    final newEnvelope = await ToolVaultCrypto.wrapKey(session.key, newPassword);
    void checkSession() {
      if (generation != _generation || !identical(session, _sessions[toolId])) {
        throw StateError('Vault session changed');
      }
    }

    checkSession();
    if (automatic) await setAutomatic(false);
    checkSession();
    if (biometric) await setBiometric(false);
    checkSession();
    await commit(oldEnvelope, newEnvelope);
    _envelope = newEnvelope;
    if (generation == _generation && identical(session, _sessions[toolId])) {
      _sessions[toolId] = ToolLockSession(session.key, newPassword);
    }
    notifyListeners();
  }

  void lock() {
    _generation++;
    _sessions.remove(toolId);
    notifyListeners();
  }

  Future<void> reset(Future<void> Function() deleteData) async {
    if (!canReset) throw StateError('Reset requires five failed attempts');
    await deleteData();
    _sessions.remove(toolId);
    _envelope = null;
    await _storage.delete(key: _preferenceKey);
    await _storage.delete(key: _attemptKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _biometricTimeoutKey);
    if (supportsBiometric && biometric) {
      try {
        await _biometricOperation<void>('delete');
      } catch (e) {
        errorLog(
          '[ToolLockController] Could not remove biometric credential: $e',
        );
      }
    }
    automatic = false;
    biometric = false;
    biometricTimeoutMinutes = 5;
    attempts = 0;
    notifyListeners();
  }
}
