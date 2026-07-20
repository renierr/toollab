// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;
import 'tools_scanner.dart';
import 'config_patcher.dart';
import 'tui/tui.dart' show Tui;

class StandaloneBuilder {
  final ToolInfo tool;
  final String platform;

  StandaloneBuilder({required this.tool, required this.platform});

  File get _mainStandaloneFile => File('lib/main_standalone.dart');

  Future<bool> build() async {
    final patcher = ConfigPatcher(tool: tool, platform: platform);

    try {
      print('[0/3] Clearing build cache...');
      await _cleanBuildDir();

      print(
        '\n[1/3] Generating temporary entry point (lib/main_standalone.dart)...',
      );
      await _mainStandaloneFile.writeAsString(_generateEntryPoint());

      print('[2/3] Patching configuration files...');
      await patcher.patch();

      print('Scanning used dependencies...');
      final scanResult = _findUsedPackages(_mainStandaloneFile.path);
      final usedPackages = scanResult.packages;
      final usedAssets = _findUsedAssets(scanResult.visitedFiles);

      print('Used packages: ${usedPackages.join(', ')}');
      print('Used assets: ${usedAssets.join(', ')}');

      if (platform.startsWith('android')) {
        await Tui.task(
          'Generating pruned standalone AndroidManifest',
          () => patcher.generateAndroidManifest(usedPackages),
        );
      }

      await patcher.patchPubspec(usedPackages, usedAssets);

      print('[3/3] Running flutter build $platform...');
      final buildArgs = [
        'build',
        _getFlutterPlatformCommand(),
        '--target=lib/main_standalone.dart',
        '--release',
        ..._getExtraBuildArgs(),
      ];

      final process = await Process.start(
        'flutter',
        buildArgs,
        runInShell: true,
      );

      // Pipe process stdout and stderr directly to console
      final stdoutStream = process.stdout.listen((data) => stdout.add(data));
      final stderrStream = process.stderr.listen((data) => stderr.add(data));

      final exitCode = await process.exitCode;

      // Wait for streams to flush
      await stdoutStream.cancel();
      await stderrStream.cancel();

      if (exitCode == 0) {
        final version = await _getVersion();
        final versionSuffix = version.isNotEmpty ? '-v$version' : '';
        final distDir = Directory('dist');
        if (!await distDir.exists()) {
          await distDir.create(recursive: true);
        }

        String finalPath = '';
        if (platform.startsWith('android')) {
          if (platform == 'android' || platform == 'android-apk') {
            final srcFile = File(
              'build/app/outputs/flutter-apk/app-release.apk',
            );
            final destFile = File('dist/${tool.id}$versionSuffix-release.apk');
            if (await srcFile.exists()) {
              await srcFile.copy(destFile.path);
              finalPath = destFile.path;
            }
          } else if (platform == 'android-split') {
            final srcDir = Directory('build/app/outputs/flutter-apk');
            final List<String> copiedPaths = [];
            if (await srcDir.exists()) {
              await for (final file in srcDir.list()) {
                final name = p.basename(file.path);
                if (file is File &&
                    name.startsWith('app-') &&
                    name.endsWith('-release.apk')) {
                  if (name == 'app-release.apk') continue;
                  final target = name
                      .replaceFirst('app-', '')
                      .replaceFirst('-release.apk', '');
                  final destFile = File(
                    'dist/${tool.id}$versionSuffix-$target-release.apk',
                  );
                  await file.copy(destFile.path);
                  copiedPaths.add(destFile.path);
                }
              }
            }
            finalPath = copiedPaths.join(', ');
          } else if (platform == 'android-arm64') {
            final srcFile = File(
              'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
            );
            final destFile = File(
              'dist/${tool.id}$versionSuffix-arm64-v8a-release.apk',
            );
            if (await srcFile.exists()) {
              await srcFile.copy(destFile.path);
              finalPath = destFile.path;
            }
          } else if (platform == 'android-bundle') {
            final srcFile = File(
              'build/app/outputs/bundle/release/app-release.aab',
            );
            final destFile = File('dist/${tool.id}$versionSuffix-release.aab');
            if (await srcFile.exists()) {
              await srcFile.copy(destFile.path);
              finalPath = destFile.path;
            }
          }
        } else if (platform == 'windows') {
          final srcDir = Directory('build/windows/x64/runner/Release');
          final destDir = Directory(
            'dist/${tool.folderName}$versionSuffix-windows',
          );
          if (await srcDir.exists()) {
            if (await destDir.exists()) {
              await destDir.delete(recursive: true);
            }
            await _copyDirectory(srcDir, destDir);
            finalPath = destDir.path;
          }
        } else if (platform == 'linux') {
          final srcDir = Directory('build/linux/x64/release/bundle');
          final destDir = Directory(
            'dist/${tool.folderName}$versionSuffix-linux',
          );
          if (await srcDir.exists()) {
            if (await destDir.exists()) {
              await destDir.delete(recursive: true);
            }
            await _copyDirectory(srcDir, destDir);
            finalPath = destDir.path;
          }
        }

        stdout.write('\n');
        Tui.success('BUILD SUCCESSFUL!');
        Tui.info('Saved standalone build to: $finalPath');
        return true;
      } else {
        stdout.write('\n');
        Tui.error('Build failed with exit code $exitCode');
        return false;
      }
    } catch (e) {
      Tui.error('An error occurred during compilation: $e');
      return false;
    } finally {
      print('\nCleaning up configuration files...');
      // 1. Delete generated main file
      if (await _mainStandaloneFile.exists()) {
        await _mainStandaloneFile.delete();
      }
      // 2. Restore patched configurations
      await ConfigPatcher.restoreGlobal();
      // 3. Clear build cache again so the main app compiles freshly
      await _cleanBuildDir();
      print('Cleanup complete.');
    }
  }

