import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_model.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_p2p_state.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_state.dart';
import 'package:tool_lab/tools/fast_drop/p2p/p2p_models.dart';
import 'package:tool_lab/tools/fast_drop/p2p/p2p_protocol.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_cloud_view.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_edit_description_dialog.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_incoming_request_dialog.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_p2p_view.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_preview_dialog.dart';
import 'package:tool_lab/tools/fast_drop/widgets/fast_drop_upload_panel.dart';
import 'package:tool_lab/tools/fast_drop/widgets/retention_selector.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

class _AppState extends ChangeNotifier implements AppState {
  _AppState({this.tvMode = false});

  @override
  final bool tvMode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FastDropState extends ChangeNotifier implements FastDropState {
  _FastDropState(this.fastDrops);

  @override
  final List<FastDropItem> fastDrops;

  @override
  bool get isLoadingFastDrops => false;

  @override
  String? get fastDropError => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _P2pState extends ChangeNotifier implements FastDropP2pState {
  @override
  P2pRole role = P2pRole.receiving;
  @override
  (int, int)? progress;
  @override
  bool isTransferActive = false;
  @override
  List<P2pReceivedFile> receivedFiles = [];

  @override
  P2pTransportKind? get activeTransport => P2pTransportKind.lan;
  @override
  P2pErrorCode? get errorCode => null;
  @override
  String? get error => null;
  @override
  bool get hasPendingSendFile => false;
  @override
  List<P2pPeer> get peers => const [];

  void update() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FastDropItem _item(String id, {String type = 'image/png'}) => FastDropItem(
  id: id,
  filename: '$id.png',
  size: 1024,
  type: type,
  source: 'upload',
  uploadedAt: 0,
  expiresAt: 3600000,
);

P2pReceivedFile _received(String id) => P2pReceivedFile(
  id: id,
  filename: '$id.bin',
  size: 10,
  mimeType: 'application/octet-stream',
  tempFileName: id,
  tempFileBaseName: id,
  receivedAt: 0,
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool tvMode = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>(
      create: (_) => _AppState(tvMode: tvMode),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) =>
            TvNavigationScope(enabled: tvMode, child: child!),
        home: home,
      ),
    ),
  );
  settle ? await tester.pumpAndSettle() : await _frames(tester);
}

// A spinner never settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

bool _isAncestor(Element ancestor, Element child) {
  var found = false;
  child.visitAncestorElements((e) {
    found = e == ancestor;
    return !found;
  });
  return found;
}

/// Focus sits inside [finder]'s widget, or on the control wrapping it.
bool _focusInside(WidgetTester tester, Finder finder) {
  final target = tester.element(finder);
  final focused = FocusManager.instance.primaryFocus?.context as Element?;
  if (focused == null) return false;
  return focused == target ||
      _isAncestor(target, focused) ||
      _isAncestor(focused, target);
}

String? _focusedTooltip() {
  String? tooltip;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    final widget = e.widget;
    if (widget is Tooltip) {
      tooltip = widget.message;
      return false;
    }
    return true;
  });
  return tooltip;
}

