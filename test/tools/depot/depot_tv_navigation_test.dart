import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/widgets/depot_details_link_settings.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_search_field.dart';
import 'package:tool_lab/tools/depot/widgets/depot_section_scroll_view.dart';
import 'package:tool_lab/tools/depot/widgets/depot_tabs.dart';
import 'package:tool_lab/tools/depot/widgets/depot_tax_settings.dart';
import 'package:tool_lab/widgets/tool_chip.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

import 'offline_test_support.dart';

class _AppState extends ChangeNotifier implements AppState {
  @override
  bool get tvMode => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _holding = DepotHolding(
  id: 'h',
  portfolioId: 'p',
  name: 'Example holding',
  assetType: DepotAssetType.security,
  shares: 1,
  purchasePrice: 1,
  purchaseValue: 1,
  currentPrice: 1,
  currentValue: 1,
  isSold: false,
  unrealizedGain: 0,
  unrealizedReturn: 0,
  realizedGain: 0,
  dividends: 0,
  fees: 0,
  taxes: 0,
);

Future<void> _pumpTv(
  WidgetTester tester,
  Widget home, {
  List<ChangeNotifierProvider> providers = const [],
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _AppState()),
        ...providers,
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            TvNavigationScope(enabled: true, child: child!),
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _focusInside(WidgetTester tester, Finder finder) {
  final target = tester.element(finder);
  var inside = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    inside = e == target;
    return !inside;
  });
  return inside;
}

Finder _segment(IconData icon) =>
    find.ancestor(of: find.byIcon(icon), matching: find.byType(TextButton));

void main() {
  blockDepotNetwork();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    FlutterSecureStorage.setMockInitialValues({});
    await DepotStore.instance.clear();
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  testWidgets('TV: text fields open the keyboard on OK, not on focus', (
    tester,
  ) async {
    final tabs = await loadedDepotState(tester);
    final portfolio = DepotPortfolioState();
    addTearDown(portfolio.dispose);
    await _pumpTv(
      tester,
      ListView(
        children: [
          DepotSearchField(initialText: '', hint: 'Search', onChanged: (_) {}),
          const DepotTaxSettings(),
          const DepotDetailsLinkSettings(),
        ],
      ),
      providers: [
        ChangeNotifierProvider<DepotState>.value(value: tabs),
        ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
      ],
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(7));
    for (var i = 0; i < 7; i++) {
      final field = tester.widget<TextField>(fields.at(i));
      expect(field.readOnly, isTrue, reason: 'field $i');
    }

    tester.widget<TextField>(fields.first).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(fields.first).readOnly, isFalse);
  });

  testWidgets('TV: the selected tab takes focus and Down reaches the active '
      'jump chip', (tester) async {
    final tabs = await loadedDepotState(tester);
    tabs.setTab(DepotTab.dividends);
    await _pumpTv(
      tester,
      Column(
        children: [
          const DepotTabs(),
          Expanded(
            child: DepotSectionScrollView<int>(
              onRefresh: () async {},
              sections: [
                for (var i = 0; i < 3; i++)
                  DepotSection(
                    id: i,
                    label: 'Section $i',
                    icon: Icons.circle,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 300,
                        child: TextButton(
                          onPressed: () {},
                          child: Text('Body $i'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      providers: [ChangeNotifierProvider<DepotState>.value(value: tabs)],
    );

    expect(_focusInside(tester, _segment(Icons.payments_outlined)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final chip = find.ancestor(
      of: find.text('Section 0'),
      matching: find.byType(ToolChip),
    );
    expect(_focusInside(tester, chip), isTrue);
  });

  testWidgets('custom sort offers move up and move down in the expanded '
      'holding', (tester) async {
    final moves = <int>[];
    final tabs = await loadedDepotState(tester);
    final logos = DepotLogoState();
    final trends = DepotHoldingTrendState();
    addTearDown(logos.dispose);
    addTearDown(trends.dispose);
    await tester.runAsync(logos.ensureLoaded);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tabs),
          ChangeNotifierProvider.value(value: logos),
          ChangeNotifierProvider.value(value: trends),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                DepotHoldingTile(
                  holding: _holding,
                  performance: null,
                  period: DepotPeriod.today,
                  format: DepotFormat('en', 'EUR'),
                  weight: 100,
                  reorderIndex: 1,
                  onMoveUp: () => moves.add(-1),
                  onMoveDown: () => moves.add(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Example holding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.tap(find.text('Move down'));
    expect(moves, [-1, 1]);
  });
}
