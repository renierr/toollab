import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Remote-control navigation for devices without a touch screen.
///
/// Flutter gives the arrow keys to the focused text field first, so up and down
/// move the caret and focus never leaves the field - with a D-pad that means
/// the user is stuck. While enabled this scope takes both keys back, switches
/// [MediaQueryData.navigationMode] to [NavigationMode.directional] so sliders
/// only bind left/right, and falls back to scrolling the active vertical
/// [Scrollable] when no focusable widget lies in the requested direction.
class TvNavigationScope extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const TvNavigationScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  State<TvNavigationScope> createState() => _TvNavigationScopeState();
}

class _TvNavigationScopeState extends State<TvNavigationScope> {
  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveFocusIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveFocusIntent(
      TraversalDirection.down,
    ),
  };

  final _MoveFocusAction _moveFocus = _MoveFocusAction();

  @override
  Widget build(BuildContext context) {
    // The tree shape stays the same in both modes so toggling TV mode never
    // reparents the Navigator and drops page state.
    return MediaQuery(
      data: MediaQueryData(
        size: MediaQuery.sizeOf(context),
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        textScaler: MediaQuery.textScalerOf(context),
        platformBrightness: MediaQuery.platformBrightnessOf(context),
        padding: MediaQuery.paddingOf(context),
        viewInsets: MediaQuery.viewInsetsOf(context),
        systemGestureInsets: MediaQuery.systemGestureInsetsOf(context),
        viewPadding: MediaQuery.viewPaddingOf(context),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        accessibleNavigation: MediaQuery.accessibleNavigationOf(context),
        invertColors: MediaQuery.invertColorsOf(context),
        highContrast: MediaQuery.highContrastOf(context),
        onOffSwitchLabels: MediaQuery.onOffSwitchLabelsOf(context),
        disableAnimations: MediaQuery.disableAnimationsOf(context),
        boldText: MediaQuery.boldTextOf(context),
        navigationMode: widget.enabled
            ? NavigationMode.directional
            : MediaQuery.navigationModeOf(context),
        gestureSettings: MediaQuery.gestureSettingsOf(context),
        displayFeatures: MediaQuery.displayFeaturesOf(context),
        supportsShowingSystemContextMenu:
            MediaQuery.supportsShowingSystemContextMenu(context),
      ),
      child: Shortcuts(
        shortcuts: widget.enabled
            ? _shortcuts
            : const <ShortcutActivator, Intent>{},
        child: Actions(
          actions: widget.enabled
              ? <Type, Action<Intent>>{_MoveFocusIntent: _moveFocus}
              : const <Type, Action<Intent>>{},
          child: widget.child,
        ),
      ),
    );
  }
}

class _MoveFocusIntent extends Intent {
  final TraversalDirection direction;

  const _MoveFocusIntent(this.direction);
}

class _MoveFocusAction extends Action<_MoveFocusIntent> {
  static const double _scrollStep = 200.0;

  @override
  void invoke(_MoveFocusIntent intent) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    if (primary.focusInDirection(intent.direction)) return;
    if (_scrollVertical(primary, intent.direction)) return;
    // Nothing lies that way and nothing can scroll. A text field falls back to
    // traversal order so the remote can always get out.
    if (!_isEditingText(primary)) return;
    if (intent.direction == TraversalDirection.up) {
      primary.previousFocus();
    } else {
      primary.nextFocus();
    }
  }

  static bool _isEditingText(FocusNode node) {
    final context = node.context;
    return context != null &&
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  static bool _scrollVertical(FocusNode primary, TraversalDirection direction) {
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      return false;
    }
    final scrollable = _findVerticalScrollable(primary);
    if (scrollable == null) return false;
    final position = scrollable.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return false;
    }
    final delta = direction == TraversalDirection.down
        ? _scrollStep
        : -_scrollStep;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return false;
    position.jumpTo(target);
    return true;
  }

  static ScrollableState? _findVerticalScrollable(FocusNode primary) {
    final primaryContext = primary.context;
    if (primaryContext != null) {
      final ancestor = Scrollable.maybeOf(primaryContext, axis: Axis.vertical);
      if (_canScroll(ancestor)) return ancestor;
    }
    final scopeContext =
        primary.enclosingScope?.context ??
        FocusManager.instance.rootScope.context;
    if (scopeContext == null) return null;
    ScrollableState? match;
    void visit(Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState && _canScroll(state)) {
          match = state;
        }
      }
      element.visitChildren(visit);
    }

    scopeContext.visitChildElements(visit);
    return match;
  }

  static bool _canScroll(ScrollableState? state) {
    if (state == null || !state.mounted) return false;
    if (state.axisDirection != AxisDirection.down &&
        state.axisDirection != AxisDirection.up) {
      return false;
    }
    final position = state.position;
    return position.hasContentDimensions && position.maxScrollExtent > 0;
  }
}
