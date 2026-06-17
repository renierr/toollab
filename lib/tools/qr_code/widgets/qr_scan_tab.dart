import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:flutter_zxing/flutter_zxing.dart' show zx;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/drop_zone_action_button.dart';
import 'package:tool_lab/tools/qr_code/config.dart';
import 'package:tool_lab/tools/qr_code/qr_codec.dart';

import 'qr_camera_scanner.dart';
import 'qr_result_card.dart';

/// Scan tab: live camera scanning on Android plus scan-from-image
/// (pick / drag-drop / paste) on every platform.
class QrScanTab extends StatefulWidget {
  const QrScanTab({super.key});

  @override
  State<QrScanTab> createState() => _QrScanTabState();
}

class _QrScanTabState extends State<QrScanTab> with DisposeCleanup {
  late final TempFileScope _scope;
  String? _result;
  bool _cameraMode = false;
  int _seq = 0;

  bool get _cameraSupported => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
    _cameraMode = _cameraSupported;
    if (_cameraSupported) {
      zx.startCameraProcessing();
      onDispose(() => zx.stopCameraProcessing());
    }
  }

  Color get _accent => QrCodeTool.config.accentColor;

  Future<void> _decodeXFile(XFile file) async {
    String path = file.path;
    if (path.isEmpty) {
      final bytes = await file.readAsBytes();
      path = await _scope.createFile('scan_${_seq++}.png', bytes: bytes);
    }
    await _decodePath(path);
  }

  Future<void> _decodePath(String path) async {
    final text = await QrCodec.decodeImageFile(path);
    if (!mounted) return;
    if (text != null) {
      setState(() => _result = text);
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.qrNoCodeFound)));
    }
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await ClipboardHelper.getImagePng();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.qrNoImageInClipboard)));
      }
      return;
    }
    final path = await _scope.createFile('paste_${_seq++}.png', bytes: bytes);
    await _decodePath(path);
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _decodeXFile(XFile(picked.path, name: picked.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return QrResultCard(
        text: _result!,
        accentColor: _accent,
        scope: _scope,
        onScanAgain: () => setState(() => _result = null),
      );
    }

    final body = (_cameraSupported && _cameraMode)
        ? QrCameraScanner(
            accentColor: _accent,
            onDetected: (text) => setState(() => _result = text),
          )
        : _buildImageScanZone();

    if (!_cameraSupported) return body;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _ScanModeToggle(
            cameraMode: _cameraMode,
            accentColor: _accent,
            onChanged: (camera) => setState(() => _cameraMode = camera),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildImageScanZone() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FileDropZone(
        onFileSelected: _decodeXFile,
        allowedExtensions: QrCodeTool.config.fileExtensions,
        typeLabel: l10n.qrImagesLabel,
        accentColor: _accent,
        icon: Icons.qr_code_2_outlined,
        title: l10n.qrScanDropTitle,
        subtitle: l10n.qrScanDropSubtitle,
        buttonLabel: l10n.qrBrowseImage,
        buttonIcon: Icons.folder_open,
        extraButtons: [
          const SizedBox(height: 16),
          DropZoneActionButton(
            onPressed: _pasteFromClipboard,
            icon: Icons.paste_outlined,
            label: l10n.qrPasteImage,
            accentColor: _accent,
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 12),
            DropZoneActionButton(
              onPressed: _pickFromGallery,
              icon: Icons.photo_library_outlined,
              label: l10n.qrPickFromGallery,
              accentColor: _accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanModeToggle extends StatelessWidget {
  final bool cameraMode;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _ScanModeToggle({
    required this.cameraMode,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(l10n.qrModeCamera),
        ),
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.image_outlined, size: 18),
          label: Text(l10n.qrModeImage),
        ),
      ],
      selected: {cameraMode},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}
