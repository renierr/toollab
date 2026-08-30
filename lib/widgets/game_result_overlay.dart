import 'package:flutter/material.dart';

/// The panel a game drops over its board when a run ends.
///
/// Scrolls and caps its width, so a win on a 320-wide phone in landscape shows
/// the same content as one on a desktop window. The entry animation is not
/// decoration: a panel that fades and lifts into place reads as a response to
/// the last move, where one that appears instantly reads as a crash.
class GameResultOverlay extends StatelessWidget {
  final String title;

  /// The one number that matters — the score, the time, the reached level.
  final String headline;
  final Color headlineColor;

  final String subtitle;
  final String? footnote;

  /// Primary action first; it gets the filled button.
  final List<GameResultAction> actions;

  /// Focuses the primary action as the panel appears, so a keyboard player can
  /// answer it with Enter. Off by default: a game whose board is driven from a
  /// focus node of its own would lose the keyboard to this and never get it
  /// back once the panel closes.
  final bool autofocusPrimary;

  /// Focus for the primary action. A page that holds keyboard focus of its own
  /// must hand it over here when the panel opens: `autofocus` is discarded when
  /// the surrounding scope already has a focused node, so a game driving its
  /// board from a focus node would otherwise leave these buttons unreachable.
  final FocusNode? primaryFocusNode;

  /// Painted behind the panel at high opacity, normally the game's own board
  /// colour so the overlay reads as part of the board rather than app chrome.
  final Color scrimColor;

  const GameResultOverlay({
    super.key,
    required this.title,
    required this.headline,
    required this.headlineColor,
    required this.subtitle,
    required this.actions,
    required this.scrimColor,
    this.footnote,
    this.autofocusPrimary = false,
    this.primaryFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => ColoredBox(
        color: scrimColor.withValues(alpha: 0.88 * t),
        child: Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  headline,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: headlineColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                if (footnote != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    footnote!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                for (var i = 0; i < actions.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: i == 0
                        ? FilledButton.icon(
                            autofocus: autofocusPrimary,
                            focusNode: primaryFocusNode,
                            onPressed: actions[i].onPressed,
                            icon: Icon(actions[i].icon),
                            label: Text(actions[i].label),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: actions[i].onPressed,
                            icon: Icon(actions[i].icon),
                            label: Text(actions[i].label),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One button on a [GameResultOverlay].
class GameResultAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const GameResultAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
