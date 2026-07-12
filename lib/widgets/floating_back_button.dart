import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// A premium, floating circular back button that can be positioned
/// in full-screen pages to save vertical space.
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isRoot = GoRouterState.of(context).matchedLocation == '/';

    if (!canPop && isRoot) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withAlpha(200),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
        onPressed: () {
          if (canPop) {
            Navigator.of(context).maybePop();
          } else {
            context.go('/');
          }
        },
        tooltip: canPop ? l10n.commonBack : l10n.commonHome,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
