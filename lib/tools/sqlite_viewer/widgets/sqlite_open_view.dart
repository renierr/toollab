import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../config.dart';
import '../db/sqlite_models.dart';
import '../sqlite_viewer_state.dart';
import 'sqlite_internal_db_list.dart';

class SqliteOpenView extends StatelessWidget {
  final ValueChanged<XFile> onFileSelected;
  final TempFileScope tempScope;

  const SqliteOpenView({
    super.key,
    required this.onFileSelected,
    required this.tempScope,
  });

  String _errorMessage(AppLocalizations l10n, SqliteViewerState state) {
    return switch (state.openFailure!) {
      SqliteOpenFailure.missing => l10n.sqliteViewerErrorMissing,
      SqliteOpenFailure.notSqlite => l10n.sqliteViewerErrorNotSqlite,
      SqliteOpenFailure.locked => l10n.sqliteViewerErrorLocked,
      SqliteOpenFailure.unknown => l10n.sqliteViewerErrorUnknown(
        state.openDetail ?? '',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SqliteViewerState>();
    final accent = SqliteViewerTool.config.accentColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.openFailure != null) ...[
            InfoCard(
              icon: Icons.error_outline,
              title: l10n.commonError,
              titleColor: AppTheme.statusRed,
              borderColor: AppTheme.statusRed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_errorMessage(l10n, state)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: state.clearOpenError,
                      child: Text(l10n.commonClose),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 320,
            child: FileDropZone(
              onFileSelected: onFileSelected,
              allowedExtensions: SqliteViewerTool.config.fileExtensions,
              allowedMimeTypes: const ['*/*'],
              typeLabel: l10n.sqliteViewerTypeLabel,
              accentColor: accent,
              icon: Icons.storage_outlined,
              title: l10n.sqliteViewerOpenTitle,
              subtitle: l10n.sqliteViewerDropSubtitle,
              useAndroidStreamingPicker: true,
              tempScope: tempScope,
            ),
          ),
          const SizedBox(height: 16),
          CollapsibleSection(
            icon: Icons.inventory_2_outlined,
            iconColor: accent,
            title: l10n.sqliteViewerInternalTitle,
            initiallyExpanded: false,
            child: const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: SqliteInternalDbList(),
            ),
          ),
          if (state.isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