  Future<void> _cleanBuildDir() async {
    final buildDir = Directory('build');
    if (await buildDir.exists()) {
      try {
        await buildDir.delete(recursive: true);
      } catch (e) {
        print('Warning: Failed to clear build directory: $e');
      }
    }
  }

  String _getFlutterPlatformCommand() {
    if (platform == 'android' ||
        platform == 'android-apk' ||
        platform == 'android-split' ||
        platform == 'android-arm64') {
      return 'apk';
    }
    if (platform == 'android-bundle') {
      return 'appbundle';
    }
    return platform; // 'windows' or 'linux'
  }

  List<String> _getExtraBuildArgs() {
    if (platform == 'android-split') {
      return ['--split-per-abi'];
    }
    if (platform == 'android-arm64') {
      return ['--target-platform', 'android-arm64', '--split-per-abi'];
    }
    return [];
  }

  Future<String> _getVersion() async {
    try {
      final file = File('pubspec.yaml');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.startsWith('version:')) {
            final ver = line.replaceFirst('version:', '').trim();
            return ver.replaceAll('+', '_'); // e.g. 1.6.1_36
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(
          p.join(destination.path, p.basename(entity.path)),
        );
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  String _generateEntryPoint() {
    return '''// GENERATED FILE - DO NOT MODIFY OR COMMIT
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/core/app_mode.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/pages/standalone_settings_page.dart';
import 'package:tool_lab/pages/appearance_settings_page.dart';
import 'package:tool_lab/pages/maintenance_page.dart';
import 'package:tool_lab/pages/sync_settings_page.dart';
import 'package:tool_lab/pages/about_page.dart';
import 'package:tool_lab/tools/${tool.folderName}/config.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  isStandaloneMode = true;
  await TempFileManager.init();
  SharingService.startupArgs = args;
  await DatabaseService.instance.database;
  final settingsService = await SettingsService.init();

  final toolProviders = ${tool.className}.config.stateProviders?.call() ?? [];

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(settingsService)),
        ...toolProviders,
      ],
      child: const StandaloneAppWrapper(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => ${tool.className}.config.createPage(state.extra as SharedData?),
    ),
    GoRoute(
      path: '/standalone-settings',
      builder: (context, state) => const StandaloneSettingsPage(),
    ),
    GoRoute(
      path: '/appearance-settings',
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: '/maintenance',
      builder: (context, state) => const MaintenancePage(),
    ),
    GoRoute(
      path: '/sync-settings',
      builder: (context, state) => const SyncSettingsPage(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutPage(),
    ),
  ],
  errorBuilder: (context, state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route \${state.uri.path} is not available in standalone mode.')),
      );
    });
    return ${tool.className}.config.createPage(null);
  },
);

class StandaloneAppWrapper extends StatefulWidget {
  const StandaloneAppWrapper({super.key});

  @override
  State<StandaloneAppWrapper> createState() => _StandaloneAppWrapperState();
}

class _StandaloneAppWrapperState extends State<StandaloneAppWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<SharedData>? _sharingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSharing();
  }

  Future<void> _initSharing() async {
    await _checkPending();
    _sharingSubscription =
        SharingService.instance.onSharedData.listen((data) {
      if (mounted && !data.isEmpty) _openWithData(data);
    });
  }

  Future<void> _checkPending() async {
    final initial = await SharingService.instance.getInitialSharedData();
    if (initial != null && !initial.isEmpty) _openWithData(initial);
  }

  Future<void> _openWithData(SharedData data) async {
    await SharingService.instance.clearSharedData();
    if (mounted) _router.go('/', extra: data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPending();
    } else if (state == AppLifecycleState.detached) {
      TempFileManager.cleanSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp.router(
      scrollBehavior: const AppScrollBehavior(),
      title: ${tool.className}.config.name,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appState.themeMode,
      locale: appState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
''';
  }

  ScanResult _findUsedPackages(String entryPoint) {
    final visited = <String>{};
    final packages = <String>{};

    void visit(String filePath) {
      if (visited.contains(filePath)) return;
      visited.add(filePath);

      final file = File(filePath);
      if (!file.existsSync()) return;

      try {
        final content = file.readAsStringSync();
        final imports = RegExp(
          r"import\s+['\x22]([^'\x22]+)['\x22]",
        ).allMatches(content);

        for (final match in imports) {
          final importPath = match.group(1)!;
          if (importPath.startsWith('package:')) {
            final parts = importPath.substring(8).split('/');
            final pkg = parts[0];
            if (pkg == 'tool_lab') {
              final localPath = importPath.replaceFirst(
                'package:tool_lab/',
                'lib/',
              );
              visit(localPath);
            } else if (pkg != 'flutter') {
              packages.add(pkg);
            }
          } else if (!importPath.startsWith('dart:')) {
            final dir = p.dirname(filePath);
            final relativePath = p.normalize(p.join(dir, importPath));
            visit(relativePath);
          }
        }
      } catch (_) {}
    }

    visit(entryPoint);
    return ScanResult(packages, visited);
  }

  Set<String> _findUsedAssets(Set<String> visitedFiles) {
    final usedAssets = <String>{};
    final assetPatterns = {
      'assets/audio/': 'assets/audio/',
      'assets/google_fonts/': 'assets/google_fonts/',
      'assets/grammars/': 'assets/grammars/',
      'assets/logo/': 'assets/logo/',
    };

    for (final filePath in visitedFiles) {
      final file = File(filePath);
      if (!file.existsSync()) continue;

      try {
        final content = file.readAsStringSync();
        for (final pattern in assetPatterns.keys) {
          if (content.contains(pattern)) {
            usedAssets.add(assetPatterns[pattern]!);
          }
        }
      } catch (_) {}
    }

    return usedAssets;
  }
}

class ScanResult {
  final Set<String> packages;
  final Set<String> visitedFiles;

  ScanResult(this.packages, this.visitedFiles);
}
