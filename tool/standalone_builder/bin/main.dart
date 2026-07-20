// ignore_for_file: avoid_print

import 'dart:io';
import '../src/tools_scanner.dart';
import '../src/config_patcher.dart';
import '../src/builder.dart';
import '../src/tui/tui.dart';

void main(List<String> args) async {
  // Catch Ctrl+C at the OS level to ensure we restore the repository configuration and terminal echo
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\n\nBuild interrupted by user. Cleaning up...');

    // Restore patched files
    await ConfigPatcher.restoreGlobal();
    final mainFile = File('lib/main_standalone.dart');
    if (await mainFile.exists()) {
      await mainFile.delete();
    }

    // Restore terminal: clear any open menu block, show cursor, re-enable
    // line/echo mode.
    stdout.write('\x1B[J\x1B[?25h');
    try {
      stdin.lineMode = true;
      stdin.echoMode = true;
    } catch (_) {}

    print('Cleanup complete. Exiting.');
    exit(0);
  });

  // Handle restore command
  if (args.isNotEmpty && (args[0] == '--restore' || args[0] == '-r')) {
    await ConfigPatcher.restoreGlobal();
    final mainFile = File('lib/main_standalone.dart');
    if (await mainFile.exists()) {
      await mainFile.delete();
      print('Deleted temporary main_standalone.dart');
    }
    exit(0);
  }

  // 1. Scan available tools
  final tools = await ToolsScanner.scan();
  if (tools.isEmpty) {
    print('Error: No tools found in lib/tools/.');
    exit(1);
  }

  // Check for existing backup safety issue
  if (await ConfigPatcher.hasBackup()) {
    print(
      '\x1B[33m⚠️ Warning: Pending configuration backups detected on disk.\x1B[0m',
    );
    print('This usually means a previous build was interrupted prematurely.');
    print('');
    final restoreChoice = await TerminalMenu.select(
      prompt: 'What would you like to do?',
      options: [
        'Restore original repository configs first (Recommended)',
        'Ignore and continue (Warning: may overwrite original backup files)',
      ],
    );
    if (restoreChoice == 0) {
      await ConfigPatcher.restoreGlobal();
      final mainFile = File('lib/main_standalone.dart');
      if (await mainFile.exists()) {
        await mainFile.delete();
      }
      print('Repository restored. Re-starting builder...\n');
    }
  }

  ToolInfo? selectedTool;
  String? selectedPlatform;

  // 2. Parse arguments or run interactive menu
  if (args.isEmpty) {
    // Run interactive menu in clack-style
    final toolOptions = [
      '↩ Restore Backups / Revert Workspace Changes',
      ...tools.map((t) => '${t.displayName} (${t.id})'),
      '✕ Exit',
    ];
    final exitIndex = toolOptions.length - 1;
    final toolIdx = await TerminalMenu.select(
      prompt: 'Select a tool to build standalone',
      options: toolOptions,
    );

    if (toolIdx == null || toolIdx == exitIndex) {
      print('Exiting.');
      exit(0);
    }

    if (toolIdx == 0) {
      print('Restoring backed up configuration files...');
      await ConfigPatcher.restoreGlobal();
      final mainFile = File('lib/main_standalone.dart');
      if (await mainFile.exists()) {
        await mainFile.delete();
      }
      print('Workspace cleaned successfully.');
      exit(0);
    }

    selectedTool = tools[toolIdx - 1];

    // Platform selection menu
    final platformOptions = [
      'Android (APK/AAB)',
      'Windows (Desktop)',
      'Linux (Desktop)',
    ];
    final platformIdx = await TerminalMenu.select(
      prompt: 'Select target platform',
      options: platformOptions,
    );

    if (platformIdx == null) {
      print('Build cancelled.');
      exit(0);
    }

    final mainPlatform = ['android', 'windows', 'linux'][platformIdx];

    if (mainPlatform == 'android') {
      final flavorOptions = [
        'Universal APK (Single file for all devices)',
        'Split APKs (Individual file per architecture, smaller size)',
        'Arm64-v8a Split APK (Only arm64 architectures, smallest size)',
        'App Bundle (AAB for Google Play Store upload)',
      ];
      final flavorIdx = await TerminalMenu.select(
        prompt: 'Select Android build flavor',
        options: flavorOptions,
      );
      if (flavorIdx == null) {
        print('Build cancelled.');
        exit(0);
      }
      selectedPlatform = [
        'android-apk',
        'android-split',
        'android-arm64',
        'android-bundle',
      ][flavorIdx];
    } else {
      selectedPlatform = mainPlatform;
    }
  } else {
    // Direct command-line arguments mode
    final targetId = args[0].replaceAll('_', '-');
    selectedTool = tools.firstWhere(
      (t) => t.id == targetId,
      orElse: () {
        print('Error: Tool "$targetId" not found.');
        print('');
        _printUsage(tools);
        exit(1);
      },
    );

    selectedPlatform = 'android';
    if (args.length > 1) {
      final argPlatform = args[1].toLowerCase();
      final validPlatforms = [
        'android',
        'android-apk',
        'android-split',
        'android-arm64',
        'android-bundle',
        'windows',
        'linux',
      ];
      if (validPlatforms.contains(argPlatform)) {
        selectedPlatform = argPlatform;
      } else {
        print(
          'Warning: Unknown platform "$argPlatform". Defaulting to "android".',
        );
      }
    }
  }

  print('\n==================================================');
  print('Extracting Standalone App for: ${selectedTool.displayName}');
  print('Tool ID:                       ${selectedTool.id}');
  print('Target Platform:               $selectedPlatform');
  print('==================================================');
  print('Note: If you cancel the build prematurely (Ctrl+C), run:');
  print('      dart run tool/build_standalone.dart --restore');
  print('==================================================\n');

  // 3. Perform the build
  final builder = StandaloneBuilder(
    tool: selectedTool,
    platform: selectedPlatform,
  );
  final success = await builder.build();

  // Ensure terminal settings are fully restored before exiting the process
  try {
    stdin.lineMode = true;
    stdin.echoMode = true;
  } catch (_) {}

  if (success) {
    exit(0);
  } else {
    exit(1);
  }
}

void _printUsage(List<ToolInfo> tools) {
  print('Usage: dart run tool/build_standalone.dart <tool-id> [target]');
  print('       dart run tool/build_standalone.dart --restore');
  print('');
  print('Targets:');
  print('  - android-apk               Universal Android APK (default)');
  print('  - android-split             Split APKs per ABI');
  print('  - android-arm64             arm64-v8a Split APK only');
  print('  - android-bundle            Android App Bundle (AAB)');
  print('  - windows                   Windows Desktop');
  print('  - linux                     Linux Desktop');
  print('');
  print('Or run without parameters for interactive menu.');
  print('');
  print('Available Tools:');
  for (final tool in tools) {
    print('  - ${tool.id.padRight(25)} (${tool.displayName})');
  }
}
