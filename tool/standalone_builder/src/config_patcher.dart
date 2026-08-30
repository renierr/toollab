// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart' as img;
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
      // The AndroidManifest itself is fully regenerated later via
      // [generateAndroidManifest] (after the dependency scan, so ML Kit
      // meta-data can be included conditionally). Here we only patch the
      // per-tool applicationId in Gradle.
      await _patchFile(
        originalFile: File('android/app/build.gradle.kts'),
        backupName: 'build.gradle.kts',
        replacements: {
          'applicationId = "de.renier.tool_lab"':
              'applicationId = "de.renier.tool_lab.${tool.folderName}"',
        },
      );
    } else if (platform == 'windows') {
      await _patchFile(
        originalFile: File('windows/CMakeLists.txt'),
        backupName: 'windows_CMakeLists.txt',
        replacements: {
          'set(BINARY_NAME "tool_lab")':
              'set(BINARY_NAME "${tool.folderName}")',
        },
      );

      await _patchFile(
        originalFile: File('windows/runner/main.cpp'),
        backupName: 'windows_main.cpp',
        replacements: {'L"ToolLab"': 'L"${tool.displayName}"'},
      );

      await _patchWindowsIcon();
    } else if (platform == 'linux') {
      await _patchFile(
        originalFile: File('linux/CMakeLists.txt'),
        backupName: 'linux_CMakeLists.txt',
        replacements: {
          'set(BINARY_NAME "tool_lab")':
              'set(BINARY_NAME "${tool.folderName}")',
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
      final result = await Process.run('flutter', [
        'pub',
        'get',
      ], runInShell: true);
      if (result.exitCode != 0) {
        print('Warning: flutter pub get failed: ${result.stderr}');
      }

      // Restore the original pubspec.lock verbatim after pub get
      // (pub get may have resolved slightly different versions)
      final lockBackup = File(p.join(backupDirName, 'pubspec.lock'));
      if (await lockBackup.exists()) {
        final lockPathMapping = File('${lockBackup.path}.path');
        if (await lockPathMapping.exists()) {
          final lockTarget = File(await lockPathMapping.readAsString());
          await lockBackup.copy(lockTarget.path);
          print('  Restored: pubspec.lock');
        }
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
  Future<void> patchPubspec(
    Set<String> usedPackages,
    Set<String> usedAssets,
  ) async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) return;

    final originalContent = await pubspecFile.readAsString();

    // Write backup file to disk
    final backupFile = File(p.join(_backupDir.path, 'pubspec.yaml'));
    final pathMappingFile = File('${backupFile.path}.path');
    await backupFile.writeAsString(originalContent);
    await pathMappingFile.writeAsString(pubspecFile.path);

    // Back up pubspec.lock so it can be restored verbatim
    final lockFile = File('pubspec.lock');
    if (await lockFile.exists()) {
      final lockBackup = File(p.join(_backupDir.path, 'pubspec.lock'));
      final lockPathMapping = File('${lockBackup.path}.path');
      await lockFile.copy(lockBackup.path);
      await lockPathMapping.writeAsString(lockFile.path);
    }

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

      if (inDependencies &&
          currentIndent == 0 &&
          (trimmed == 'dev_dependencies:' ||
              trimmed == 'flutter:' ||
              trimmed == 'dependency_overrides:')) {
        inDependencies = false;
      }

      if (inAssets &&
          currentIndent <= 2 &&
          trimmed.isNotEmpty &&
          trimmed != 'assets:') {
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
    final result = await Process.run('flutter', [
      'pub',
      'get',
    ], runInShell: true);
    if (result.exitCode != 0) {
      print('Warning: flutter pub get failed: ${result.stderr}');
    }
  }

  /// Regenerates AndroidManifest.xml for the standalone tool.
  ///
  /// Prunes the multi-tool manifest down to a single app:
  /// - Only a safe base permission set is declared. Sensitive permissions
  ///   (camera, microphone, location, bluetooth, NFC) and their features are
  ///   contributed by the tool's plugins via Gradle manifest merging — and
  ///   since unused plugins are stripped from pubspec for this build, those
  ///   permissions disappear automatically for tools that don't need them.
  /// - All activity-aliases and the extra isolated activities are dropped.
  /// - Share/open-with intent-filters are generated only from the tool's
  ///   declared `shareTarget.accept` MIME patterns (none if it has no target).
  /// - ML Kit dependency meta-data is emitted only when the tool uses a
  ///   google_mlkit_* package.
  ///
  /// [usedPackages] is the dependency set computed by the builder's scan.
  Future<void> generateAndroidManifest(Set<String> usedPackages) async {
    final manifestFile = File('android/app/src/main/AndroidManifest.xml');
    if (!await manifestFile.exists()) return;

    // Back up the original so restoreGlobal() puts it back.
    final backupFile = File(p.join(_backupDir.path, 'AndroidManifest.xml'));
    final pathMappingFile = File('${backupFile.path}.path');
    await backupFile.writeAsString(await manifestFile.readAsString());
    await pathMappingFile.writeAsString(manifestFile.path);

    final usesMlKit = usedPackages.any((pkg) => pkg.startsWith('google_mlkit'));
    final label = tool.displayName.replaceAll('"', '\\"');

    await manifestFile.writeAsString(
      _buildManifest(label: label, usesMlKit: usesMlKit),
    );
  }

  String _buildManifest({required String label, required bool usesMlKit}) {
    final shareFilters = _buildShareIntentFilters();
    final mlKitMeta = usesMlKit
        ? '''
        <meta-data
            android:name="com.google.mlkit.vision.DEPENDENCIES"
            android:value="document_ui,barcode,subject_segment,ocr" />
'''
        : '';

    return '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Base permissions for the standalone app. Sensitive permissions
         (CAMERA, RECORD_AUDIO, ACCESS_*_LOCATION, BLUETOOTH*, NFC) and their
         features are merged in automatically from the tool's plugins. -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <application
        android:label="$label"
        android:name="\${applicationName}"
        android:allowAudioPlaybackCapture="true"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <meta-data
              android:name="flutter_deeplinking_enabled"
              android:value="false"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>$shareFilters
        </activity>

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="\${applicationId}.fileprovider;\${applicationId}.provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>

        <service
            android:name=".ToolLabForegroundService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />
$mlKitMeta        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <package android:name="com.google.android.aicore" />
    </queries>
</manifest>
''';
  }

  /// Builds SEND / SEND_MULTIPLE / VIEW intent-filters from the tool's declared
  /// share MIME patterns. Returns an empty string when the tool declares none.
  String _buildShareIntentFilters() {
    if (tool.shareAcceptMimes.isEmpty) return '';

    final dataTags = tool.shareAcceptMimes
        .map((mime) => '                <data android:mimeType="$mime" />')
        .join('\n');

    return '''

            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
$dataTags
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
$dataTags
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="file" />
                <data android:scheme="content" />
$dataTags
            </intent-filter>''';
  }

  /// Extracts the `static final Map<String, ToolSection> sections = {...};`
  /// declaration verbatim from the real tool_registry.dart source, so the
  /// generated single-tool registry always matches the live section list.
  String _extractSectionsBlock(String content) {
    const marker = 'static final Map<String, ToolSection> sections = ';
    final startIdx = content.indexOf(marker);
    if (startIdx == -1) {
      throw StateError(
        'Could not find "$marker" in lib/core/tool_registry.dart',
      );
    }

    final braceStart = content.indexOf('{', startIdx);
    var depth = 0;
    var i = braceStart;
    for (; i < content.length; i++) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') {
        depth--;
        if (depth == 0) break;
      }
    }

    final endIdx = content.indexOf(';', i) + 1;
    return content.substring(startIdx, endIdx);
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

    // Write single-tool registry, copying the real sections map verbatim so
    // it can never drift out of sync with lib/core/tool_registry.dart.
    final sectionsBlock = _extractSectionsBlock(originalContent);
    final singleRegistryContent =
        '''
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/${tool.folderName}/config.dart';

class ToolRegistry {
  $sectionsBlock

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
        final destIcon = File(
          p.join(resDir.path, 'mipmap-$density', 'ic_launcher.png'),
        );
        if (await destIcon.exists()) {
          await _backupAndReplaceFile(destIcon, customIconFile);
        }
      }

      // Temporarily delete XML adaptive launcher icon so Android falls back to our raster PNG launcher icon
      final adaptiveIcon = File(
        p.join(resDir.path, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
      );
      if (await adaptiveIcon.exists()) {
        final backupFile = File(p.join(_backupDir.path, 'ic_launcher.xml'));
        final pathMappingFile = File('${backupFile.path}.path');
        await adaptiveIcon.copy(backupFile.path);
        await pathMappingFile.writeAsString(adaptiveIcon.path);

        await adaptiveIcon.delete();
      }
    }
  }

  /// Regenerates the Windows executable icon (`app_icon.ico`) from the tool's
  /// standalone PNG. Without this the standalone .exe keeps the ToolLab icon.
  /// (Linux Flutter runners embed no binary icon, so nothing to patch there.)
  Future<void> _patchWindowsIcon() async {
    final customIconFile = File('assets/logo/standalone/${tool.id}.png');
    if (!await customIconFile.exists()) return;

    final icoFile = File('windows/runner/resources/app_icon.ico');
    if (!await icoFile.exists()) return;

    final decoded = img.decodePng(await customIconFile.readAsBytes());
    if (decoded == null) return;

    print('Applying custom Windows app icon...');

    // Back up the original .ico so restoreGlobal() puts it back.
    final safeName = icoFile.path.replaceAll(RegExp(r'[/\\]'), '_');
    final backupFile = File(p.join(_backupDir.path, safeName));
    await icoFile.copy(backupFile.path);
    await File('${backupFile.path}.path').writeAsString(icoFile.path);

    final resized = img.copyResize(decoded, width: 256, height: 256);
    await icoFile.writeAsBytes(img.encodeIco(resized));
  }

  Future<void> _backupAndReplaceFile(
    File targetFile,
    File replacementFile,
  ) async {
    // Generate unique backup filename using file path hashing or sanitization
    final safeName = targetFile.path.replaceAll(RegExp(r'[/\\]'), '_');
    final backupFile = File(p.join(_backupDir.path, safeName));
    final pathMappingFile = File('${backupFile.path}.path');

    await targetFile.copy(backupFile.path);
    await pathMappingFile.writeAsString(targetFile.path);

    await replacementFile.copy(targetFile.path);
  }
}
