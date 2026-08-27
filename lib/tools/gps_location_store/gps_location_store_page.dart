import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'gps_location_store_state.dart';
import 'location_capture_service.dart';
import 'saved_location.dart';
import 'widgets/current_location_card.dart';
import 'widgets/last_location_card.dart';
import 'widgets/location_description_dialog.dart';
import 'widgets/location_list.dart';

class GpsLocationStorePage extends StatefulWidget {
  const GpsLocationStorePage({super.key});

  @override
  State<GpsLocationStorePage> createState() => _GpsLocationStorePageState();
}

class _GpsLocationStorePageState extends State<GpsLocationStorePage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsLocationStoreState>().load();
    });
  }

  Future<void> _locate() async {
    final state = context.read<GpsLocationStoreState>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await state.locateCurrent();
    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.gpsStoreCaptureFailed),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _saveFix(LocationFix fix) async {
    final state = context.read<GpsLocationStoreState>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final description = await LocationDescriptionDialog.show(
      context: context,
      title: l10n.gpsStoreSaveLocationTitle,
      confirmLabel: l10n.commonSave,
      fix: fix,
    );
    if (description == null) return;

    await state.saveFix(fix, description);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.gpsStoreLocationSaved),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _editDescription(SavedLocation location) async {
    final state = context.read<GpsLocationStoreState>();
    final l10n = AppLocalizations.of(context);
    final description = await LocationDescriptionDialog.show(
      context: context,
      title: l10n.gpsStoreEditDescription,
      confirmLabel: l10n.commonSave,
      initialDescription: location.description,
    );
    if (description == null) return;
    await state.updateDescription(location.id, description);
  }

  Future<void> _deleteLocation(SavedLocation location) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.gpsStoreDeleteTitle,
      message: l10n.gpsStoreDeleteMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<GpsLocationStoreState>().deleteLocation(location.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<GpsLocationStoreState>();
    final locations = state.locations;
    final current = state.currentPosition;
    final last = state.lastLocation;
    final history = locations.length > 1
        ? locations.sublist(1)
        : <SavedLocation>[];

    final hasContent = current != null || locations.isNotEmpty;

    return ToolLayout(
      title: GpsLocationStoreTool.config.localizedName(l10n),
      actions: [
        IconButton(
          icon: const Icon(Icons.satellite_alt_outlined),
          tooltip: l10n.gpsInfoButtonTooltip,
          onPressed: () => context.push('/gps-location-store/gps-info'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLocatingCurrent ? null : _locate,
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: state.isLocatingCurrent
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.my_location),
        label: Text(l10n.gpsStoreLocateButton),
      ),
      child: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
              ),
            )
          : !hasContent
          ? _EmptyState(
              onLocate: state.isLocatingCurrent ? null : _locate,
              isLocating: state.isLocatingCurrent,
            )
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (current != null) ...[
                    CurrentLocationCard(
                      fix: current,
                      isLocating: state.isLocatingCurrent,
                      onRefresh: _locate,
                      onSave: () => _saveFix(current),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (last != null)
                    LastLocationCard(location: last, currentPosition: current),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    LocationList(
                      locations: history,
                      currentPosition: current,
                      onEditDescription: _editDescription,
                      onDelete: _deleteLocation,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onLocate;
  final bool isLocating;

  const _EmptyState({this.onLocate, required this.isLocating});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_searching,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.gpsStoreEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.gpsStoreEmptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onLocate,
              icon: isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(l10n.gpsStoreLocateButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
