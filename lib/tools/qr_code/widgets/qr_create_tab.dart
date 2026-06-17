import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/qr_code/config.dart';
import 'package:tool_lab/tools/qr_code/qr_codec.dart';
import 'package:tool_lab/tools/qr_code/qr_content_type.dart';

import 'qr_create_form.dart';
import 'qr_preview_panel.dart';
import 'qr_type_chips.dart';

/// Create tab: pick a content type, fill the form, get a live QR preview that
/// can be saved, copied, or shared.
class QrCreateTab extends StatefulWidget {
  const QrCreateTab({super.key});

  @override
  State<QrCreateTab> createState() => _QrCreateTabState();
}

class _QrCreateTabState extends State<QrCreateTab> with DisposeCleanup {
  late final TempFileScope _scope;
  QrContentType _type = QrContentType.text;
  Uint8List? _png;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
  }

  Color get _accent => QrCodeTool.config.accentColor;

  void _onPayloadChanged(String payload) {
    if (payload.isEmpty) {
      setState(() {
        _png = null;
        _error = null;
      });
      return;
    }
    try {
      final bytes = QrCodec.encodePng(payload);
      setState(() {
        _png = bytes;
        _error = null;
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _png = null;
        _error = l10n.qrEncodeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = QrCreateForm(type: _type, onPayloadChanged: _onPayloadChanged);
    final preview = QrPreviewPanel(
      pngBytes: _png,
      error: _error,
      accentColor: _accent,
      scope: _scope,
    );
    final chips = Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: QrTypeChips(
        selected: _type,
        onSelected: (t) => setState(() => _type = t),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Column(
            children: [
              chips,
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: form,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: SingleChildScrollView(child: preview)),
                  ],
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              chips,
              preview,
              Padding(padding: const EdgeInsets.all(16), child: form),
            ],
          ),
        );
      },
    );
  }
}
