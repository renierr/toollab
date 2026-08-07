import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Wraps a camera preview with pinch-to-zoom, quick zoom steps and a slider so
/// distant codes can be magnified optically instead of relying on resolution.
class CameraZoomOverlay extends StatefulWidget {
  final CameraController? controller;
  final Color accentColor;
  final Widget child;

  /// Tap position in relative (0..1) preview coordinates, for tap-to-focus.
  final ValueChanged<Offset>? onTapFocus;

  const CameraZoomOverlay({
    super.key,
    required this.controller,
    required this.accentColor,
    required this.child,
    this.onTapFocus,
  });

  @override
  State<CameraZoomOverlay> createState() => _CameraZoomOverlayState();
}

class _CameraZoomOverlayState extends State<CameraZoomOverlay> {
  double _min = 1.0;
  double _max = 1.0;
  double _zoom = 1.0;
  double _pinchBase = 1.0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  @override
  void didUpdateWidget(CameraZoomOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _ready = false;
      _loadLimits();
    }
  }

  Future<void> _loadLimits() async {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      if (!mounted) return;
      setState(() {
        _min = min;
        _max = max;
        _zoom = min;
        _ready = max > min;
      });
    } catch (e) {
      debugPrint('[CameraZoomOverlay] Zoom limits unavailable: $e');
    }
  }

  Future<void> _apply(double value) async {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = value.clamp(_min, _max);
    setState(() => _zoom = clamped);
    try {
      await controller.setZoomLevel(clamped);
    } catch (e) {
      debugPrint('[CameraZoomOverlay] setZoomLevel failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Cap the steps at what the sensor actually supports.
    final steps = [1.0, 2.0, 3.0, 5.0].where((s) => s <= _max).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onScaleStart: (_) => _pinchBase = _zoom,
          onScaleUpdate: (d) {
            if (!_ready || d.pointerCount < 2) return;
            _apply(_pinchBase * d.scale);
          },
          onTapUp: widget.onTapFocus == null
              ? null
              : (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final size = box.size;
                  widget.onTapFocus!(
                    Offset(
                      (details.localPosition.dx / size.width).clamp(0.0, 1.0),
                      (details.localPosition.dy / size.height).clamp(0.0, 1.0),
                    ),
                  );
                },
          child: widget.child,
        ),
        if (_ready)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ZoomBar(
              label: l10n.qrCameraZoom,
              accentColor: widget.accentColor,
              min: _min,
              max: _max,
              zoom: _zoom,
              steps: steps,
              onChanged: _apply,
            ),
          ),
      ],
    );
  }
}

class _ZoomBar extends StatelessWidget {
  final String label;
  final Color accentColor;
  final double min;
  final double max;
  final double zoom;
  final List<double> steps;
  final ValueChanged<double> onChanged;

  const _ZoomBar({
    required this.label,
    required this.accentColor,
    required this.min,
    required this.max,
    required this.zoom,
    required this.steps,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.zoom_in, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: zoom.clamp(min, max),
                    min: min,
                    max: max,
                    activeColor: accentColor,
                    label: '${zoom.toStringAsFixed(1)}x',
                    semanticFormatterCallback: (v) =>
                        '$label ${v.toStringAsFixed(1)}x',
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${zoom.toStringAsFixed(1)}x',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (steps.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  for (final step in steps)
                    _ZoomStepChip(
                      value: step,
                      selected: (zoom - step).abs() < 0.05,
                      accentColor: accentColor,
                      onTap: () => onChanged(step),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomStepChip extends StatelessWidget {
  final double value;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ZoomStepChip({
    required this.value,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.25)
              : Colors.transparent,
          border: Border.all(
            color: selected ? accentColor : Colors.white54,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${value.toStringAsFixed(0)}x',
          style: TextStyle(
            color: selected ? accentColor : Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
