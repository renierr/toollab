import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_ble_probe_state.dart';

/// Reads a Renpho export — the cloud response, a helper script's dump, or this
/// tool's own sync payload — into the local history.
class RenphoImportTile extends StatefulWidget {
  const RenphoImportTile({super.key});

  @override
  State<RenphoImportTile> createState() => _RenphoImportTileState();
}

class _RenphoImportTileState extends State<RenphoImportTile> {
  static const _typeGroup = XTypeGroup(
    label: 'Renpho export',
    extensions: ['json'],
  );

  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.file_upload_outlined),
      title: Text(l10n.renphoImportTitle),
      subtitle: Text(l10n.renphoImportSubtitle),
      trailing: _running
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _running ? null : _import,
    );
  }

  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final state = context.read<RenphoBleProbeState>();
    setState(() => _running = true);
    try {
      final source = await File(file.path).readAsString();
      final outcome = await state.importFromJson(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.isEmpty
                ? l10n.renphoImportNothing
                : l10n.renphoImportDone(
                    outcome.added,
                    outcome.duplicates,
                    outcome.skipped,
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }
}
