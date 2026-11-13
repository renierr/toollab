import 'package:path/path.dart' as p;

typedef LocalLinkTarget = ({String path, String? fragment});

class MarkdownLinkResolver {
  MarkdownLinkResolver._();

  static final RegExp _windowsDrive = RegExp(r'^[a-zA-Z]:[\\/]');

  /// A link with a real URL scheme (`https:`, `mailto:`), handed to the OS.
  static bool isExternal(String href) {
    if (_windowsDrive.hasMatch(href)) return false;
    final uri = Uri.tryParse(href);
    return uri != null && uri.hasScheme && uri.scheme != 'file';
  }

  /// Resolves a file link against the folder of [baseFilePath]; null when the
  /// link is relative but the document has no folder on disk.
  static LocalLinkTarget? resolveLocal(
    String href,
    String? baseFilePath, {
    p.Context? context,
  }) {
    final ctx = context ?? p.context;
    if (_windowsDrive.hasMatch(href)) {
      return (path: ctx.normalize(href), fragment: null);
    }
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    final fragment = uri.hasFragment && uri.fragment.isNotEmpty
        ? uri.fragment
        : null;
    if (uri.scheme == 'file') {
      return (path: ctx.fromUri(uri), fragment: fragment);
    }

    final linkPath = Uri.decodeComponent(uri.path);
    if (linkPath.isEmpty) return null;
    if (ctx.isAbsolute(linkPath)) {
      return (path: ctx.normalize(linkPath), fragment: fragment);
    }
    if (baseFilePath == null || baseFilePath.isEmpty) return null;
    final resolved = ctx.normalize(
      ctx.join(ctx.dirname(baseFilePath), linkPath),
    );
    return (path: resolved, fragment: fragment);
  }
}
