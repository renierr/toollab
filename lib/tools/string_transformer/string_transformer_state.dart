import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/shared_file.dart';

class StringTransformerState extends ChangeNotifier {
  String _inputText = '';
  String get inputText => _inputText;

  String _outputText = '';
  String get outputText => _outputText;

  String _transformType = 'camel-case';
  String get transformType => _transformType;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setInputText(String text) {
    if (_inputText == text) return;
    _inputText = text;
    _transform();
  }

  void setTransformType(String type) {
    if (_transformType == type) return;
    _transformType = type;
    _transform();
  }

  void clear() {
    _inputText = '';
    _outputText = '';
    _errorMessage = null;
    notifyListeners();
  }

  void swap() {
    final temp = _inputText;
    _inputText = _outputText;
    _outputText = temp;
    _transform();
  }

  Future<void> loadSharedData(SharedData data) async {
    if (data.text != null) {
      setInputText(data.text!);
    } else {
      final file = data.firstFile;
      if (file != null) {
        try {
          final diskFile = File(file.path);
          if (await diskFile.exists()) {
            final content = await diskFile.readAsString();
            setInputText(content);
          }
        } catch (_) {
          // Silently fail or handle error if needed
        }
      }
    }
  }

  void _transform() {
    _errorMessage = null;
    if (_inputText.isEmpty) {
      _outputText = '';
      notifyListeners();
      return;
    }

    try {
      _outputText = _performTransform(_inputText, _transformType);
    } catch (e) {
      _errorMessage = e is FormatException ? e.message : e.toString();
      _outputText = '';
    }
    notifyListeners();
  }

  String _performTransform(String input, String type) {
    switch (type) {
      case 'camel-case':
        return _toCamelCase(input);
      case 'snake-case':
        return _toSnakeCase(input);
      case 'kebab-case':
        return _toKebabCase(input);
      case 'pascal-case':
        return _toPascalCase(input);
      case 'url-slug':
        return _toUrlSlug(input);
      case 'base64-encode':
        return base64.encode(utf8.encode(input));
      case 'base64-decode':
        try {
          return utf8.decode(base64.decode(input.trim()));
        } catch (_) {
          throw const FormatException('Invalid Base64 string');
        }
      case 'hex-encode':
        return utf8
            .encode(input)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join('');
      case 'hex-decode':
        final cleaned = input.replaceAll(RegExp(r'\s+'), '');
        if (cleaned.length % 2 != 0) {
          throw const FormatException('Hex string has odd length');
        }
        if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned)) {
          throw const FormatException('Invalid hex string');
        }
        final bytes = <int>[];
        for (int i = 0; i < cleaned.length; i += 2) {
          final hexPart = cleaned.substring(i, i + 2);
          bytes.add(int.parse(hexPart, radix: 16));
        }
        try {
          return utf8.decode(bytes);
        } catch (_) {
          throw const FormatException('Invalid UTF-8 sequence in hex');
        }
      case 'ad-url-decode':
        return _decodeAdUrl(input);
      default:
        return input;
    }
  }

  List<String> _splitIntoWords(String str) {
    final regex1 = RegExp(r'([a-z\d])([A-Z])');
    final regex2 = RegExp(r'([A-Z]+)([A-Z][a-z\d])');
    String temp = str.replaceAllMapped(regex1, (m) => '${m[1]} ${m[2]}');
    temp = temp.replaceAllMapped(regex2, (m) => '${m[1]} ${m[2]}');
    return temp
        .split(RegExp(r'[\s_\-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toList();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _toCamelCase(String input) {
    final words = _splitIntoWords(input);
    if (words.isEmpty) return input;
    return words[0] + words.skip(1).map(_capitalize).join('');
  }

  String _toPascalCase(String input) {
    final words = _splitIntoWords(input);
    if (words.isEmpty) return input;
    return words.map(_capitalize).join('');
  }

  String _toSnakeCase(String input) {
    final words = _splitIntoWords(input);
    if (words.isEmpty) return input;
    return words.join('_');
  }

  String _toKebabCase(String input) {
    final words = _splitIntoWords(input);
    if (words.isEmpty) return input;
    return words.join('-');
  }

  String _toUrlSlug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _decodeAdUrl(String input) {
    if (input.isEmpty) return '';
    try {
      final uri = Uri.parse(input.trim());
      final lines = <String>[];

      void findUrls(String text) {
        final match = RegExp(
          r'(https?:\/\/[^\s&]+)',
          caseSensitive: false,
        ).firstMatch(text);
        if (match != null) {
          lines.add(match.group(1)!);
        }
        try {
          final normalizedB64 = text.replaceAll('-', '+').replaceAll('_', '/');
          String padded = normalizedB64;
          while (padded.length % 4 != 0) {
            padded += '=';
          }
          final decodedB64 = utf8.decode(base64.decode(padded));
          final b64Match = RegExp(
            r'(https?:\/\/[^\s&]+)',
            caseSensitive: false,
          ).firstMatch(decodedB64);
          if (b64Match != null) {
            lines.add(b64Match.group(1)!);
          }
        } catch (_) {}
      }

      uri.queryParameters.forEach((key, val) {
        findUrls(val);
      });

      final pathMatch = RegExp(
        r'(https?:\/\/[^\s?#]+)',
        caseSensitive: false,
      ).firstMatch(uri.path);
      if (pathMatch != null) {
        lines.add(pathMatch.group(1)!);
      }

      if (uri.fragment.isNotEmpty) {
        findUrls(uri.fragment);
      }

      final unique = lines.toSet().toList();
      return unique.isNotEmpty
          ? unique.join('\n')
          : 'No embedded URL detected.';
    } catch (_) {
      throw const FormatException('Invalid URL');
    }
  }
}
