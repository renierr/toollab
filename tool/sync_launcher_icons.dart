// ignore_for_file: avoid_print

// Syncs the per-tool adaptive launcher icons used by app-drawer activity
// aliases and home-screen pinned shortcuts.
//
// Source of truth: `assets/logo/standalone/<tool-id>.png` (square, ideally
// 512x512). This script creates Android 8+ adaptive-icon definitions plus
// legacy PNG fallbacks for older Android versions.
//
// Run after adding or changing any icon under assets/logo/standalone/:
//   dart run tool/sync_launcher_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

// Legacy launcher icon edge lengths per density bucket (px).
const Map<String, int> _legacyIconSizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

// Adaptive icon foreground viewports are 108dp.
const Map<String, int> _adaptiveForegroundSizes = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

void main() async {
  final sourceDir = Directory('assets/logo/standalone');
  if (!await sourceDir.exists()) {
    print('Error: ${sourceDir.path} not found. Run from the repo root.');
    exit(1);
  }

  final resDir = Directory('android/app/src/main/res');
  if (!await resDir.exists()) {
    print('Error: ${resDir.path} not found. Run from the repo root.');
    exit(1);
  }

  var synced = 0;
  await for (final entity in sourceDir.list()) {
    if (entity is! File || p.extension(entity.path) != '.png') continue;

    final toolId = p.basenameWithoutExtension(entity.path);
    final resourceName = 'ic_launcher_${toolId.replaceAll('-', '_')}';

    final decoded = img.decodePng(await entity.readAsBytes());
    if (decoded == null) {
      print('  Skipped (not a valid PNG): ${entity.path}');
      continue;
    }

    for (final entry in _legacyIconSizes.entries) {
      final resized = img.copyResize(
        decoded,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic,
      );
      final destDir = Directory(p.join(resDir.path, 'mipmap-${entry.key}'));
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final destFile = File(p.join(destDir.path, '$resourceName.png'));
      await destFile.writeAsBytes(img.encodePng(resized));
    }

    for (final entry in _adaptiveForegroundSizes.entries) {
      final foreground = img.copyResize(
        decoded,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic,
      );
      final destDir = Directory(p.join(resDir.path, 'drawable-${entry.key}'));
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final destFile = File(
        p.join(destDir.path, '${resourceName}_foreground.png'),
      );
      await destFile.writeAsBytes(img.encodePng(foreground));
    }

    final adaptiveIconDir = Directory(p.join(resDir.path, 'mipmap-anydpi-v26'));
    if (!await adaptiveIconDir.exists()) {
      await adaptiveIconDir.create(recursive: true);
    }
    final adaptiveIcon = File(
      p.join(adaptiveIconDir.path, '$resourceName.xml'),
    );
    await adaptiveIcon.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_tool_launcher_background" />
  <foreground>
    <inset
        android:drawable="@drawable/${resourceName}_foreground"
        android:inset="16%" />
  </foreground>
</adaptive-icon>
''');
    synced++;
    print(
      '  Synced $toolId -> $resourceName (${_legacyIconSizes.length} densities)',
    );
  }

  print('\nDone. Synced $synced tool icon(s) into res/mipmap-*.');
}
