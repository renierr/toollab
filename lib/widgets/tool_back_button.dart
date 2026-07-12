import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// A premium, reusable back/home button for tools that automatically adapts
/// to show either an "arrow_back" (if pop-able) or a "home" icon (if not pop-able).
class ToolBackButton extends StatelessWidget {
  final Color? color;
  final double iconSize;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final ButtonStyle? style;

  /// An optional callback to run (such as confirming edit discards) before executing navigation.
  /// If it returns false, navigation is aborted.
  final Future<bool> Function()? onConfirm;

  const ToolBackButton({
    super.key,
    this.color,
    this.iconSize = 24.0,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isRoot = GoRouterState.of(context).matchedLocation == '/';

    if (!canPop && isRoot) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
      color: color,
      iconSize: iconSize,
      visualDensity: visualDensity,
      padding: padding,
      constraints: constraints,
      style: style,
      tooltip: canPop ? l10n.commonBack : l10n.commonHome,
      onPressed: () async {
        if (onConfirm != null) {
          final proceed = await onConfirm!();
          if (!proceed) return;
        }
        if (context.mounted) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.maybePop();
          } else {
            GoRouter.of(context).go('/');
          }
        }
      },
    );
  }
}
