import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/theme/theme.dart';

class ZoomableArea extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    double scale,
    ScrollPhysics? physics,
  )
  builder;
  final Color accentColor;
  final double initialScale;

  const ZoomableArea({
    super.key,
    required this.builder,
    this.accentColor = AppTheme.accentBlue,
    this.initialScale = 1.0,
  });

  @override
  State<ZoomableArea> createState() => _ZoomableAreaState();
}

class _ZoomableAreaState extends State<ZoomableArea> {
  late double _scaleFactor;
  double _baseScale = 1.0;
  bool _isScaling = false;
  bool _ctrlPressed = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scaleFactor = widget.initialScale;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _hideTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isPressed =
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlRight,
        );
    if (isPressed != _ctrlPressed) {
      setState(() {
        _ctrlPressed = isPressed;
      });
    }
    return false; // Do not consume key events
  }

  void _onScaleStart(ScaleStartDetails details) {
    _hideTimer?.cancel();
    setState(() {
      _baseScale = _scaleFactor;
      _isScaling = true;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scaleFactor = (_baseScale * details.scale).clamp(0.8, 3.0);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _hideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isScaling = false;
        });
      }
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final isControlPressed =
          HardwareKeyboard.instance.isLogicalKeyPressed(
            LogicalKeyboardKey.controlLeft,
          ) ||
          HardwareKeyboard.instance.isLogicalKeyPressed(
            LogicalKeyboardKey.controlRight,
          );

      if (isControlPressed != _ctrlPressed) {
        setState(() {
          _ctrlPressed = isControlPressed;
        });
      }

      if (isControlPressed) {
        GestureBinding.instance.pointerSignalResolver.register(event, (
          resolvedEvent,
        ) {
          if (resolvedEvent is PointerScrollEvent) {
            final delta = resolvedEvent.scrollDelta.dy;
            setState(() {
              if (delta < 0) {
                _scaleFactor = (_scaleFactor + 0.1).clamp(0.8, 3.0);
              } else if (delta > 0) {
                _scaleFactor = (_scaleFactor - 0.1).clamp(0.8, 3.0);
              }
              _isScaling = true;
            });

            _hideTimer?.cancel();
            _hideTimer = Timer(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _isScaling = false;
                });
              }
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ScrollPhysics? physics = _ctrlPressed
        ? const NeverScrollableScrollPhysics()
        : null;

    return Listener(
      onPointerSignal: _handlePointerSignal,
      behavior: HitTestBehavior.translucent,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.builder(context, _scaleFactor, physics),
            if (_isScaling)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Zoom: ${(_scaleFactor * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
