import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'converters/document_codec.dart';
import 'doc_format.dart';

class FileConverterState extends ChangeNotifier {
  String? _inputPath;
  String? _inputName;
  DocFormat? _inputFormat;
  DocFormat? _selectedTarget;
  List<DocFormat> _targets = const [];
  bool _isConverting = false;
  String? _error;

  String? get inputPath => _inputPath;
  String? get inputName => _inputName;
  DocFormat? get inputFormat => _inputFormat;
  DocFormat? get selectedTarget => _selectedTarget;
  List<DocFormat> get targets => _targets;
  bool get isConverting => _isConverting;
  String? get error => _error;

  /// Whether the loaded file is a format the converter can read.
  bool get isSupported =>
      _inputFormat != null && DocumentConverter.canDecode(_inputFormat!);

  void loadFile(String path, String name) {
    _inputPath = path;
    _inputName = name;
    _inputFormat = DocFormat.fromPath(name);
    _error = null;
    if (_inputFormat != null && DocumentConverter.canDecode(_inputFormat!)) {
      _targets = DocumentConverter.targetsFor(_inputFormat!);
      _selectedTarget = _targets.isNotEmpty ? _targets.first : null;
    } else {
      _targets = const [];
      _selectedTarget = null;
    }
    notifyListeners();
  }

  void selectTarget(DocFormat format) {
    _selectedTarget = format;
    notifyListeners();
  }

  void clear() {
    _inputPath = null;
    _inputName = null;
    _inputFormat = null;
    _selectedTarget = null;
    _targets = const [];
    _isConverting = false;
    _error = null;
    notifyListeners();
  }

  Future<void> convert(BuildContext context, TempFileScope scope) async {
    final path = _inputPath;
    final name = _inputName;
    final from = _inputFormat;
    final to = _selectedTarget;
    if (path == null || name == null || from == null || to == null) return;

    _isConverting = true;
    _error = null;
    notifyListeners();

    try {
      final bytes = await File(path).readAsBytes();
      final output = await DocumentConverter.convert(bytes, from, to);

      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final outName = '$base.${to.canonicalExtension}';

      final tempPath = await scope.createFile(outName, bytes: output);
      if (context.mounted) {
        await FileSaveHelper.saveFileFromPath(
          context: context,
          sourcePath: tempPath,
          suggestedName: outName,
        );
      }
    } catch (e) {
      _error = e.toString();
      errorLog('[FileConverterState] Conversion failed: $e');
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }
}
