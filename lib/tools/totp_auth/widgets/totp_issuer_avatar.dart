import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

/// Round issuer badge with a stable color per service name.
class TotpIssuerAvatar extends StatelessWidget {
  final String label;
  final double size;

  const TotpIssuerAvatar({super.key, required this.label, this.size = 36});

  static const _palette = [
    AppTheme.accentBlue,
    AppTheme.accentPurple,
    AppTheme.accentTeal,
    AppTheme.accentGreen,
    AppTheme.accentAmberLight,
  ];

  @override
  Widget build(BuildContext context) {
    final name = label.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final color = _palette[_stableHash(name) % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final unit in value.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
