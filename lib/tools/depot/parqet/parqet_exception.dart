enum ParqetErrorKind {
  notConnected,
  unauthorized,
  denied,

  /// The integration lacks a requested scope; fixed in the developer console.
  scopeNotAllowed,
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
