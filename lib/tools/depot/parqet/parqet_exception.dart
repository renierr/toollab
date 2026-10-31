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

  /// How long the server asked the client to wait, when it said so.
  final Duration? retryAfter;

  /// HTTP status of the failed response, when there was one.
  final int? statusCode;

  const ParqetException(this.kind, [this.detail = ''])
    : retryAfter = null,
      statusCode = null;

  const ParqetException.detailed(
    this.kind,
    this.detail, {
    this.retryAfter,
    this.statusCode,
  });

  /// Only a new interactive login fixes these.
  bool get needsLogin =>
      kind == ParqetErrorKind.notConnected ||
      kind == ParqetErrorKind.unauthorized;

  @override
  String toString() {
    final wait = retryAfter;
    return 'ParqetException(${kind.name})'
        '${wait == null ? '' : ', retry after ${wait.inSeconds}s'}'
        ': $detail';
  }
}
