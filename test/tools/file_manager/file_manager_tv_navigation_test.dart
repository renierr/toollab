import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_page.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_tile.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_folder_picker_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_grouped_image_grid.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

const _root = '/fm';
const _loadDelay = Duration(milliseconds: 50);

/// Serves a fixed folder tree without touching the file system or database,
/// and clears the listing while loading like [FileManagerState.openLocal].
class _FakeState extends FileManagerState {
  final Map<String, List<String>> tree;
  String _current = _root;
  bool _loading = false;
  List<FileManagerEntry> _listing = [];
  int _generation = 0;

  _FakeState(this.tree, {this.connections = const []});

  @override
  final List<FileManagerConnection> connections;

  @override
  String get path => _current;
  @override
  List<FileManagerEntry> get entries => _listing;
  @override
  bool get isLoading => _loading;
  @override
  int get listingGeneration => _generation;
  @override
  bool get canGoUp => _current != _root;
  @override
  bool get canNavigateBack => canGoUp;
  @override
  String get defaultFolderPath => _root;

  @override
  Future<void> initialize() => openLocal(_root);

  @override
  Future<void> openLocal(String directory) async {
    _current = directory;
    _loading = true;
    _listing = [];
    final generation = ++_generation;
    notifyListeners();
    await Future<void>.delayed(_loadDelay);
    if (generation != _generation) return;
    _listing = [
      for (final name in tree[directory] ?? const <String>[])
        FileManagerEntry(
          name: name,
          path: p.posix.join(directory, name),
          isDirectory: true,
        ),
    ];
    _loading = false;
    notifyListeners();
  }

  @override
  Future<void> openPath(String path) => openLocal(path);
  @override
  Future<void> openEntry(FileManagerEntry entry) => openLocal(entry.path);
  @override
  Future<void> goUp() => openLocal(p.posix.dirname(_current));
  @override
  Future<void> refresh() => openLocal(_current);

  @override
  ValueListenable<FileStat?> metadataFor(FileManagerEntry entry) =>
      ValueNotifier(null);
  @override
  ValueListenable<int?> childCountFor(FileManagerEntry entry) =>
      ValueNotifier(null);
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeState state, {
  bool tvMode = true,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: _root,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: _root, builder: (_, _) => const FileManagerPage()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<FileManagerState>.value(
      value: state,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) =>
            TvNavigationScope(enabled: tvMode, child: child!),
        routerConfig: router,
      ),
    ),
  );
  // The page initializes the state after a short delay.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump(_loadDelay * 2);
  await tester.pumpAndSettle();
}

/// Name of the entry whose row (or trailing button with [trailing]) has focus.
String? _focusedEntry(WidgetTester tester, {bool trailing = false}) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final tile = context.findAncestorWidgetOfExactType<FileManagerEntryTile>();
  if (tile == null) return null;
  final inRow = context.findAncestorWidgetOfExactType<ListTile>() != null;
  return inRow != trailing ? tile.entry.name : null;
}

String? _focusedTooltip() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<IconButton>()?.tooltip;
}

void _focusRow(WidgetTester tester, String name) =>
    Focus.of(tester.element(find.text(name))).requestFocus();

