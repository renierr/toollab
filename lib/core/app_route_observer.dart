import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lets a page notice it became visible again after the route above it popped.
/// A tool page stays alive underneath a pushed settings screen, so anything that
/// screen changed is invisible until the page re-reads it.
///
/// Registered on the router in `app.dart`; subscribe from `didChangeDependencies`
/// with `ModalRoute.of(context)` and unsubscribe via `onDispose`.
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// True while a dialog, bottom sheet or popup menu sits on top of the
/// navigator. Overlays mounted *above* the Navigator (see
/// `ToolModel.overlayBuilder`) must hide while it is set — they otherwise paint
/// over the modal barrier and stay tappable through it.
final popupRouteActive = ValueNotifier<bool>(false);

/// Feeds [popupRouteActive]. Registered on the router in `app.dart`.
final popupRouteTracker = _PopupRouteTracker();

class _PopupRouteTracker extends NavigatorObserver {
  int _depth = 0;

  /// Synchronous counterpart to [popupRouteActive], updated before the other
  /// observers run so a `RouteAware.didPushNext` can tell a dialog opening on
  /// top of a page from a real navigation away from it.
  bool get popupOnTop => _depth > 0;

  void _apply() {
    final active = _depth > 0;
    if (popupRouteActive.value == active) return;
    // A push can land mid-frame; deferring keeps it out of the build phase.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => popupRouteActive.value = _depth > 0,
      );
      return;
    }
    popupRouteActive.value = active;
  }

  void _track(Route<dynamic>? route, int delta) {
    if (route is! PopupRoute) return;
    _depth = (_depth + delta).clamp(0, 1 << 20);
    _apply();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(oldRoute, -1);
    _track(newRoute, 1);
  }
}
