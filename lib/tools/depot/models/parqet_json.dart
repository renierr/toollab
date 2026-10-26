/// Lenient readers for Parqet wire values, which omit fields instead of
/// sending zero.
class ParqetJson {
  ParqetJson._();

  static double number(Object? value) => (value as num?)?.toDouble() ?? 0;

  static double? numberOrNull(Object? value) => (value as num?)?.toDouble();

  static DateTime? date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static DateTime? fromEpoch(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  static Map<String, dynamic> object(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  /// Reads `parent.key.inInterval` blocks of the performance payload.
  static Map<String, dynamic> inInterval(
    Map<String, dynamic> parent,
    String key,
  ) => object(object(parent[key])['inInterval']);
}
