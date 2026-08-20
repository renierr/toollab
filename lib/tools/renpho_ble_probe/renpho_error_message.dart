import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_ble_probe_state.dart';

/// Turns a scan failure into text. The technical detail is appended only when
/// the platform gave one, because "connect failed: null" helps nobody.
String renphoErrorMessage(
  AppLocalizations l10n,
  RenphoFailure failure,
  String? detail,
) {
  final message = switch (failure) {
    RenphoFailure.bluetoothUnavailable => l10n.renphoErrorBluetooth,
    RenphoFailure.scanFailed => l10n.renphoErrorScan,
    RenphoFailure.notFound => l10n.renphoErrorNotFound,
    RenphoFailure.connectFailed => l10n.renphoErrorConnect,
    RenphoFailure.setupFailed => l10n.renphoErrorSetup,
    RenphoFailure.saveFailed => l10n.renphoErrorSave,
  };
  final trimmed = detail?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return message;
  return '$message ($trimmed)';
}
