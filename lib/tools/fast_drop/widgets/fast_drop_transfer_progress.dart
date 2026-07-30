import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../fast_drop_state.dart';
import 'fast_drop_progress_indicator.dart';

class FastDropTransferProgress extends StatelessWidget {
  const FastDropTransferProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FastDropState>();
    return ValueListenableBuilder<int>(
      valueListenable: state.transferProgressRevision,
      builder: (context, _, child) {
        final upload = state.fastDropUploadProgress;
        if (state.isUploadingFastDrop && upload != null) {
          return _Progress(
            isUpload: true,
            sent: upload.$1,
            total: upload.$2,
            startedAt: state.transferStartedAt,
          );
        }

        final download = state.fastDropDownloadProgress;
        if (state.isDownloadingFastDrop && download != null) {
          return _Progress(
            isUpload: false,
            sent: download.$1,
            total: download.$2,
            startedAt: state.transferStartedAt,
          );
        }

        return const SizedBox();
      },
    );
  }
}

class _Progress extends StatelessWidget {
  final bool isUpload;
  final int sent;
  final int total;
  final DateTime? startedAt;

  const _Progress({
    required this.isUpload,
    required this.sent,
    required this.total,
    required this.startedAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FastDropProgressIndicator(
      label: isUpload
          ? l10n.fastDropProgressUploading
          : l10n.fastDropProgressDownloading,
      sent: sent,
      total: total,
      startedAt: startedAt,
      onCancel: isUpload
          ? () => context.read<FastDropState>().cancelUploadFastDrop()
          : () => context.read<FastDropState>().cancelDownloadFastDrop(),
    );
  }
}