Widget _dialogOpener(WidgetBuilder dialog, ValueSetter<Object?> onResult) =>
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => onResult(
              await showDialog<Object?>(context: context, builder: dialog),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('incoming request dialog focuses Accept so OK accepts', (
    tester,
  ) async {
    Object? result;
    await _pump(
      tester,
      _dialogOpener(
        (_) => const FastDropIncomingRequestDialog(
          senderName: 'Phone',
          request: P2pHandshakeRequest(
            senderName: 'Phone',
            candidateIps: [],
            lanPort: 0,
            fileName: 'a.txt',
            fileSize: 1,
            mimeType: 'text/plain',
          ),
        ),
        (r) => result = r,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(_focusInside(tester, find.byType(FilledButton)), isTrue);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(result, isTrue);
  });

  group('cloud view side by side', () {
    late _FastDropState state;
    final scope = TempFileManager.createScope();

    Future<void> pumpCloud(WidgetTester tester, {bool tvMode = true}) async {
      state = _FastDropState([_item('a'), _item('b'), _item('c')]);
      await _pump(
        tester,
        Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'header',
                onPressed: () {},
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: FastDropCloudView(
            fastDropState: state,
            pendingFiles: const [],
            isUploadingPending: false,
            isActionsEnabled: true,
            onUploadPending: () {},
            onDismissPending: () {},
            retention: '24',
            onRetentionChanged: (_) {},
            onFilesSelected: (_) {},
            onPasteClipboard: () {},
            tempScope: scope,
            onDelete: (_) {},
            onPreview: (_) {},
            onOpen: (_) {},
            onDownload: (_) {},
            onEditDescription: (_) {},
            onEditRetention: (_) {},
          ),
        ),
        tvMode: tvMode,
      );
    }

    for (final tvMode in [true, false]) {
      testWidgets('${tvMode ? 'TV' : 'keyboard'}: down walks a card down '
          'to its own action row', (tester) async {
        await pumpCloud(tester, tvMode: tvMode);
        Focus.of(
          tester.element(find.text('Add description...').first),
        ).requestFocus();
        await tester.pumpAndSettle();

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focusedTooltip(), 'Preview');

        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(
          _focusInside(tester, find.text('Add description...').first),
          isTrue,
        );
      });
    }

    testWidgets('down from the paste button stays in the upload panel', (
      tester,
    ) async {
      await pumpCloud(tester);
      final paste = find.text('Paste Clipboard');
      Focus.of(tester.element(paste)).requestFocus();
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusInside(tester, find.byType(FastDropUploadPanel)), isTrue);
    });

    testWidgets('right crosses from the upload panel into the list and '
        'up from the panel top reaches the app bar', (tester) async {
      await pumpCloud(tester);
      final chip = find.byType(ChoiceChip).first;
      Focus.of(tester.element(find.text('1 hr'))).requestFocus();
      await tester.pumpAndSettle();
      expect(_focusInside(tester, chip), isTrue);

      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedTooltip(), 'header');

      Focus.of(tester.element(find.text('Paste Clipboard'))).requestFocus();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusInside(tester, find.byType(ListView)), isTrue);
    });
  });

  testWidgets('offline upload panel keeps the remote off Browse Files', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: FastDropUploadPanel(
            retention: '24',
            onRetentionChanged: (_) {},
            onFilesSelected: (_) {},
            onPasteClipboard: () {},
            isActionsEnabled: false,
            tempScope: TempFileManager.createScope(),
            shortViewport: true,
          ),
        ),
      ),
    );
    final browse = find.text('Browse Files');
    expect(browse, findsOneWidget);
    expect(Focus.of(tester.element(browse)).canRequestFocus, isFalse);
  });

  for (final tvMode in [true, false]) {
    testWidgets('${tvMode ? 'TV' : 'desktop'}: edit description '
        '${tvMode ? 'does not open the keyboard' : 'focuses the field'}', (
      tester,
    ) async {
      await _pump(
        tester,
        _dialogOpener(
          (_) => const FastDropEditDescriptionDialog(currentDescription: 'x'),
          (_) {},
        ),
        tvMode: tvMode,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(_focusInside(tester, find.byType(EditableText)), !tvMode);
      if (tvMode) {
        expect(_focusInside(tester, find.byType(FilledButton)), isTrue);
      }
    });
  }

  testWidgets('retention selector is localized', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: RetentionSelector(selectedValue: '24', onChanged: (_) {}),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RetentionSelector)),
    );
    expect(find.text(l10n.fastDropRetentionPeriod), findsOneWidget);
    expect(find.text(l10n.fastDropRetentionIndefinite), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: RetentionSelector(selectedValue: '24', onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retention Period'), findsNothing);
  });

  testWidgets('preview dialog long text scrolls with down on TV', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('fast_drop_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => tmp.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final text = List.generate(200, (i) => 'line $i').join('\n');
    await _pump(
      tester,
      _dialogOpener(
        (_) => FastDropPreviewDialog(
          item: _item('t', type: 'text/plain'),
          onDownloadToFile: (id, path) async {
            await File(path).writeAsString(text);
            return path;
          },
          onOpen: () {},
          onSave: () {},
        ),
        (_) {},
      ),
    );
    await tester.tap(find.text('open'));
    for (
      var i = 0;
      i < 40 && find.textContaining('line 199').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('line 199'), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byType(FastDropPreviewDialog),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable.first).position;
    expect(position.pixels, 0);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(position.pixels, greaterThan(0));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(position.pixels, greaterThan(0));
  });

  group('p2p receive toggle', () {
    Future<_P2pState> pumpP2p(WidgetTester tester) async {
      final p2p = _P2pState();
      await _pump(
        tester,
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'home',
              onPressed: () {},
              icon: const Icon(Icons.home),
            ),
          ),
          body: ListenableBuilder(
            listenable: p2p,
            builder: (context, _) => FastDropP2pView(
              p2pState: p2p,
              tempScope: TempFileManager.createScope(),
              onFilesPickedToSend: (_) {},
              onPasteClipboardToSend: () {},
              onSelectPeer: (_) {},
              onCancelSendSelection: () {},
              onToggleReceiving: () {},
              onOpenReceived: (_) {},
              onSaveReceived: (_) {},
              onCancelTransfer: () {},
            ),
          ),
        ),
        settle: false,
      );
      Focus.of(tester.element(find.text('Stop Receiving'))).requestFocus();
      await _frames(tester);
      return p2p;
    }

    testWidgets('a transfer keeps focus off Home and ends on the received '
        'file', (tester) async {
      final p2p = await pumpP2p(tester);

      p2p
        ..isTransferActive = true
        ..update();
      await _frames(tester);
      p2p
        ..progress = (0, 10)
        ..update();
      await _frames(tester);
      expect(_focusedTooltip(), 'Cancel');

      p2p
        ..isTransferActive = false
        ..progress = null
        ..receivedFiles = [_received('r1')]
        ..update();
      await _frames(tester);
      expect(_focusedTooltip(), 'Open');
    });

    testWidgets('a failed transfer returns focus to the toggle', (
      tester,
    ) async {
      final p2p = await pumpP2p(tester);
      p2p
        ..isTransferActive = true
        ..progress = (0, 10)
        ..update();
      await _frames(tester);
      p2p
        ..isTransferActive = false
        ..progress = null
        ..update();
      await _frames(tester);
      expect(_focusInside(tester, find.text('Stop Receiving')), isTrue);
    });
  });
}
