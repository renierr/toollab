import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../fast_drop_state.dart';
import 'fast_drop_progress_indicator.dart';

class FastDropTransferProgress extends StatelessWidget {
  const FastDropTransferProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final transfer = context.select<FastDropState, (bool, int, int)?>((state) {
      final upload = state.fastDropUploadProgress;
      if (state.isUploadingFastDrop && upload != null) {
        return (true, upload.$1, upload.$2);
      }

      final download = state.fastDropDownloadProgress;
      if (state.isDownloadingFastDrop && download != null) {
        return (false, download.$1, download.$2);
      }

      return null;
    });

    if (transfer == null) return const SizedBox();

    final l10n = AppLocalizations.of(context);
    return FastDropProgressIndicator(
      label: transfer.$1
          ? l10n.fastDropProgressUploading
          : l10n.fastDropProgressDownloading,
      sent: transfer.$2,
      total: transfer.$3,
      onCancel: transfer.$1
          ? () => context.read<FastDropState>().cancelUploadFastDrop()
          : () => context.read<FastDropState>().cancelDownloadFastDrop(),
    );
  }
}