void main() {
  final tree = {
    _root: ['a', 'b', 'c'],
    '$_root/a': ['a1'],
    '$_root/b': ['b1', 'b2'],
    '$_root/c': <String>[],
  };

  testWidgets('opening a folder and going back keeps the focus in the list', (
    tester,
  ) async {
    await _pumpPage(tester, _FakeState(tree));
    _focusRow(tester, 'b');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('b1'), findsOneWidget);
    expect(_focusedEntry(tester), 'b1');

    await tester.binding.handlePopRoute();
    await tester.pump(_loadDelay * 2);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(_focusedEntry(tester), 'b');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedEntry(tester), 'c');
  });

  testWidgets('enter opens a folder with a keyboard on desktop', (
    tester,
  ) async {
    await _pumpPage(tester, _FakeState(tree), tvMode: false);
    _focusRow(tester, 'b');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.enter);
    expect(_focusedEntry(tester), 'b1');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedEntry(tester), 'b2');
  });

  testWidgets('the toolbar stays while a folder loads', (tester) async {
    await _pumpPage(tester, _FakeState(tree));
    _focusRow(tester, 'b');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    await tester.pump(_loadDelay * 2);
    await tester.pumpAndSettle();
  });

  testWidgets('the up button keeps its focus', (tester) async {
    await _pumpPage(tester, _FakeState(tree));
    _focusRow(tester, 'b');
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.select);
    Focus.of(tester.element(find.byIcon(Icons.arrow_upward))).requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('a'), findsOneWidget);
    expect(_focusedTooltip(), 'Back');
  });

  testWidgets('right on the row menu moves to the toolbar actions', (
    tester,
  ) async {
    await _pumpPage(tester, _FakeState(tree));
    _focusRow(tester, 'a');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedEntry(tester, trailing: true), 'a');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedTooltip(), 'Settings');
  });

  testWidgets('down from the last row stays on it', (tester) async {
    final names = [for (var i = 0; i < 3; i++) 'f${i + 10}'];
    await _pumpPage(
      tester,
      _FakeState(
        {_root: names},
        connections: [
          for (var i = 0; i < 4; i++)
            FileManagerConnection(
              id: '$i',
              label: 'NAS $i',
              protocol: FileManagerProtocol.smb,
              host: 'nas',
              port: 445,
              share: 'share',
              username: '',
              initialPath: '',
            ),
        ],
      ),
    );
    _focusRow(tester, names.first);
    await tester.pumpAndSettle();
    for (var i = 1; i < names.length; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focusedEntry(tester), names.last);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedEntry(tester), names.last);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedEntry(tester, trailing: true), names.last);
  });

  testWidgets('the image group collapse toggle takes the focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) =>
            TvNavigationScope(enabled: true, child: child!),
        home: Scaffold(
          body: FileManagerGroupedImageGrid(
            groups: const {'/fm/pics': []},
            tileSize: 160,
            selectedPaths: const {},
            isSelectionMode: false,
            onOpen: (_) {},
            onOpenFolder: (_) {},
            onToggleSelection: (_) {},
            crop: true,
            onGridWidth: (_) {},
          ),
        ),
      ),
    );
    Focus.of(
      tester.element(find.byIcon(Icons.folder_open_outlined)),
    ).requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedTooltip(), 'Collapse folder');
    await _press(tester, LogicalKeyboardKey.select);
    expect(_focusedTooltip(), 'Expand folder');
  });

  group('folder picker', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fm_picker_');
      for (final name in ['x', 'y', 'z']) {
        Directory(p.join(temp.path, name, 'inner')).createSync(recursive: true);
      }
    });
    tearDown(() => temp.deleteSync(recursive: true));

    Future<void> settleIo(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    String? focusedFolder() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context?.findAncestorWidgetOfExactType<ListTile>() == null) {
        return null;
      }
      final title = context!.findAncestorWidgetOfExactType<ListTile>()!.title;
      return title is Text ? title.data : null;
    }

    testWidgets('opening and leaving a folder keeps the focus in the list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) =>
              TvNavigationScope(enabled: true, child: child!),
          home: Scaffold(
            body: FileManagerFolderPickerDialog(initialPath: temp.path),
          ),
        ),
      );
      await settleIo(tester);
      Focus.of(tester.element(find.text('y'))).requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settleIo(tester);
      expect(find.text('inner'), findsOneWidget);
      expect(focusedFolder(), 'inner');

      Focus.of(tester.element(find.byIcon(Icons.arrow_upward))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settleIo(tester);
      expect(find.text('x'), findsOneWidget);
      expect(_focusedTooltip(), 'Back');
    });
  });
}
