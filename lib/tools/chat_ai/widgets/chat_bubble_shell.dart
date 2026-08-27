import 'package:flutter/material.dart';

/// Padding, alignment, width cap and rounded background shared by the message
/// and thinking bubbles. The cap follows the room the list gives it, not the
/// window, so bubbles stay sane inside a pane or split view.
class ChatBubbleShell extends StatelessWidget {
  final bool fromUser;
  final Widget child;

  const ChatBubbleShell({
    super.key,
    required this.fromUser,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
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
      ),
    );
  }
}
