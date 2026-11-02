/// Marks a system screen the app opened itself (file picker), so handlers that
/// lock on backgrounding can tell it apart from the user leaving the app.
abstract final class ExternalActivity {
  static int _depth = 0;

  static bool get active => _depth > 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
    }
  }
}
