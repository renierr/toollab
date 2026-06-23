import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';

class ToolLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final bool fullscreen;
  final List<Widget>? actions;
  final bool showFloatingBackButton;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const ToolLayout({
    super.key,
    required this.title,
    required this.child,
    this.fullscreen = false,
    this.actions,
    this.showFloatingBackButton = true,
    this.drawer,
    this.endDrawer,
    this.leading,
    this.floatingActionButton,
    this.backgroundColor,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShort = MediaQuery.of(context).size.height < 600;
    final appBarHeight = isShort ? 40.0 : 56.0;

    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
      appBar: fullscreen
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(appBarHeight),
              child: AppBar(
                toolbarHeight: appBarHeight,
                leading:
                    leading ??
                    (Navigator.of(context).canPop()
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null),
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
            if (fullscreen && showFloatingBackButton)
              const Positioned(left: 12, top: 12, child: FloatingBackButton()),
            if (fullscreen && actions != null)
              Positioned(
                left: (showFloatingBackButton && Navigator.of(context).canPop())
                    ? 64
                    : 12,
                right: 12,
                top: 12,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions!.map((action) {
                      return Material(
                        color: theme.colorScheme.surface.withAlpha(200),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: action,
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
