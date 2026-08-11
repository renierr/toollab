import 'package:flutter/widgets.dart';

/// Lets a page notice it became visible again after the route above it popped.
/// A tool page stays alive underneath a pushed settings screen, so anything that
/// screen changed is invisible until the page re-reads it.
///
/// Registered on the router in `app.dart`; subscribe from `didChangeDependencies`
/// with `ModalRoute.of(context)` and unsubscribe via `onDispose`.
final appRouteObserver = RouteObserver<ModalRoute<void>>();
