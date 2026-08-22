import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// Maps file extensions to re-highlight grammars for the editor.
class TextEditorLanguages {
  TextEditorLanguages._();

  static const Map<String, String> _extToKey = {
    'dart': 'dart',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'mts': 'typescript',
    'cts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'pyw': 'python',
    'json': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'xml': 'xml',
    'svg': 'xml',
    'html': 'xml',
    'htm': 'xml',
    'css': 'css',
    'scss': 'css',
    'less': 'css',
    'sql': 'sql',
    'md': 'markdown',
    'markdown': 'markdown',
    'sh': 'bash',
    'bash': 'bash',
    'zsh': 'bash',
    'bat': 'dos',
    'cmd': 'dos',
    'ps1': 'powershell',
    'java': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'go': 'go',
    'rs': 'rust',
    'c': 'cpp',
    'h': 'cpp',
    'cpp': 'cpp',
    'hpp': 'cpp',
    'cc': 'cpp',
    'cs': 'csharp',
    'rb': 'ruby',
    'php': 'php',
    'ini': 'ini',
    'cfg': 'ini',
    'conf': 'ini',
    'toml': 'ini',
    'properties': 'ini',
    'env': 'ini',
  };

  static final Map<String, Mode> _keyModes = {
    'bash': langBash,
    'cpp': langCpp,
    'csharp': langCsharp,
    'css': langCss,
    'dart': langDart,
    'dos': langDos,
    'go': langGo,
    'ini': langIni,
    'java': langJava,
    'javascript': langJavascript,
    'json': langJson,
    'kotlin': langKotlin,
    'markdown': langMarkdown,
    'php': langPhp,
    'powershell': langPowershell,
    'python': langPython,
    'ruby': langRuby,
    'rust': langRust,
    'sql': langSql,
    'typescript': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
  };

  /// Highlight grammar keys (also display labels), or null for plain text.
  static const List<String> supportedKeys = [
    'bash',
    'cpp',
    'csharp',
    'css',
    'dart',
    'go',
    'ini',
    'java',
    'javascript',
    'json',
    'kotlin',
    'markdown',
    'php',
    'powershell',
    'python',
    'ruby',
    'rust',
    'sql',
    'typescript',
    'xml',
    'yaml',
  ];

  static String? keyForFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return _extToKey[fileName.substring(dot + 1).toLowerCase()];
  }

  static CodeHighlightTheme themeFor(String key, Brightness brightness) {
    return CodeHighlightTheme(
      languages: {
        key: CodeHighlightThemeMode(mode: _keyModes[key] ?? langDart),
      },
      theme: brightness == Brightness.dark
          ? atomOneDarkTheme
          : atomOneLightTheme,
    );
  }
}
