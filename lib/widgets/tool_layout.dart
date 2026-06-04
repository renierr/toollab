import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';

class ToolLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final bool fullscreen;
  final List<Widget>? actions;

  const ToolLayout({
    super.key,
    required this.title,
    required this.child,
    this.fullscreen = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: fullscreen ? null : AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Stack(
          children: [
            child,
            if (fullscreen) ...[
              const Positioned(left: 12, top: 12, child: FloatingBackButton()),
              if (actions != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!.map((action) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Material(
                          color: theme.colorScheme.surface.withAlpha(200),
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: action,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
