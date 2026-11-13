import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidViewerPage extends StatefulWidget {
  final String path;
  final String title;

  const MermaidViewerPage({super.key, required this.path, required this.title});

  @override
  State<MermaidViewerPage> createState() => _MermaidViewerPageState();
}

class _MermaidViewerPageState extends State<MermaidViewerPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..loadFile(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
