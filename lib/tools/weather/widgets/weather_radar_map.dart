import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../api/radar_cities.dart';
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
    this.focusAnchor = .5,
  });

  final WeatherRadarState radar;
  final List<RadarPin> pins;
  final bool interactive;

  /// Vertical share of the map the place sits at; less than half keeps it
  /// clear of controls along the bottom.
  final double focusAnchor;

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
          if (mounted) {
            widget.radar.resize(size, focusAnchor: widget.focusAnchor);
          }
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
    final image = Paint()..filterQuality = FilterQuality.high;

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
    final placed = <Rect>[
      for (final pin in pins)
        Rect.fromCircle(
          center: vp.toScreenLatLon(pin.lat, pin.lon),
          radius: 14,
        ),
    ];
    _cities(canvas, size, vp, mode == RadarBaseMap.light, placed);
    _pins(canvas, vp, mode == RadarBaseMap.light);
  }

  /// Subtle place names for orientation; bigger cities first, and labels
  /// that would collide with a pin or another label are skipped.
  void _cities(
    Canvas canvas,
    Size size,
    RadarViewport vp,
    bool light,
    List<Rect> placed,
  ) {
    final maxTier = vp.resolution > 2500 ? 1 : (vp.resolution > 1100 ? 2 : 3);
    final ink = light ? const Color(0xFF3C4450) : const Color(0xFFE4E8EE);
    final halo = light
        ? Colors.white.withValues(alpha: .8)
        : Colors.black.withValues(alpha: .7);
    final dot = Paint()..color = ink.withValues(alpha: .55);
    for (final city in radarCities) {
      if (city.tier > maxTier) continue;
      final p = vp.toScreenLatLon(city.lat, city.lon);
      if (p.dx < -40 ||
          p.dy < -20 ||
          p.dx > size.width + 40 ||
          p.dy > size.height + 20) {
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: city.name,
          style: labelStyle.copyWith(
            fontSize: city.tier == 1 ? 12 : 11,
            fontWeight: city.tier == 1 ? FontWeight.w600 : FontWeight.w500,
            color: ink.withValues(alpha: city.tier == 1 ? .85 : .7),
            shadows: [Shadow(color: halo, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rect = Rect.fromLTWH(
        p.dx + 5,
        p.dy - tp.height / 2,
        tp.width,
        tp.height,
      ).inflate(3);
      final dotRect = Rect.fromCircle(center: p, radius: 3);
      if (placed.any((r) => r.overlaps(rect) || r.overlaps(dotRect))) continue;
      placed.add(rect);
      canvas.drawCircle(p, city.tier == 1 ? 2.6 : 2, dot);
      tp.paint(canvas, Offset(p.dx + 5, p.dy - tp.height / 2));
    }
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
