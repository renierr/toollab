import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/copyable_image.dart';

void main() {
  testWidgets('long press and right click copy the image', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACAQMAAABIeJ9nAAAAIGNIUk0AAHomAACAhAAA'
      '+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAADUExURf8AABniCTcAAAAHdElNRQfq'
      'CwgLKgs9g3H7AAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDI2LTExLTA4VDExOjQyOjExKzAw'
      'OjAwIZOIRQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyNi0xMS0wOFQxMTo0MjoxMSswMDow'
      'MFDOMPkAAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjYtMTEtMDhUMTE6NDI6MTErMDA6'
      'MDAH2xEmAAAADElEQVQI12NgYGAAAAAEAAEnNCcKAAAAAElFTkSuQmCC',
    );
    final provider = MemoryImage(bytes);
    var copies = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CopyableImage(
            image: provider,
            copyImage: (image) async {
              expect(image.width, 2);
              copies++;
              return true;
            },
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(provider, tester.element(find.byType(CopyableImage)));
    });
    await tester.pump();
    await tester.longPress(find.byType(CopyableImage));
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(find.text('Image copied to clipboard'), findsOneWidget);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.addPointer(
      location: tester.getCenter(find.byType(CopyableImage)),
    );
    await gesture.down(tester.getCenter(find.byType(CopyableImage)));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(copies, 2);
  });
}
