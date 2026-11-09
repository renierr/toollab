import 'package:flutter/material.dart';

/// Multiplies the inherited text scaling by [scale] for [child].
class NewsTextScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const NewsTextScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        textScaler: _MultipliedTextScaler(data.textScaler, scale),
      ),
      child: child,
    );
  }
}

// Keeps the system's (possibly nonlinear) scaling and multiplies its result.
class _MultipliedTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;

  const _MultipliedTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _MultipliedTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
