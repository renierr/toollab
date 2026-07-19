// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;
import 'tools_scanner.dart';

class ConfigPatcher {
  static const String backupDirName = '.agents/temp/standalone_backup';

  final ToolInfo tool;
  final String platform;

  ConfigPatcher({required this.tool, required this.platform});

  /// Path to store backups on disk.
  Directory get _backupDir => Directory(backupDirName);

  /// Performs backups and patches all files for the specified platform.
  Future<void> patch() async {
    // Ensure backup directory exists and is empty
    if (await _backupDir.exists()) {
      await _backupDir.delete(recursive: true);
    }
    await _backupDir.create(recursive: true);

    // Patch global tool registry to isolate dependencies
    await _patchToolRegistry();

    // Patch launcher icons if custom icon is available
    await _patchLauncherIcons();

    if (platform.startsWith('android')) {
      final iconName = 'ic_launcher_${tool.folderName}';
      final hasCustomIcon = await File('android/app/src/main/res/mipmap-anydpi-v26/$iconName.xml').exists();
      final androidIconValue = hasCustomIcon ? '@mipmap/$iconName' : '@mipmap/ic_launcher';

      await _patchFile(
        originalFile: File('android/app/src/main/AndroidManifest.xml'),
        backupName: 'AndroidManifest.xml',
        replacements: {
          'android:label="ToolLab"': 'android:label="${tool.displayName}"',
          'android:icon="@mipmap/ic_launcher"': 'android:icon="$androidIconValue"',
        },
      );
    } else if (platform == 'windows') {
      await _patchFile(
        originalFile: File('windows/CMakeLists.txt'),
        backupName: 'windows_CMakeLists.txt',
        replacements: {
          'set(BINARY_NAME "tool_lab")': 'set(BINARY_NAME "${tool.folderName}")',
        },
      );

      await _patchFile(
        originalFile: File('windows/runner/main.cpp'),
        backupName: 'windows_main.cpp',
        replacements: {
          'L"ToolLab"': 'L"${tool.displayName}"',
        },
      );
    } else if (platform == 'linux') {
      await _patchFile(
        originalFile: File('linux/CMakeLists.txt'),
        backupName: 'linux_CMakeLists.txt',
        replacements: {
          'set(BINARY_NAME "tool_lab")': 'set(BINARY_NAME "${tool.folderName}")',
          'set(APPLICATION_ID "de.renier.tool_lab")':
              'set(APPLICATION_ID "de.renier.tool_lab.${tool.folderName}")',
        },
      );

      await _patchFile(
        originalFile: File('linux/runner/my_application.cc'),
        backupName: 'linux_my_application.cc',
        replacements: {
          'gtk_window_set_title(window, "ToolLab");':
              'gtk_window_set_title(window, "${tool.displayName}");',
        },
      );
    }
  }

  /// Patches a specific file and creates a persistent backup copy on disk.
  Future<void> _patchFile({
    required File originalFile,
    required String backupName,
    required Map<String, String> replacements,
  }) async {
    if (!await originalFile.exists()) return;

    final originalContent = await originalFile.readAsString();

    // Write backup file to disk
    final backupFile = File(p.join(_backupDir.path, backupName));
    // Save mapping metadata so we know where to restore it to
    final pathMappingFile = File('${backupFile.path}.path');
    await backupFile.writeAsString(originalContent);
    await pathMappingFile.writeAsString(originalFile.path);

    // Apply replacements
    var patchedContent = originalContent;
    for (final entry in replacements.entries) {
      patchedContent = patchedContent.replaceAll(entry.key, entry.value);
    }

    await originalFile.writeAsString(patchedContent);
  }

