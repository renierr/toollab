import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/web_login/desktop_web_login.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mermaid_viewer_page.dart';

/// Renders a Mermaid diagram with the bundled mermaid.js in a WebView: an
/// in-app page on Android, a native window on Windows and Linux.
class MermaidViewer {
  MermaidViewer._();

  static const String _asset = 'assets/mermaid/mermaid.min.js';
  static const String _dir = 'mermaid';

  static Future<void> open(BuildContext context, String source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;
    final title = l10n.widgetMermaidTitle;
    try {
      final path = await _writePage(source, scheme);
      if (Platform.isAndroid) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => MermaidViewerPage(path: path, title: title),
          ),
        );
      } else if ((Platform.isWindows || Platform.isLinux) &&
          await WebviewWindow.isWebviewAvailable()) {
        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            title: title,
            windowWidth: 1100,
            windowHeight: 800,
            brightness: brightness,
            titleBar: const TitleBarOptions(
              showNavigation: false,
              showHost: false,
            ),
            windows: await DesktopWebLogin.options(),
          ),
        );
        await webview.launch(Uri.file(path).toString());
      } else if (!await launchUrl(Uri.file(path))) {
        throw StateError('no handler for $path');
      }
    } catch (e) {
      errorLog('[MermaidViewer] Opening diagram failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.widgetMermaidOpenFailed(e.toString()))),
      );
    }
  }

  static Future<String> _writePage(String source, ColorScheme scheme) async {
    final script = await TempFileManager.resolveFile('$_dir/mermaid.min.js');
    if (!await script.exists()) {
      final data = await rootBundle.load(_asset);
      await TempFileManager.createFile(
        '$_dir/mermaid.min.js',
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    final html = _html(source, scheme);
    final name = '$_dir/diagram-${html.hashCode.toUnsigned(32)}.html';
    return TempFileManager.createFile(
      name,
      bytes: Uint8List.fromList(utf8.encode(html)),
    );
  }

  static String _css(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _html(String source, ColorScheme scheme) {
    // `</` would end the inline script early.
    final src = jsonEncode(source).replaceAll('</', r'<\/');
    final dark = scheme.brightness == Brightness.dark;
    final background = _css(scheme.surface);
    final foreground = _css(scheme.onSurface);
    final error = _css(scheme.error);
    return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html, body { margin: 0; background: $background; color: $foreground; }
  #diagram { padding: 16px; display: flex; justify-content: center; }
  #error { padding: 16px; white-space: pre-wrap; font-family: monospace; color: $error; }
</style>
<script src="mermaid.min.js"></script>
</head>
<body>
<div id="diagram"></div>
<div id="error"></div>
<script>
  mermaid.initialize({ startOnLoad: false, theme: '${dark ? 'dark' : 'default'}' });
  mermaid.render('graph', $src)
    .then(function (r) { document.getElementById('diagram').innerHTML = r.svg; })
    .catch(function (e) { document.getElementById('error').textContent = String(e && e.message || e); });
</script>
</body>
</html>
''';
  }
}
