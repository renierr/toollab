import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

/// Padding, alignment, width cap and rounded background shared by the message
/// and thinking bubbles. The cap follows the room the list gives it, not the
/// window, so bubbles stay sane inside a pane or split view.
class ChatBubbleShell extends StatelessWidget {
  final bool fromUser;
  final Widget child;

  /// Lets a reply span the full row, as when the chat text is enlarged.
  /// Replies on a compact row always do.
  final bool expand;

  const ChatBubbleShell({
    super.key,
    required this.fromUser,
    required this.child,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.isCompact;
        final side = compact ? 8.0 : 16.0;
        final fill = !fromUser && (expand || compact);
        final room = constraints.maxWidth - side * 2;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: side),
          child: Align(
            alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: fill ? room : room * 0.8),
              decoration: BoxDecoration(
                color: fromUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16.0),
                  topRight: const Radius.circular(16.0),
                  bottomLeft: fromUser
                      ? const Radius.circular(16.0)
                      : Radius.zero,
                  bottomRight: fromUser
                      ? Radius.zero
                      : const Radius.circular(16.0),
                ),
              ),
              padding: const EdgeInsets.all(12.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
