import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tool_model.dart';

/// Wraps a tool's route page and runs [ToolModel.onClose] once the last open
/// route of that tool leaves the stack. Sub-pages, dialogs and sheets sit on
/// top of the route, so they never count as closing it.
class ToolRouteScope extends StatefulWidget {
  final ToolModel tool;
  final Widget child;

  const ToolRouteScope({super.key, required this.tool, required this.child});

  /// The same tool can be on the stack twice (a shortcut or a share on top).
  static final Map<String, int> _open = {};

  @visibleForTesting
  static int openCount(String toolId) => _open[toolId] ?? 0;

  @override
  State<ToolRouteScope> createState() => _ToolRouteScopeState();
}

class _ToolRouteScopeState extends State<ToolRouteScope> {
  /// A context above every route, still mounted when this one is disposed;
  /// tool state providers sit above the Navigator and are read through it.
  BuildContext? _appContext;

  @override
  void initState() {
    super.initState();
    final id = widget.tool.id;
    ToolRouteScope._open[id] = ToolRouteScope.openCount(id) + 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appContext = Navigator.maybeOf(context, rootNavigator: true)?.context;
  }

  @override
  void dispose() {
    final tool = widget.tool;
    final left = ToolRouteScope.openCount(tool.id) - 1;
    if (left > 0) {
      ToolRouteScope._open[tool.id] = left;
    } else {
      ToolRouteScope._open.remove(tool.id);
      final onClose = tool.onClose;
      final appContext = _appContext;
      if (onClose != null && appContext != null) {
        // After the tree is unlocked, since releasing notifies listeners.
        scheduleMicrotask(() {
          if (appContext.mounted && ToolRouteScope.openCount(tool.id) == 0) {
            onClose(appContext);
          }
        });
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
