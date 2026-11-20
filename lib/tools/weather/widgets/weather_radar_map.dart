import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../models/radar_viewport.dart';
import '../weather_radar_state.dart';
import '../weather_settings.dart';

class RadarPin {
  const RadarPin({
    required this.lat,
    required this.lon,
    required this.label,
    required this.selected,
  });

  final double lat;
  final double lon;
  final String label;
  final bool selected;
}

class WeatherRadarMap extends StatefulWidget {
  const WeatherRadarMap({
    super.key,
    required this.radar,
    required this.pins,
    this.interactive = true,
  });

  final WeatherRadarState radar;
  final List<RadarPin> pins;
  final bool interactive;

  @override
  State<WeatherRadarMap> createState() => _WeatherRadarMapState();
}

class _WeatherRadarMapState extends State<WeatherRadarMap> {
  Offset? _lastFocal;
  double _lastScale = 1;

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocal = d.localFocalPoint;
    _lastScale = 1;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final last = _lastFocal;
    if (last != null) widget.radar.panBy(d.localFocalPoint - last);
    if (d.scale != _lastScale) {
      widget.radar.zoomAt(d.scale / _lastScale, d.localFocalPoint);
      _lastScale = d.scale;
    }
    _lastFocal = d.localFocalPoint;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.radar.zoomAt(
        event.scrollDelta.dy < 0 ? 1.25 : 0.8,
        event.localPosition,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.radar.resize(size);
        });
        final map = CustomPaint(
          size: size,
          painter: _RadarPainter(
            radar: widget.radar,
            pins: widget.pins,
            pinColor: theme.colorScheme.primary,
            labelStyle: theme.textTheme.labelMedium!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        if (!widget.interactive) return ClipRect(child: map);
        return ClipRect(
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onDoubleTapDown: (d) => widget.radar.zoomAt(2, d.localPosition),
              onDoubleTap: () {},
              child: map,
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.radar,
    required this.pins,
    required this.pinColor,
    required this.labelStyle,
  }) : super(repaint: Listenable.merge([radar, radar.viewport]));

  final WeatherRadarState radar;
  final List<RadarPin> pins;
  final Color pinColor;
  final TextStyle labelStyle;

  static const Color _light = Color(0xFFE8EDF2);
  static const Color _dark = Color(0xFF0E1420);

  @override
  void paint(Canvas canvas, Size size) {
    final vp = radar.viewport.value;
    final mode = radar.baseMap;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = mode == RadarBaseMap.light ? _light : _dark,
    );
    if (vp == null) return;
    final image = Paint()..filterQuality = FilterQuality.medium;

    void draw(RadarImage? img, {double opacity = 1}) {
      if (img == null) return;
      final src = Rect.fromLTWH(
        0,
        0,
        img.image.width.toDouble(),
        img.image.height.toDouble(),
      );
      image.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.drawImageRect(img.image, src, vp.rectToScreen(img.bbox), image);
    }

    draw(radar.base);
    if (mode == RadarBaseMap.light) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: .62),
      );
    } else if (mode == RadarBaseMap.dark) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: .45),
      );
    }
    draw(radar.overlay, opacity: mode == RadarBaseMap.light ? .9 : .7);
    draw(radar.warnings, opacity: .45);
    draw(radar.frameAt(radar.index), opacity: .88);
    draw(radar.lightning);
    _pins(canvas, vp, mode == RadarBaseMap.light);
  }

  void _pins(Canvas canvas, RadarViewport vp, bool light) {
    final ordered = [...pins]
      ..sort((a, b) => a.selected ? 1 : (b.selected ? -1 : 0));
    for (final pin in ordered) {
      final p = vp.toScreenLatLon(pin.lat, pin.lon);
      final r = pin.selected ? 7.0 : 5.0;
      canvas.drawCircle(
        p,
        r + 6,
        Paint()..color = pinColor.withValues(alpha: .22),
      );
      canvas.drawCircle(p, r + 2, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = pin.selected ? pinColor : pinColor.withValues(alpha: .7),
      );
      if (!pin.selected && vp.resolution > 2500) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: pin.label,
          style: labelStyle.copyWith(
            color: light ? Colors.black87 : Colors.white,
            shadows: [
              Shadow(color: light ? Colors.white : Colors.black, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 160);
      tp.paint(canvas, p + Offset(r + 6, -tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.pins != pins || old.pinColor != pinColor || old.radar != radar;
}
