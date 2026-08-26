import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

/// Selection toolbar for the editor: Material selection menu on touch
/// devices, a popup menu on desktop. Handles cut/copy/paste/select all.
class TextEditorSelectionToolbar implements SelectionToolbarController {
  const TextEditorSelectionToolbar();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    if (_isTouchDevice(context)) {
      _MobileController().show(
        context: context,
        controller: controller,
        anchors: anchors,
        renderRect: renderRect,
        layerLink: layerLink,
        visibility: visibility,
      );
      return;
    }
    _showDesktopMenu(context, controller, anchors);
  }

  static bool _isTouchDevice(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
  }

  Future<void> _showDesktopMenu(
    BuildContext context,
    CodeLineEditingController controller,
    TextSelectionToolbarAnchors anchors,
  ) async {
    final l10n = AppLocalizations.of(context);
    final hasSelection = !controller.selection.isCollapsed;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromSize(
        anchors.primaryAnchor & const Size(180, double.infinity),
        MediaQuery.sizeOf(context),
      ),
      items: [
        PopupMenuItem(
          enabled: hasSelection,
          onTap: controller.cut,
          child: Text(l10n.commonCut),
        ),
        PopupMenuItem(
          enabled: hasSelection,
          onTap: controller.copy,
          child: Text(l10n.commonCopy),
        ),
        PopupMenuItem(onTap: controller.paste, child: Text(l10n.commonPaste)),
        PopupMenuItem(
          onTap: controller.selectAll,
          child: Text(l10n.textEditorSelectAll),
        ),
      ],
    );
  }
}

/// Delegates to re_editor's mobile overlay machinery, which handles anchoring
/// and dismissal; we only supply the button row.
class _MobileController implements MobileSelectionToolbarController {
  _MobileController();

  late final MobileSelectionToolbarController _delegate =
      MobileSelectionToolbarController(builder: _buildMenu);

  Widget _buildMenu({
    required BuildContext context,
    required TextSelectionToolbarAnchors anchors,
    required CodeLineEditingController controller,
    required VoidCallback onDismiss,
    required VoidCallback onRefresh,
  }) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = !controller.selection.isCollapsed;
    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        _ToolbarButton(
          label: l10n.commonCut,
          onPressed: hasSelection
              ? () {
                  controller.cut();
                  onDismiss();
                }
              : null,
        ),
        _ToolbarButton(
          label: l10n.commonCopy,
          onPressed: hasSelection
              ? () {
                  controller.copy();
                  onDismiss();
                }
              : null,
        ),
        _ToolbarButton(
          label: l10n.commonPaste,
          onPressed: () {
            controller.paste();
            onDismiss();
          },
        ),
        _ToolbarButton(
          label: l10n.textEditorSelectAll,
          onPressed: () {
            controller.selectAll();
            onDismiss();
          },
        ),
      ],
    );
  }

  @override
  void hide(BuildContext context) => _delegate.hide(context);

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    ui.Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _delegate.show(
      context: context,
      controller: controller,
      anchors: anchors,
      renderRect: renderRect,
      layerLink: layerLink,
      visibility: visibility,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: onPressed == null
                ? theme.colorScheme.outline
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
