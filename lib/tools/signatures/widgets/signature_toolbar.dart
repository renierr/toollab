import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../signatures_state.dart';

/// Action bar below the canvas. Undo/redo/clear act on state directly;
/// export/copy/save are delegated to the page (they need platform helpers).
class SignatureToolbar extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;
  final VoidCallback onSave;

  const SignatureToolbar({
    super.key,
    required this.onCopy,
    required this.onShare,
    required this.onExportPng,
    required this.onExportSvg,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SignaturesState>();
    final hasContent = !state.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          ToolChip(
            icon: Icons.undo,
            label: l10n.sigUndo,
            showLabel: false,
            onTap: state.canUndo
                ? () => context.read<SignaturesState>().undo()
                : () {},
          ),
          ToolChip(
            icon: Icons.redo,
            label: l10n.sigRedo,
            showLabel: false,
            onTap: state.canRedo
                ? () => context.read<SignaturesState>().redo()
                : () {},
          ),
          ToolChip(
            icon: Icons.delete_outline,
            label: l10n.commonClear,
            onTap: hasContent
                ? () => context.read<SignaturesState>().clear()
                : () {},
          ),
          ToolChip(
            icon: Icons.copy_outlined,
            label: l10n.commonCopy,
            onTap: hasContent ? onCopy : () {},
          ),
          ToolChip(
            icon: Icons.share_outlined,
            label: l10n.commonShare,
            onTap: hasContent ? onShare : () {},
          ),
          ToolChip(
            icon: Icons.image_outlined,
            label: l10n.sigPng,
            onTap: hasContent ? onExportPng : () {},
          ),
          ToolChip(
            icon: Icons.polyline_outlined,
            label: l10n.sigSvg,
            onTap: hasContent ? onExportSvg : () {},
          ),
          ToolChip(
            icon: Icons.save_outlined,
            label: l10n.commonSave,
            selected: hasContent,
            onTap: hasContent ? onSave : () {},
          ),
        ],
      ),
    );
  }
}
