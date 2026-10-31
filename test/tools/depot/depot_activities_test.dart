import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_activity_export.dart';
import 'package:tool_lab/tools/depot/depot_activity_groups.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_tax_export.dart';
import 'package:tool_lab/tools/depot/models/depot_filters.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/models/depot_year_report.dart';
import 'package:tool_lab/tools/depot/widgets/depot_activities_view.dart';
import 'package:tool_lab/tools/depot/widgets/depot_transaction_tile.dart';

DepotTransaction activity(
  String id,
  DateTime date, {
  DepotTransactionType type = DepotTransactionType.dividend,
  String name = 'Example',
  String currency = 'EUR',
  String? broker,
}) => DepotTransaction(
  id: id,
  portfolioId: 'p',
  holdingId: 'h',
  holdingName: name,
  type: type,
  assetType: DepotAssetType.security,
  datetime: date,
  shares: 1.5,
  price: 2,
  amount: -10,
  amountNet: 8,
  tax: 2,
  fee: 1,
  currency: currency,
  broker: broker,
);

class _Portfolio extends DepotPortfolioState {
  _Portfolio(this.items) {
    filtered = List.of(items);
  }
  final List<DepotTransaction> items;
  late List<DepotTransaction> filtered;
  DepotActivityFilter selected = const DepotActivityFilter();
  @override
  bool get isLoaded => true;
  @override
  bool get isConnected => true;
  @override
  bool get hasData => true;
  @override
  String get currency => 'EUR';
  @override
  List<DepotTransaction> get transactions => items;
  @override
  DepotActivityFilter get activityFilter => selected;
  @override
  List<DepotTransaction> get visibleTransactions => filtered;
  @override
  List<DepotYearReport> get yearReports => const [
    DepotYearReport(
      year: 2026,
      realizedGain: 100,
      dividends: 80,
      interest: 10,
      taxes: 20,
      fees: 5,
      sells: 1,
    ),
  ];
  @override
  DepotYearReport? get yearReport => yearReports.first;
  @override
  void setActivityFilter(DepotActivityFilter filter) {
    selected = filter;
    filtered = items.where(selected.matches).toList();
    notifyListeners();
  }
}

