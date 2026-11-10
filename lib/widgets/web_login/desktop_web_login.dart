import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'web_login.dart';

/// Windows and Linux login in a native browser window (WebView2 / WebKitGTK).
class DesktopWebLogin {
  DesktopWebLogin._();

  static const Duration _cookiePollInterval = Duration(seconds: 1);

  /// The profile lives in app support, not next to a possibly read-only exe.
  static Future<WindowsWebviewOptions> options() async {
    final support = await getApplicationSupportDirectory();
    return WindowsWebviewOptions(
      userDataFolder: p.join(support.path, 'WebView2'),
    );
  }

  static Future<WebLoginResult?> open({
    required Uri url,
    required String title,
    required WebLoginTarget target,
  }) async {
    if (!await WebviewWindow.isWebviewAvailable()) return null;
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: title,
        windowWidth: 520,
        windowHeight: 760,
        windows: await options(),
      ),
    );

    final completer = Completer<WebLoginResult?>();
    void finish(WebLoginResult? result) {
      if (completer.isCompleted) return;
      completer.complete(result);
      unawaited(webview.close());
    }

    unawaited(webview.onClose.then((_) => finish(null)));

    final prefix = target.callbackPrefix;
    if (prefix != null) {
      await webview.setOnUrlRequestCallback((requested) {
        if (!requested.startsWith(prefix)) return true;
        finish(WebLoginRedirect(Uri.parse(requested)));
        return false;
      });
    }

    Timer? poll;
    final cookieUrl = target.cookieUrl;
    final isComplete = target.isComplete;
    if (cookieUrl != null && isComplete != null) {
      var reading = false;
      poll = Timer.periodic(_cookiePollInterval, (_) async {
        if (reading || completer.isCompleted) return;
        reading = true;
        try {
          final host = cookieUrl.host;
          final cookies = {
            for (final c in await webview.getAllCookies())
              if (_matches(c.domain, host)) c.name: c.value,
          };
          if (isComplete(cookies)) finish(WebLoginCookies(cookies));
        } catch (e) {
          debugLog('[DesktopWebLogin] Reading cookies failed: $e');
        } finally {
          reading = false;
        }
      });
    }

    await webview.launch(url.toString());
    try {
      return await completer.future;
    } finally {
      poll?.cancel();
    }
  }

  static bool _matches(String cookieDomain, String host) {
    final domain = cookieDomain.startsWith('.')
        ? cookieDomain.substring(1)
        : cookieDomain;
    return host == domain || host.endsWith('.$domain');
  }
}
