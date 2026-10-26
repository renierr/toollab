enum ParqetErrorKind {
  notConnected,
  unauthorized,
  denied,
  portBusy,
  timeout,
  network,
  rateLimited,
  server,
  invalidResponse,
}

class ParqetException implements Exception {
  final ParqetErrorKind kind;
  final String detail;

  const ParqetException(this.kind, [this.detail = '']);

  /// Only a new interactive login fixes these.
  bool get needsLogin =>
      kind == ParqetErrorKind.notConnected ||
      kind == ParqetErrorKind.unauthorized;

  @override
  String toString() => 'ParqetException(${kind.name}): $detail';
}