void main() {
  final before = activity('before', DateTime(2026, 3, 9, 23, 59));
  final first = activity('first', DateTime(2026, 3, 10));
  final end = activity('end', DateTime(2026, 3, 20, 23, 59, 59));
  final after = activity('after', DateTime(2026, 3, 21));

  test('inclusive calendar dates compose with type and search filters', () {
    final range = DepotActivityDateRange(
      DateTime(2026, 3, 10, 12),
      DateTime(2026, 3, 20),
    );
    final filter = DepotActivityFilter(
      query: 'example',
      types: {DepotTransactionType.dividend},
      dateRange: range,
    );
    expect([before, first, end, after].where(filter.matches).map((t) => t.id), [
      'first',
      'end',
    ]);
    expect(
      filter.matches(
        activity('buy', DateTime(2026, 3, 15), type: DepotTransactionType.buy),
      ),
      isFalse,
    );
    expect(
      filter.matches(activity('other', DateTime(2026, 3, 15), name: 'Other')),
      isFalse,
    );
    final cleared = filter.copyWith(clearDateRange: true);
    expect(cleared.matches(before), isTrue);
    expect(cleared.query, 'example');
    expect(cleared.types, {DepotTransactionType.dividend});
    expect(
      () =>
          DepotActivityDateRange(DateTime(2026, 3, 21), DateTime(2026, 3, 20)),
      throwsArgumentError,
    );
  });

  test(
    'monthly grouping is newest first, retains each booking and currency',
    () {
      final old = activity('old', DateTime(2025, 12, 31));
      final rows = depotActivityRows([old, end, first, after]);
      expect(rows.whereType<DepotActivityMonth>().map((r) => r.month), [
        DateTime(2026, 3),
        DateTime(2025, 12),
      ]);
      expect(rows.whereType<DepotActivityItem>().map((r) => r.transaction.id), [
        'end',
        'first',
        'after',
        'old',
      ]);
      expect(depotActivityRows([]), isEmpty);
    },
  );

  test(
    'two newest months start open and toggles keep all filtered bookings',
    () {
      final list = [
        activity('march', DateTime(2026, 3)),
        activity('feb', DateTime(2026, 2)),
        activity('jan', DateTime(2026, 1)),
      ];
      final state = _Portfolio(list);
      addTearDown(state.dispose);
      final rows = state.activityRows;
      expect(identical(rows, state.activityRows), isTrue);
      expect(rows.whereType<DepotActivityMonth>().map((m) => m.expanded), [
        true,
        true,
        false,
      ]);
      expect(rows.whereType<DepotActivityItem>().map((r) => r.transaction.id), [
        'march',
        'feb',
      ]);
      state.toggleActivityMonth(DateTime(2026, 1), defaultExpanded: false);
      expect(
        state.activityRows.whereType<DepotActivityItem>().map(
          (r) => r.transaction.id,
        ),
        ['march', 'feb', 'jan'],
      );
      state.toggleActivityMonth(DateTime(2026, 3), defaultExpanded: true);
      expect(
        state.activityRows.whereType<DepotActivityItem>().map(
          (r) => r.transaction.id,
        ),
        ['feb', 'jan'],
      );
      expect(
        utf8.decode(DepotActivityExport.csv(state.visibleTransactions)),
        contains('march'),
      );
      state.setActivityFilter(const DepotActivityFilter(query: 'nomatch'));
      expect(state.activityRows, isEmpty);
    },
  );

  test(
    'filtered export uses exactly matching rows across years with safe CSV values',
    () {
      final old = activity(
        'old',
        DateTime(2025, 12, 31),
        name: '=Formula, "text"',
        currency: 'USD',
        broker: '@broker',
      );
      final latest = activity('latest', DateTime(2026, 1, 1), currency: 'EUR');
      final excluded = activity('excluded', DateTime(2026, 2, 1));
      final filter = DepotActivityFilter(
        dateRange: DepotActivityDateRange(
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 1),
        ),
      );
      final matches = [old, latest, excluded].where(filter.matches).toList();
      final bytes = DepotActivityExport.csv(matches);
      final csv = utf8.decode(bytes);
      expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
      expect(csv, startsWith('date,portfolio_id,activity_id,'));
      expect(csv, contains('"\'=Formula, ""text"""'));
      expect(csv, contains('"\'@broker"'));
      expect(csv, contains('"USD"'));
      expect(csv, contains('"EUR"'));
      expect(csv, contains('"-10.0"'));
      expect(csv, isNot(contains('excluded')));
      expect(csv, contains('2025-12-31'));
      expect(csv, contains('2026-01-01'));
      final annual = utf8.decode(DepotTaxExport.csv(matches, 2026));
      expect(annual, contains('2026-01-01'));
      expect(annual, isNot(contains('2025-12-31')));
    },
  );

  for (final (locale, width, scale) in [
    (const Locale('de'), 320.0, 2.0),
    (const Locale('en'), 1000.0, 1.0),
  ]) {
    testWidgets(
      'activity filters, groups and net labels fit $locale at $width / $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final older = activity('old', DateTime(2025, 12, 31), name: 'Older');
        final current = activity(
          'now',
          DateTime(2026, 3, 10),
          name: 'Example',
          currency: 'USD',
        );
        final portfolio = _Portfolio([current, older]);
        addTearDown(portfolio.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<DepotPortfolioState>.value(
            value: portfolio,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(body: DepotActivitiesView()),
            ),
          ),
        );
        final net = locale.languageCode == 'de' ? '(netto)' : '(net)';
        expect(find.textContaining(net), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'de'
                ? 'Kostenübersicht · nicht erneut abziehen'
                : 'Costs overview · do not subtract again',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            locale.languageCode == 'de' ? 'nicht umgerechnet' : 'not converted',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'initial view');
        final rangeButton = find.text(
          locale.languageCode == 'de' ? 'Zeitraum wählen' : 'Choose dates',
        );
        await tester.scrollUntilVisible(
          rangeButton,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(rangeButton);
        await tester.pumpAndSettle();
        portfolio.setActivityFilter(
          DepotActivityFilter(
            query: 'Example',
            dateRange: DepotActivityDateRange(
              DateTime(2026, 3, 1),
              DateTime(2026, 3, 31),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(rangeButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'date picker');
        expect(find.byType(DatePickerDialog), findsOneWidget);
        final ok = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        ).okButtonLabel;
        await tester.tap(find.text(ok));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.text(ok));
        await tester.pumpAndSettle();
        expect(portfolio.activityFilter.dateRange?.start, DateTime(2026, 3, 1));
        expect(portfolio.activityFilter.dateRange?.end, DateTime(2026, 3, 31));
        expect(portfolio.visibleTransactions.map((t) => t.id), ['now']);
        final clear = find.byTooltip(
          locale.languageCode == 'de'
              ? 'Datumsfilter entfernen'
              : 'Clear date filter',
        );
        await tester.ensureVisible(clear);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(portfolio.activityFilter.query, 'Example');
        expect(portfolio.activityFilter.dateRange, isNull);
        expect(portfolio.visibleTransactions.map((t) => t.id), ['now']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('large activity lists build only visible transaction tiles', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 5000; i++) activity('$i', DateTime(2026, 3, 1)),
      activity('older', DateTime(2025, 1, 1)),
      activity('oldest', DateTime(2024, 1, 1)),
    ];
    final portfolio = _Portfolio(items);
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotPortfolioState>.value(
        value: portfolio,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DepotActivitiesView()),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byType(DepotTransactionTile).evaluate().length, lessThan(40));
    final rows = portfolio.activityRows;
    expect(identical(rows, portfolio.activityRows), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older month expands and newest month collapses', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final portfolio = _Portfolio([
      activity('march', DateTime(2026, 3), name: 'March item'),
      activity('feb', DateTime(2026, 2), name: 'February item'),
      activity('jan', DateTime(2026, 1), name: 'January item'),
    ]);
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotPortfolioState>.value(
        value: portfolio,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DepotActivitiesView()),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('January 2026'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('January item'), findsNothing);
    await tester.ensureVisible(find.text('January 2026'));
    await tester.tap(find.text('January 2026'));
    await tester.pumpAndSettle();
    expect(find.text('January item'), findsOneWidget);
    await tester.ensureVisible(find.text('March 2026'));
    await tester.tap(find.text('March 2026'));
    await tester.pumpAndSettle();
    expect(find.text('March item'), findsNothing);
    expect(portfolio.visibleTransactions.length, 3);
    expect(tester.takeException(), isNull);
  });
}
