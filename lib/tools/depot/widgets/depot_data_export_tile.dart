import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_data_export.dart';

class DepotDataExportTile extends StatefulWidget {
  const DepotDataExportTile({super.key});

  @override
  State<DepotDataExportTile> createState() => _DepotDataExportTileState();
}

class _DepotDataExportTileState extends State<DepotDataExportTile>
    with DisposeCleanup {
  late final TempFileScope _scope;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final name =
          'depot-export-${now.year}-${'${now.month}'.padLeft(2, '0')}-'
          '${'${now.day}'.padLeft(2, '0')}.zip';
      final path = await _scope.createFile(
        name,
        bytes: await DepotDataExport.zip(_scope),
      );
      if (!mounted) return;
      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: name,
        sourcePath: path,
        successMessageAndroid: l10n.depotExportDone,
        successMessageGeneralBuilder: (shown) =>
            '${l10n.depotExportDone}\n$shown',
      );
    } catch (e) {
      errorLog('[DepotDataExportTile] Export failed: $e');
      if (mounted) {
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(title: l10n.depotExportSection),
        ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text(l10n.depotExportTitle),
          subtitle: Text(l10n.depotExportSubtitle),
          trailing: _exporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          onTap: _exporting ? null : _export,
        ),
      ],
    );
  }
}
