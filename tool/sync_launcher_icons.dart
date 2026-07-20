// ignore_for_file: avoid_print

// Syncs the per-tool launcher icons used by the app-drawer activity-aliases
// and home-screen pinned shortcuts.
//
// Source of truth: `assets/logo/standalone/<tool-id>.png` (square, ideally
// 512x512). This script downscales each one into every Android density bucket
// and writes `res/mipmap-<density>/ic_launcher_<tool_id>.png` (hyphens in the
// tool id become underscores to form a valid resource name).
//
// Run after adding or changing any icon under assets/logo/standalone/:
//   dart run tool/sync_launcher_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

// Legacy launcher icon edge lengths per density bucket (px).
const Map<String, int> _densitySizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
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

    for (final entry in _densitySizes.entries) {
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
    synced++;
    print(
      '  Synced $toolId -> $resourceName (${_densitySizes.length} densities)',
    );
  }

  print('\nDone. Synced $synced tool icon(s) into res/mipmap-*.');
}
