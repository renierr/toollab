import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';

class ToolLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final bool fullscreen;
  final List<Widget>? actions;
  final bool showFloatingBackButton;

  const ToolLayout({
    super.key,
    required this.title,
    required this.child,
    this.fullscreen = false,
    this.actions,
    this.showFloatingBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShort = MediaQuery.of(context).size.height < 600;
    final appBarHeight = isShort ? 40.0 : 56.0;

    return Scaffold(
      appBar: fullscreen
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(appBarHeight),
              child: AppBar(
                toolbarHeight: appBarHeight,
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: isShort ? 16.0 : 20.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: actions,
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            child,
            if (fullscreen && showFloatingBackButton) ...[
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
