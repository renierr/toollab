import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'web_login.dart';

/// Android's in-app login: a full-screen WebView that pops with a
/// [WebLoginResult] once [target] is reached.
class WebLoginPage extends StatefulWidget {
  final Uri url;
  final String title;
  final WebLoginTarget target;

  const WebLoginPage({
    super.key,
    required this.url,
    required this.title,
    required this.target,
  });

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> with DisposeCleanup {
  static const Duration _cookiePollInterval = Duration(seconds: 1);

  late final WebViewController _controller;
  final WebViewCookieManager _cookies = WebViewCookieManager();
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: (_) {
            _setLoading(false);
            unawaited(_checkCookies());
            unawaited(_checkScript());
          },
        ),
      )
      ..loadRequest(widget.url);
    if (widget.target.cookieUrl != null) {
      final timer = Timer.periodic(_cookiePollInterval, (_) => _checkCookies());
      onDispose(timer.cancel);
    }
    if (widget.target.script != null) {
      final timer = Timer.periodic(_cookiePollInterval, (_) => _checkScript());
      onDispose(timer.cancel);
    }
  }

  void _setLoading(bool loading) {
    if (mounted && _loading != loading) setState(() => _loading = loading);
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final prefix = widget.target.callbackPrefix;
    if (prefix != null && request.url.startsWith(prefix)) {
      _finish(WebLoginRedirect(Uri.parse(request.url)));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _checkCookies() async {
    final cookieUrl = widget.target.cookieUrl;
    final isComplete = widget.target.isComplete;
    if (_done || cookieUrl == null || isComplete == null) return;
    try {
      final list = await _cookies.getCookies(domain: cookieUrl);
      final cookies = {for (final c in list) c.name: c.value};
      if (isComplete(cookies)) _finish(WebLoginCookies(cookies));
    } catch (e) {
      debugLog('[WebLoginPage] Reading cookies failed: $e');
    }
  }

  Future<void> _checkScript() async {
    final script = widget.target.script;
    final isComplete = widget.target.isScriptComplete;
    if (_done || script == null || isComplete == null) return;
    try {
      final value = await _controller.runJavaScriptReturningResult(script);
      if (isComplete(value)) _finish(WebLoginScriptValue(value));
    } catch (e) {
      debugLog('[WebLoginPage] Running login script failed: $e');
    }
  }

  void _finish(WebLoginResult result) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.webLoginReload,
              onPressed: _controller.reload,
            ),
          ],
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
