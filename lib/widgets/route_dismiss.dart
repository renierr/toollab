import 'package:flutter/material.dart';

/// Closes the route [context] belongs to, even when something newer sits on top.
///
/// `Navigator.pop()` removes the navigator's topmost route, not the caller's. A
/// dialog that dismisses itself the moment its work finishes is racing whatever
/// the completion pushed - a success notification is itself a route - so a plain
/// pop closes that instead and leaves the dialog up with nothing left to trigger
/// another rebuild.
void dismissOwnRoute(BuildContext context) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  // Popping keeps the exit animation, so it stays the path for the common case.
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}
