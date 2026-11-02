import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

/// Keyboard and D-pad remote navigation across desktop and Android TV.
///
/// Sets [MediaQueryData.navigationMode] to [NavigationMode.directional] so
/// horizontal [Slider] widgets only consume left/right arrow keys instead of
/// trapping up/down, scrolls the active vertical [Scrollable] when no nearby
/// focus target lies in the requested direction, and paints a high-contrast
/// focus ring around any focused control during keyboard/D-pad navigation.
///
/// When [enabled] (TV mode) is true, up/down arrow keys also move focus out of
/// an active [TextField] so a D-pad remote is never trapped inside text input.
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
    SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveFocusIntent(
      TraversalDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): _MoveFocusIntent(
      TraversalDirection.right,
    ),
    SingleActivator(LogicalKeyboardKey.pageUp): _MoveFocusIntent(
      TraversalDirection.up,
      page: true,
    ),
    SingleActivator(LogicalKeyboardKey.pageDown): _MoveFocusIntent(
      TraversalDirection.down,
      page: true,
    ),
    SingleActivator(LogicalKeyboardKey.mediaPlayPause): _MediaActionIntent(
      'play_pause',
    ),
    SingleActivator(LogicalKeyboardKey.mediaPlay): _MediaActionIntent('play'),
    SingleActivator(LogicalKeyboardKey.mediaPause): _MediaActionIntent('pause'),
    SingleActivator(LogicalKeyboardKey.mediaStop): _MediaActionIntent('stop'),
    SingleActivator(LogicalKeyboardKey.mediaTrackNext): _MediaActionIntent(
      'next',
    ),
    SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): _MediaActionIntent(
      'previous',
    ),
  };

  final GlobalKey _paintKey = GlobalKey();
  final FocusNode _fallbackFocusNode = FocusNode(
    debugLabel: 'TvNavigationScopeFallback',
    skipTraversal: true,
  );
  final ValueNotifier<int> _focusRepaint = ValueNotifier<int>(0);
  bool _keyboardFocusActive = false;
  late final _MoveFocusAction _moveFocus = _MoveFocusAction(
    isTvMode: () => widget.enabled,
    fallbackFocusNode: _fallbackFocusNode,
    scopeContext: () => context,
    onMovedOrScrolled: () {
      _keyboardFocusActive = true;
      _triggerFocusRepaint();
    },
  );
  final _MediaAction _mediaAction = _MediaAction();

  @override
  void initState() {
    super.initState();
    _keyboardFocusActive = widget.enabled;
    FocusManager.instance.addListener(_triggerFocusRepaint);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void didUpdateWidget(covariant TvNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _keyboardFocusActive = widget.enabled;
      _triggerFocusRepaint();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    FocusManager.instance.removeListener(_triggerFocusRepaint);
    _fallbackFocusNode.dispose();
    _focusRepaint.dispose();
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent && _isNavigationKey(event.logicalKey)) {
      if (!_keyboardFocusActive) {
        _keyboardFocusActive = true;
        _triggerFocusRepaint();
      }
    }
    return false;
  }

  static bool _isNavigationKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.tab ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.pageUp ||
      key == LogicalKeyboardKey.pageDown ||
      key == LogicalKeyboardKey.select;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled && _keyboardFocusActive) {
      _keyboardFocusActive = false;
      _triggerFocusRepaint();
    }
  }

  void _triggerFocusRepaint() {
    if (!mounted) return;
    _focusRepaint.value++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusRepaint.value++;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _focusRepaint.value++;
    return false;
  }

  bool _onScrollMetricsNotification(ScrollMetricsNotification notification) {
    _focusRepaint.value++;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Overriding one field needs the whole data; rebuilding it field by field
    // silently drops accessibility settings Flutter adds later.
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(navigationMode: NavigationMode.directional),
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveFocusIntent: _moveFocus,
            _MediaActionIntent: _mediaAction,
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _onScrollMetricsNotification,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                child: Focus(
                  focusNode: _fallbackFocusNode,
                  autofocus: true,
                  child: CustomPaint(
                    key: _paintKey,
                    foregroundPainter: _GlobalFocusRingPainter(
                      paintKey: _paintKey,
                      fallbackFocusNode: _fallbackFocusNode,
                      isKeyboardFocusActive: () =>
                          widget.enabled || _keyboardFocusActive,
                      repaint: _focusRepaint,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaActionIntent extends Intent {
  final String action;

  const _MediaActionIntent(this.action);
}

class _MediaAction extends Action<_MediaActionIntent> {
  @override
  bool isEnabled(_MediaActionIntent intent) =>
      ForegroundRuntimeService.isActive;

  @override
  void invoke(_MediaActionIntent intent) {
    ForegroundRuntimeService.dispatchAction(intent.action);
  }
}

class _MoveFocusIntent extends Intent {
  final TraversalDirection direction;
  final bool page;

  const _MoveFocusIntent(this.direction, {this.page = false});
}

class _MoveFocusAction extends Action<_MoveFocusIntent> {
  static const double _scrollStep = 200.0;
  static const double _viewportMargin = 48.0;

  final bool Function() isTvMode;
  final FocusNode fallbackFocusNode;
  final BuildContext Function() scopeContext;
  final VoidCallback onMovedOrScrolled;

  _MoveFocusAction({
    required this.isTvMode,
    required this.fallbackFocusNode,
    required this.scopeContext,
    required this.onMovedOrScrolled,
  });

  @override
  bool isEnabled(_MoveFocusIntent intent) {
    final primary = FocusManager.instance.primaryFocus;
    if (intent.direction == TraversalDirection.left ||
        intent.direction == TraversalDirection.right) {
      if (primary == null) return true;
      return !_isEditingText(primary) && !_isHorizontalSlider(primary);
    }
    if (isTvMode()) return true;
    return primary == null || !_isEditingText(primary);
  }

  @override
  void invoke(_MoveFocusIntent intent) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    final direction = intent.direction;

    if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      if (_focusInDirectionSkippingContainers(
        primary,
        direction,
        fallbackFocusNode,
      )) {
        _ensureFocusedVisible();
        onMovedOrScrolled();
        return;
      }
      if (_focusOutOfBandTarget(primary, direction, fallbackFocusNode)) {
        _ensureFocusedVisible();
        onMovedOrScrolled();
      }
      return;
    }

    final scrollable = _findVerticalScrollable(primary, scopeContext());

    if (intent.page) {
      if (_scrollVertical(scrollable, direction, page: true)) {
        onMovedOrScrolled();
      }
      return;
    }

    if (_isContainerOrRegionFocus(primary, fallbackFocusNode)) {
      final scope = primary is FocusScopeNode
          ? primary
          : (primary.nearestScope ?? FocusManager.instance.rootScope);
      if (scrollable != null &&
          _canScrollInDirection(scrollable, direction) &&
          !_hasVisibleFocusableInScrollable(
            scope,
            scrollable,
            fallbackFocusNode,
          )) {
        _scrollVertical(scrollable, direction);
        onMovedOrScrolled();
        return;
      }
      if (_focusInDirectionSkippingContainers(
        primary,
        direction,
        fallbackFocusNode,
      )) {
        _ensureFocusedVisible();
        onMovedOrScrolled();
        return;
      }
      if (_scrollVertical(scrollable, direction)) {
        onMovedOrScrolled();
        return;
      }
      if (_focusOutOfBandTarget(primary, direction, fallbackFocusNode)) {
        _ensureFocusedVisible();
        onMovedOrScrolled();
      }
      return;
    }

    if (scrollable != null &&
        _canScrollInDirection(scrollable, direction) &&
        !_hasNearbyFocusTarget(
          primary,
          scrollable,
          direction,
          fallbackFocusNode,
        )) {
      if (_scrollVertical(scrollable, direction)) {
        onMovedOrScrolled();
        return;
      }
    }

    if (_focusInDirectionSkippingContainers(
      primary,
      direction,
      fallbackFocusNode,
    )) {
      _ensureFocusedVisible();
      onMovedOrScrolled();
      return;
    }

    if (_scrollVertical(scrollable, direction)) {
      onMovedOrScrolled();
      return;
    }

    if (_focusOutOfBandTarget(primary, direction, fallbackFocusNode)) {
      _ensureFocusedVisible();
      onMovedOrScrolled();
      return;
    }

    if (!_isEditingText(primary)) return;
    if (direction == TraversalDirection.up) {
      primary.previousFocus();
    } else {
      primary.nextFocus();
    }
    onMovedOrScrolled();
  }

  static bool _isEditingText(FocusNode node) {
    final context = node.context;
    return context != null &&
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  static bool _isHorizontalSlider(FocusNode node) {
    final context = node.context;
    return context != null &&
        context.findAncestorWidgetOfExactType<Slider>() != null;
  }

  static void _ensureFocusedVisible() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null || !focusedContext.mounted) return;
    if (Scrollable.maybeOf(focusedContext) == null) return;
    Scrollable.ensureVisible(
      focusedContext,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      focusedContext,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  static bool _scrollVertical(
    ScrollableState? scrollable,
    TraversalDirection direction, {
    bool page = false,
  }) {
    if (scrollable == null) return false;
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      return false;
    }
    final position = scrollable.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return false;
    }
    final step = page
        ? (position.viewportDimension * 0.85).clamp(_scrollStep, 1200.0)
        : _scrollStep;
    final delta = direction == TraversalDirection.down ? step : -step;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return false;
    position.jumpTo(target);
    return true;
  }

  static bool _canScrollInDirection(
    ScrollableState scrollable,
    TraversalDirection direction,
  ) {
    if (!_canScroll(scrollable)) return false;
    final position = scrollable.position;
    return switch (direction) {
      TraversalDirection.down =>
        position.pixels < position.maxScrollExtent - 0.5,
      TraversalDirection.up => position.pixels > position.minScrollExtent + 0.5,
      _ => false,
    };
  }

  static bool _focusInDirectionSkippingContainers(
    FocusNode primary,
    TraversalDirection direction,
    FocusNode fallbackFocusNode,
  ) {
    if (!primary.focusInDirection(direction)) return false;
    final next = FocusManager.instance.primaryFocus;
    if (next != null && !_isContainerOrRegionFocus(next, fallbackFocusNode)) {
      return true;
    }
    if (_focusOutOfBandTarget(primary, direction, fallbackFocusNode)) {
      return true;
    }
    if (!identical(primary, next) && primary.canRequestFocus) {
      primary.requestFocus();
    }
    return false;
  }

  static bool _hasVisibleFocusableInScrollable(
    FocusScopeNode scope,
    ScrollableState scrollable,
    FocusNode fallbackFocusNode,
  ) {
    final scrollContext = scrollable.context;
    final scrollBox = scrollContext.findRenderObject();
    if (scrollBox is! RenderBox || !scrollBox.attached || !scrollBox.hasSize) {
      return false;
    }
    final viewportRect = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
    for (final node in scope.traversalDescendants) {
      if (!node.canRequestFocus || node.context == null) continue;
      if (_isContainerOrRegionFocus(node, fallbackFocusNode)) continue;
      if (!_isDescendantOf(node.context!, scrollContext)) continue;
      final rect = _nodeGlobalRect(node);
      if (rect != null && rect.overlaps(viewportRect)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasNearbyFocusTarget(
    FocusNode primary,
    ScrollableState scrollable,
    TraversalDirection direction,
    FocusNode fallbackFocusNode,
  ) {
    final primaryContext = primary.context;
    final scrollContext = scrollable.context;
    if (primaryContext == null || !primaryContext.mounted) return true;
    final primaryRect = _nodeGlobalRect(primary);
    final scrollBox = scrollContext.findRenderObject();
    if (primaryRect == null ||
        scrollBox is! RenderBox ||
        !scrollBox.attached ||
        !scrollBox.hasSize) {
      return true;
    }
    final viewportRect = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
    final primaryInScrollable = _isDescendantOf(primaryContext, scrollContext);
    final scope = primary.nearestScope ?? FocusManager.instance.rootScope;

    for (final node in scope.traversalDescendants) {
      if (node == primary || !node.canRequestFocus) continue;
      if (_isContainerOrRegionFocus(node, fallbackFocusNode)) continue;
      final nodeContext = node.context;
      if (nodeContext == null || !nodeContext.mounted) continue;
      if (_isDescendantOf(nodeContext, primaryContext) ||
          _isDescendantOf(primaryContext, nodeContext)) {
        continue;
      }
      final rect = _nodeGlobalRect(node);
      if (rect == null || rect.isEmpty) continue;

      if (direction == TraversalDirection.down) {
        if (rect.center.dy <= primaryRect.center.dy + 2.0) continue;
        if (rect.top < primaryRect.center.dy - 4.0) continue;
        if (rect.top <= viewportRect.bottom + _viewportMargin) {
          return true;
        }
      } else if (direction == TraversalDirection.up) {
        if (rect.center.dy >= primaryRect.center.dy - 2.0) continue;
        if (rect.bottom > primaryRect.center.dy + 4.0) continue;
        if (primaryInScrollable &&
            !_isDescendantOf(nodeContext, scrollContext)) {
          continue;
        }
        if (rect.bottom >= viewportRect.top - _viewportMargin) {
          return true;
        }
      }
    }
    return false;
  }

  static List<FocusNode> _collectFocusableLeaves(
    FocusNode primary,
    FocusNode fallbackFocusNode,
  ) {
    final result = <FocusNode>[];
    final visited = <FocusNode>{};

    void visitScope(FocusScopeNode scope) {
      for (final node in scope.traversalDescendants) {
        if (!visited.add(node)) continue;
        if (node is FocusScopeNode) {
          visitScope(node);
          continue;
        }
        if (node == primary ||
            identical(node, fallbackFocusNode) ||
            !node.canRequestFocus) {
          continue;
        }
        final ctx = node.context;
        if (ctx == null || !ctx.mounted) continue;
        final route = ModalRoute.of(ctx);
        if (route != null && !route.isCurrent) continue;
        if (_isContainerOrRegionFocus(node, fallbackFocusNode)) continue;
        result.add(node);
      }
    }

    visitScope(FocusManager.instance.rootScope);
    return result;
  }

  static bool _focusOutOfBandTarget(
    FocusNode primary,
    TraversalDirection direction,
    FocusNode fallbackFocusNode,
  ) {
    final primaryContext = primary.context;
    final primaryRect = _nodeGlobalRect(primary);
    if (primaryContext == null || primaryRect == null) return false;
    final candidates = _collectFocusableLeaves(primary, fallbackFocusNode);
    if (candidates.isEmpty) return false;

    FocusNode? best;
    double bestPrimaryDist = double.infinity;
    double bestCrossDist = double.infinity;

    for (final node in candidates) {
      final nodeContext = node.context!;
      if (_isDescendantOf(nodeContext, primaryContext) ||
          _isDescendantOf(primaryContext, nodeContext)) {
        continue;
      }
      final rect = _nodeGlobalRect(node);
      if (rect == null || rect.isEmpty) continue;

      final double primaryDist;
      final double crossDist;
      switch (direction) {
        case TraversalDirection.down:
          if (rect.top < primaryRect.bottom - 2.0) continue;
          primaryDist = rect.top - primaryRect.bottom;
          crossDist = (rect.center.dx - primaryRect.center.dx).abs();
        case TraversalDirection.up:
          if (rect.bottom > primaryRect.top + 2.0) continue;
          primaryDist = primaryRect.top - rect.bottom;
          crossDist = (rect.center.dx - primaryRect.center.dx).abs();
        case TraversalDirection.right:
          if (rect.left < primaryRect.right - 2.0) continue;
          primaryDist = rect.left - primaryRect.right;
          crossDist = (rect.center.dy - primaryRect.center.dy).abs();
        case TraversalDirection.left:
          if (rect.right > primaryRect.left + 2.0) continue;
          primaryDist = primaryRect.left - rect.right;
          crossDist = (rect.center.dy - primaryRect.center.dy).abs();
      }
      if (primaryDist < bestPrimaryDist - 1.0 ||
          ((primaryDist - bestPrimaryDist).abs() <= 1.0 &&
              crossDist < bestCrossDist)) {
        best = node;
        bestPrimaryDist = primaryDist;
        bestCrossDist = crossDist;
      }
    }

    // Floating overlays (e.g. ChiptuneMiniPlayer) sit above Navigator in their
    // own scope and can overlap the bottom/left edge of the active route.
    if (best == null) {
      final primaryIsOverlay = ModalRoute.of(primaryContext) == null;
      double bestDist = double.infinity;
      for (final node in candidates) {
        final nodeContext = node.context!;
        final nodeIsOverlay = ModalRoute.of(nodeContext) == null;
        if (primaryIsOverlay == nodeIsOverlay) continue;
        if (!primaryIsOverlay &&
            direction != TraversalDirection.down &&
            direction != TraversalDirection.left) {
          continue;
        }
        final rect = _nodeGlobalRect(node);
        if (rect == null || rect.isEmpty) continue;
        final dist = (rect.center - primaryRect.center).distance;
        if (dist < bestDist) {
          bestDist = dist;
          best = node;
        }
      }
    }

    if (best == null) return false;
    best.requestFocus();
    return true;
  }

  static Rect? _nodeGlobalRect(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static bool _isDescendantOf(BuildContext child, BuildContext ancestor) {
    if (identical(child, ancestor)) return false;
    bool found = false;
    child.visitAncestorElements((element) {
      if (identical(element, ancestor)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  static ScrollableState? _findVerticalScrollable(
    FocusNode primary,
    BuildContext fallbackContext,
  ) {
    BuildContext? current = primary.context;
    while (current != null && current.mounted) {
      final ancestor = Scrollable.maybeOf(current, axis: Axis.vertical);
      if (ancestor == null) break;
      if (_canScroll(ancestor)) return ancestor;
      Element? parent;
      ancestor.context.visitAncestorElements((element) {
        parent = element;
        return false;
      });
      current = parent;
    }

    final primaryContext = primary.context;
    if (primaryContext != null &&
        primaryContext.mounted &&
        !identical(primary, FocusManager.instance.rootScope) &&
        primary is! FocusScopeNode &&
        ModalRoute.of(primaryContext) == null) {
      // Focused widget is inside an app-wide overlay above Navigator; arrow
      // keys should traverse the overlay rather than scrolling the route below.
      return null;
    }

    final searchRoot =
        primary.nearestScope?.context ??
        primary.enclosingScope?.context ??
        (fallbackContext.mounted ? fallbackContext : null);
    if (searchRoot == null || !searchRoot.mounted) return null;

    ScrollableState? match;
    void visit(Element element) {
      if (match != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is Visibility && !widget.visible) return;
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState && _canScroll(state)) {
          final route = ModalRoute.of(state.context);
          if (route == null || route.isCurrent) {
            match = state;
            return;
          }
        }
      }
      element.visitChildren(visit);
    }

    searchRoot.visitChildElements(visit);
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

class _GlobalFocusRingPainter extends CustomPainter {
  final GlobalKey paintKey;
  final FocusNode fallbackFocusNode;
  final bool Function() isKeyboardFocusActive;

  _GlobalFocusRingPainter({
    required this.paintKey,
    required this.fallbackFocusNode,
    required this.isKeyboardFocusActive,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isKeyboardFocusActive() ||
        FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null ||
        _isContainerOrRegionFocus(primary, fallbackFocusNode)) {
      return;
    }
    final targetContext = primary.context;
    if (targetContext == null || !targetContext.mounted) return;
    if (targetContext.findAncestorWidgetOfExactType<FocusOutline>() != null) {
      return;
    }

    final rootBox = paintKey.currentContext?.findRenderObject();
    final targetBox = _resolveTargetBox(targetContext);
    if (rootBox is! RenderBox || !rootBox.attached) return;
    if (targetBox == null || !targetBox.attached || !targetBox.hasSize) return;

    final targetSize = targetBox.size;
    final isEditableText =
        targetContext.findAncestorStateOfType<EditableTextState>() != null;
    if (targetSize.isEmpty ||
        targetSize.width <= 4 ||
        targetSize.height <= 4 ||
        (!isEditableText &&
            (targetSize.height > 200 ||
                (targetSize.width >= size.width * 0.5 &&
                    targetSize.height >= size.height * 0.35)))) {
      return;
    }

    final rect = MatrixUtils.transformRect(
      targetBox.getTransformTo(rootBox),
      Offset.zero & targetSize,
    );
    if (rect.isEmpty || !rect.overlaps(Offset.zero & size)) return;

    canvas.save();
    BuildContext? scrollSearch = targetContext;
    while (scrollSearch != null && scrollSearch.mounted) {
      final scrollable = Scrollable.maybeOf(scrollSearch);
      if (scrollable == null || !scrollable.mounted) break;
      final scrollBox = scrollable.context.findRenderObject();
      if (scrollBox is RenderBox && scrollBox.attached && scrollBox.hasSize) {
        final scrollRect = MatrixUtils.transformRect(
          scrollBox.getTransformTo(rootBox),
          Offset.zero & scrollBox.size,
        );
        canvas.clipRect(scrollRect.inflate(4));
      }
      Element? parent;
      scrollable.context.visitAncestorElements((element) {
        parent = element;
        return false;
      });
      scrollSearch = parent;
    }

    final isRoundIconButton =
        targetContext.findAncestorWidgetOfExactType<IconButton>() != null &&
        (rect.width - rect.height).abs() < 6;
    final radius = isRoundIconButton
        ? Radius.circular(rect.shortestSide / 2 + 2)
        : const Radius.circular(10);
    final rrect = RRect.fromRectAndRadius(rect.inflate(1.5), radius);

    final glowPaint = Paint()
      ..color = AppTheme.accentBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final borderPaint = Paint()
      ..color = AppTheme.accentBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, borderPaint);
    canvas.restore();
  }

  static RenderBox? _resolveTargetBox(BuildContext context) {
    if (context.findAncestorStateOfType<EditableTextState>() != null) {
      RenderBox? decoratorBox;
      context.visitAncestorElements((element) {
        if (element.widget is InputDecorator) {
          final renderObject = element.findRenderObject();
          if (renderObject is RenderBox) decoratorBox = renderObject;
          return false;
        }
        return true;
      });
      if (decoratorBox != null) return decoratorBox;
    }
    final renderObject = context.findRenderObject();
    return renderObject is RenderBox ? renderObject : null;
  }

  @override
  bool shouldRepaint(covariant _GlobalFocusRingPainter oldDelegate) =>
      oldDelegate.paintKey != paintKey;
}

bool _isContainerOrRegionFocus(FocusNode node, FocusNode fallbackFocusNode) {
  if (node is FocusScopeNode ||
      identical(node, fallbackFocusNode) ||
      node.skipTraversal) {
    return true;
  }
  final context = node.context;
  if (context == null || !context.mounted) return true;
  if (_isSelectableRegionFocus(context)) return true;
  if (node.traversalDescendants.any((d) => d.canRequestFocus)) return true;
  if (context.findAncestorStateOfType<EditableTextState>() == null &&
      _containsScrollable(context)) {
    return true;
  }
  return false;
}

bool _isSelectableRegionFocus(BuildContext context) {
  bool isSelectable = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is SelectableRegion || widget is SelectionArea) {
      isSelectable = true;
      return false;
    }
    if (widget is FocusableActionDetector && !widget.includeFocusSemantics) {
      isSelectable = true;
      return false;
    }
    if (widget is Focus) {
      return false;
    }
    return true;
  });
  return isSelectable;
}

bool _containsScrollable(BuildContext context) {
  bool found = false;
  void visit(Element element) {
    if (found) return;
    if (element is StatefulElement && element.state is ScrollableState) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return found;
}
