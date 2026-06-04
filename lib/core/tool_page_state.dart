import 'package:flutter/widgets.dart';

mixin DisposeCleanup<T extends StatefulWidget> on State<T> {
  final List<VoidCallback> _disposeHooks = [];

  @override
  void dispose() {
    for (final fn in _disposeHooks) {
      fn();
    }
    super.dispose();
  }

  void onDispose(VoidCallback fn) {
    _disposeHooks.add(fn);
  }
}
