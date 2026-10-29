import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/widgets/depot_tabs.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

void main() {
  for (final width in [320.0, 700.0, 1000.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('tabs fit $width at text scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => DepotState(),
            child: MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 400),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(16),
                    child: DepotTabs(),
                  ),
                ),
              ),
            ),
          ),
        );
        final segments = tester
            .widget<SegmentedButton<DepotTab>>(
              find.byType(SegmentedButton<DepotTab>),
            )
            .segments;
        expect(segments, hasLength(6));
        for (final segment in segments) {
          if (BoxConstraints(maxWidth: width - 32).isCompact) {
            expect(segment.label, isA<Icon>());
            continue;
          }
          final row = segment.label! as Row;
          expect(row.children.first, isA<Icon>());
          final label = (row.children.last as Flexible).child as Text;
          expect(label.maxLines, 1);
          expect(label.overflow, TextOverflow.ellipsis);
        }
        expect(find.byType(Icon), findsNWidgets(6));
        if (BoxConstraints(maxWidth: width - 32).isCompact) {
          final icons = find.byType(Icon);
          for (var i = 0; i < 6; i++) {
            final icon = icons.at(i);
            final button = find
                .ancestor(of: icon, matching: find.byType(TextButton))
                .first;
            expect(
              tester.getCenter(icon).dx,
              closeTo(tester.getCenter(button).dx, 0.1),
            );
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
