import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_ble_probe_state.dart';
import 'renpho_device_sheet.dart';
import 'renpho_health_connect_actions.dart';
import 'renpho_import_tile.dart';
import 'renpho_profile_dialog.dart';

/// Tool-local settings. Backend sync stays with the global switch in the app
/// settings; only the Health Connect export is decided here.
class RenphoSettingsSheet extends StatelessWidget {
  const RenphoSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const RenphoSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Material rather than a decorated box: the list tiles paint their
    // background and ink on the nearest Material ancestor.
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.renphoSettingsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.renphoProfileTitle),
                subtitle: Text(
                  '${state.profile.name} · '
                  '${state.profile.sex == 'male' ? l10n.renphoSexMale : l10n.renphoSexFemale} · '
                  '${state.profile.heightCm.toStringAsFixed(1)} cm',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final profile = await RenphoProfileDialog.show(
                    context,
                    profile: state.profile,
                  );
                  if (profile != null) await state.saveProfile(profile);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bluetooth_searching),
                title: Text(l10n.renphoDevicesTitle),
                subtitle: Text(
                  state.rememberedDeviceId == null
                      ? l10n.renphoNoRememberedDevice
                      : '${state.deviceName ?? ''} ${state.rememberedDeviceId}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  RenphoDeviceSheet.show(context);
                },
              ),
              const Divider(),
              const RenphoImportTile(),
              if (Platform.isAndroid) ...[
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.health_and_safety_outlined),
                  title: Text(l10n.renphoSyncToHealthConnect),
                  subtitle: Text(l10n.renphoSyncToHealthConnectSubtitle),
                  value: state.healthConnectEnabled,
                  onChanged: state.setHealthConnectEnabled,
                ),
                const RenphoHealthConnectActions(),
              ],
              const Divider(),
              Text(
                l10n.renphoBackendSyncHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