  /// Restores all files that have a pending backup on disk.
  static Future<void> restoreGlobal() async {
    final backupDir = Directory(backupDirName);
    if (!await backupDir.exists()) return;

    print('Restoring backed up configuration files...');
    bool restoredPubspec = false;

    await for (final entity in backupDir.list()) {
      if (entity is File && !entity.path.endsWith('.path')) {
        final pathFile = File('${entity.path}.path');
        if (await pathFile.exists()) {
          final originalPath = await pathFile.readAsString();
          final targetFile = File(originalPath);
          
          if (p.basename(targetFile.path) == 'pubspec.yaml') {
            restoredPubspec = true;
          }

          try {
            await entity.copy(targetFile.path);
            print('  Restored: ${p.basename(targetFile.path)}');
          } catch (e) {
            print('  Failed to restore ${targetFile.path}: $e');
          }
        }
      }
    }

    if (restoredPubspec) {
      print('Restoring dependencies (flutter pub get)...');
      final result = await Process.run('flutter', ['pub', 'get'], runInShell: true);
      if (result.exitCode != 0) {
        print('Warning: flutter pub get failed: ${result.stderr}');
      }
    }

    // Delete backup directory
    try {
      await backupDir.delete(recursive: true);
      print('Backup directory cleared.');
    } catch (_) {}
  }

  /// Checks if a backup folder currently exists on disk.
  static Future<bool> hasBackup() async {
    return await Directory(backupDirName).exists();
  }

