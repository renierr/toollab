import 'package:flutter/painting.dart';

/// A tag, correspondent or document type — the three share one shape.
class PaperlessLabel {
  final int id;
  final String name;
  final int documentCount;
  final Color? color;
  final bool isInboxTag;

  const PaperlessLabel({
    required this.id,
    required this.name,
    this.documentCount = 0,
    this.color,
    this.isInboxTag = false,
  });

  // paperless-ng (API v1) sends a palette index in `colour` instead of a hex.
  static const List<int> _legacyPalette = [
    0xFFA6CEE3,
    0xFF1F78B4,
    0xFFB2DF8A,
    0xFF33A02C,
    0xFFFB9A99,
    0xFFE31A1C,
    0xFFFDBF6F,
    0xFFFF7F00,
    0xFFCAB2D6,
    0xFF6A3D9A,
    0xFFB15928,
    0xFF000000,
    0xFFCCCCCC,
  ];

  factory PaperlessLabel.fromJson(Map<String, dynamic> json) {
    return PaperlessLabel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      documentCount: json['document_count'] as int? ?? 0,
      color: _parseColor(json['color']) ?? _legacyColor(json['colour']),
      isInboxTag: json['is_inbox_tag'] as bool? ?? false,
    );
  }

  static Color? _parseColor(Object? value) {
    if (value is! String || !value.startsWith('#') || value.length != 7) {
      return null;
    }
    final rgb = int.tryParse(value.substring(1), radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  static Color? _legacyColor(Object? value) {
    if (value is! int || value < 1 || value > _legacyPalette.length) {
      return null;
    }
    return Color(_legacyPalette[value - 1]);
  }
}
