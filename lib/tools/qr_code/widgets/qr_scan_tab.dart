import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/drop_zone_action_button.dart';
import 'package:tool_lab/tools/qr_code/config.dart';
import 'package:tool_lab/tools/qr_code/qr_codec.dart';

import 'qr_camera_scanner.dart';
import 'qr_mlkit_camera_scanner.dart';
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
  String _engine = 'zxing';

  String? _capturedImagePath;
  Rect? _barcodeRect;
  Size? _cameraImageSize;

  bool get _cameraSupported => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
    _cameraMode = _cameraSupported;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final stored = await DatabaseService.instance.getSetting(
      QrCodeTool.config.id,
      'scanner_engine',
    );
    if (stored != null && mounted) {
      setState(() {
        _engine = stored;
      });
    }
  }

  Future<void> _saveSetting(String value) async {
    setState(() {
      _engine = value;
    });
    await DatabaseService.instance.setSetting(
      QrCodeTool.config.id,
      'scanner_engine',
      value,
    );
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
    String? text;
    Rect? rect;
    Size? size;
    String? capturedPath;

    if (_engine == 'mlkit' && Platform.isAndroid) {
      final result = await QrCodec.decodeImageFileMlKit(path);
      if (result != null) {
        text = result.text;
        rect = result.rect;
        size = result.size;
        capturedPath = path;
      }
    } else {
      text = await QrCodec.decodeImageFile(path);
    }

    if (!mounted) return;
    if (text != null) {
      setState(() {
        _result = text;
        _barcodeRect = rect;
        _cameraImageSize = size;
        _capturedImagePath = capturedPath;
      });
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
        onScanAgain: () {
          setState(() {
            _result = null;
            _capturedImagePath = null;
            _barcodeRect = null;
            _cameraImageSize = null;
          });
        },
        capturedImagePath: _capturedImagePath,
        barcodeRect: _barcodeRect,
        cameraImageSize: _cameraImageSize,
      );
    }

    final Widget cameraView;
    if (_engine == 'mlkit') {
      cameraView = QrMlKitCameraScanner(
        accentColor: _accent,
        scope: _scope,
        onDetected: (text, rect, size, path) {
          setState(() {
            _result = text;
            _barcodeRect = rect;
            _cameraImageSize = size;
            _capturedImagePath = path;
          });
        },
      );
    } else {
      cameraView = QrCameraScanner(
        accentColor: _accent,
        onDetected: (text) => setState(() => _result = text),
      );
    }

    final body = (_cameraSupported && _cameraMode)
        ? cameraView
        : _ImageScanZone(
            accent: _accent,
            extensions: QrCodeTool.config.fileExtensions,
            onFile: _decodeXFile,
            onPaste: _pasteFromClipboard,
            onPickGallery: _pickFromGallery,
          );

    if (!_cameraSupported) return body;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScanModeToggle(
                cameraMode: _cameraMode,
                accentColor: _accent,
                onChanged: (camera) => setState(() => _cameraMode = camera),
              ),
              if (_cameraMode) ...[
                const SizedBox(height: 8),
                _EngineToggle(
                  engine: _engine,
                  accentColor: _accent,
                  onChanged: _saveSetting,
                ),
              ],
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Empty-state for image scanning: drop zone plus paste / gallery actions.
class _ImageScanZone extends StatelessWidget {
  final Color accent;
  final List<String> extensions;
  final ValueChanged<XFile> onFile;
  final VoidCallback onPaste;
  final VoidCallback onPickGallery;

  const _ImageScanZone({
    required this.accent,
    required this.extensions,
    required this.onFile,
    required this.onPaste,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FileDropZone(
        onFileSelected: onFile,
        allowedExtensions: extensions,
        typeLabel: l10n.qrImagesLabel,
        accentColor: accent,
        icon: Icons.qr_code_2_outlined,
        title: l10n.qrScanDropTitle,
        subtitle: l10n.qrScanDropSubtitle,
        buttonLabel: l10n.qrBrowseImage,
        buttonIcon: Icons.folder_open,
        extraButtons: [
          const SizedBox(height: 16),
          DropZoneActionButton(
            onPressed: onPaste,
            icon: Icons.paste_outlined,
            label: l10n.qrPasteImage,
            accentColor: accent,
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 12),
            DropZoneActionButton(
              onPressed: onPickGallery,
              icon: Icons.photo_library_outlined,
              label: l10n.qrPickFromGallery,
              accentColor: accent,
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

class _EngineToggle extends StatelessWidget {
  final String engine;
  final Color accentColor;
  final ValueChanged<String> onChanged;

  const _EngineToggle({
    required this.engine,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'zxing',
          icon: const Icon(Icons.code, size: 18),
          label: Text(l10n.qrScannerEngineZxing),
        ),
        ButtonSegment(
          value: 'mlkit',
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(l10n.qrScannerEngineMlKit),
        ),
      ],
      selected: {engine},
      onSelectionChanged: (s) => onChanged(s.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}
