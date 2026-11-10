import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'desktop_web_login.dart';
import 'web_login_page.dart';

/// Decides when an in-app login is done, from the URL being navigated to or
/// the cookies the site has set so far.
class WebLoginTarget {
  /// Navigations starting with this end the login and are never loaded, so a
  /// loopback OAuth redirect needs no listener and no cleartext permission.
  final String? callbackPrefix;

  /// Polled while the page is open; [isComplete] sees the cookies of [url].
  final Uri? cookieUrl;
  final bool Function(Map<String, String> cookies)? isComplete;

  const WebLoginTarget.redirect(String this.callbackPrefix)
    : cookieUrl = null,
      isComplete = null;

  const WebLoginTarget.cookies({
    required Uri this.cookieUrl,
    required bool Function(Map<String, String> cookies) this.isComplete,
  }) : callbackPrefix = null;
}

sealed class WebLoginResult {
  const WebLoginResult();
}

class WebLoginRedirect extends WebLoginResult {
  final Uri uri;
  const WebLoginRedirect(this.uri);
}

class WebLoginCookies extends WebLoginResult {
  final Map<String, String> cookies;
  const WebLoginCookies(this.cookies);
}

/// A login page inside the app, for devices without a browser (Android TV)
/// and for sites whose session cookies the app needs to keep. Android embeds a
/// WebView page; Windows and Linux open a native browser window.
class WebLogin {
  WebLogin._();

  static bool get isSupported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  /// Null when the user closed the login before it completed.
  static Future<WebLoginResult?> open(
    BuildContext context, {
    required Uri url,
    required String title,
    required WebLoginTarget target,
  }) async {
    if (Platform.isAndroid) {
      return Navigator.of(context).push<WebLoginResult>(
        MaterialPageRoute(
          builder: (_) => WebLoginPage(url: url, title: title, target: target),
        ),
      );
    }
    if (Platform.isWindows || Platform.isLinux) {
      return DesktopWebLogin.open(url: url, title: title, target: target);
    }
    return null;
  }

  static Future<Uri?> captureRedirect(
    BuildContext context, {
    required Uri url,
    required String callbackPrefix,
    required String title,
  }) async {
    final result = await open(
      context,
      url: url,
      title: title,
      target: WebLoginTarget.redirect(callbackPrefix),
    );
    return result is WebLoginRedirect ? result.uri : null;
  }

  /// Forgets every site's login so the next one starts signed out.
  static Future<void> clearCookies() async {
    try {
      if (Platform.isAndroid) {
        await WebViewCookieManager().clearCookies();
      } else if (Platform.isWindows || Platform.isLinux) {
        await WebviewWindow.clearAll(windows: await DesktopWebLogin.options());
      }
    } catch (e) {
      errorLog('[WebLogin] Clearing cookies failed: $e');
    }
  }
}