  /// Temporarily patches pubspec.yaml to strip dependencies and assets that are not used by the standalone app.
  Future<void> patchPubspec(Set<String> usedPackages, Set<String> usedAssets) async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) return;

    final originalContent = await pubspecFile.readAsString();

    // Write backup file to disk
    final backupFile = File(p.join(_backupDir.path, 'pubspec.yaml'));
    final pathMappingFile = File('${backupFile.path}.path');
    await backupFile.writeAsString(originalContent);
    await pathMappingFile.writeAsString(pubspecFile.path);

    // Patch content
    final lines = originalContent.split('\n');
    final patchedLines = <String>[];
    
    bool inDependencies = false;
    bool inAssets = false;
    int indentToStrip = -1;
    
    for (var line in lines) {
      final trimmed = line.trim();
      
      if (trimmed == 'dependencies:') {
        inDependencies = true;
        patchedLines.add(line);
        continue;
      }

      if (trimmed == 'assets:') {
        inAssets = true;
        patchedLines.add(line);
        continue;
      }
      
      final currentIndent = line.isEmpty ? 0 : line.indexOf(line.trim());

      if (inDependencies && currentIndent == 0 && (trimmed == 'dev_dependencies:' || trimmed == 'flutter:' || trimmed == 'dependency_overrides:')) {
        inDependencies = false;
      }

      if (inAssets && currentIndent <= 2 && trimmed.isNotEmpty && trimmed != 'assets:') {
        inAssets = false;
      }
      
      if (inDependencies && trimmed.isNotEmpty) {
        if (trimmed.startsWith('#')) {
          patchedLines.add(line);
          continue;
        }
        
        if (currentIndent > 2) {
          if (indentToStrip != -1) {
            patchedLines.add('# [STRIPPED] $line');
          } else {
            patchedLines.add(line);
          }
          continue;
        }
        
        final parts = trimmed.split(':');
        final pkgName = parts[0].trim();
        
        final corePackages = {
          'flutter',
          'flutter_localizations',
          'intl',
          'cupertino_icons',
          'sqflite',
          'sqlite3',
          'sqlite3_flutter_libs',
        };
        
        if (corePackages.contains(pkgName) || usedPackages.contains(pkgName)) {
          patchedLines.add(line);
          indentToStrip = -1;
        } else {
          patchedLines.add('# [STRIPPED] $line');
          indentToStrip = currentIndent;
        }
      } else if (inAssets && trimmed.isNotEmpty) {
        if (trimmed.startsWith('#')) {
          patchedLines.add(line);
          continue;
        }

        if (trimmed.startsWith('- assets/')) {
          final assetPath = trimmed.substring(2).trim(); // remove "- "
          if (usedAssets.contains(assetPath)) {
            patchedLines.add(line);
          } else {
            patchedLines.add('# [STRIPPED] $line');
          }
        } else {
          patchedLines.add(line);
        }
      } else {
        patchedLines.add(line);
      }
    }

    await pubspecFile.writeAsString(patchedLines.join('\n'));
    
    // Run flutter pub get to update native project build configurations
    print('Updating dependencies (flutter pub get)...');
    final result = await Process.run('flutter', ['pub', 'get'], runInShell: true);
    if (result.exitCode != 0) {
      print('Warning: flutter pub get failed: ${result.stderr}');
    }
  }

  /// Patches the global tool registry to only reference the target tool.
  Future<void> _patchToolRegistry() async {
    final registryFile = File('lib/core/tool_registry.dart');
    if (!await registryFile.exists()) return;

    final originalContent = await registryFile.readAsString();

    // Write backup file to disk
    final backupFile = File(p.join(_backupDir.path, 'tool_registry.dart'));
    final pathMappingFile = File('${backupFile.path}.path');
    await backupFile.writeAsString(originalContent);
    await pathMappingFile.writeAsString(registryFile.path);

    // Write single-tool registry
    final singleRegistryContent = '''
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/${tool.folderName}/config.dart';

class ToolRegistry {
  static final Map<String, ToolSection> sections = {
    'sensors': ToolSection(
      id: 'sensors',
      title: 'Sensors',
      icon: Icons.sensors,
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleSensors,
    ),
    'utilities': ToolSection(
      id: 'utilities',
      title: 'Utilities',
      icon: Icons.build_outlined,
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleUtilities,
    ),
    'info': ToolSection(
      id: 'info',
      title: 'Information',
      icon: Icons.info_outline,
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleInfo,
    ),
  };

  static List<ToolModel> get all => [
    ${tool.className}.config,
  ];
}
''';

    await registryFile.writeAsString(singleRegistryContent);
  }

  /// Swaps launcher icons if a custom PNG exists under assets/logo/standalone/.
  Future<void> _patchLauncherIcons() async {
    final customIconFile = File('assets/logo/standalone/${tool.id}.png');
    if (!await customIconFile.exists()) return;

    print('Applying custom launcher icons for standalone tool...');

    // 1. Patch main logo inside the app
    final logoFile = File('assets/logo/logo.png');
    if (await logoFile.exists()) {
      await _backupAndReplaceFile(logoFile, customIconFile);
    }

    // 2. Patch Android launcher icons
    final resDir = Directory('android/app/src/main/res');
    if (await resDir.exists()) {
      final densities = ['hdpi', 'mdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final destIcon = File(p.join(resDir.path, 'mipmap-$density', 'ic_launcher.png'));
        if (await destIcon.exists()) {
          await _backupAndReplaceFile(destIcon, customIconFile);
        }
      }

      // Temporarily delete XML adaptive launcher icon so Android falls back to our raster PNG launcher icon
      final adaptiveIcon = File(p.join(resDir.path, 'mipmap-anydpi-v26', 'ic_launcher.xml'));
      if (await adaptiveIcon.exists()) {
        final backupFile = File(p.join(_backupDir.path, 'ic_launcher.xml'));
        final pathMappingFile = File('${backupFile.path}.path');
        await adaptiveIcon.copy(backupFile.path);
        await pathMappingFile.writeAsString(adaptiveIcon.path);

        await adaptiveIcon.delete();
      }
    }
  }

  Future<void> _backupAndReplaceFile(File targetFile, File replacementFile) async {
    // Generate unique backup filename using file path hashing or sanitization
    final safeName = targetFile.path.replaceAll(RegExp(r'[/\\]'), '_');
    final backupFile = File(p.join(_backupDir.path, safeName));
    final pathMappingFile = File('${backupFile.path}.path');

    await targetFile.copy(backupFile.path);
    await pathMappingFile.writeAsString(targetFile.path);

    await replacementFile.copy(targetFile.path);
  }
}
