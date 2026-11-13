import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/services/document_insight/document_insight.dart';
import 'package:tool_lab/services/document_insight/document_insight_service.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('document_insight_test_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<String> writeText(String text) async {
    final file = File('${dir.path}/doc.txt');
    await file.writeAsString(text);
    return file.path;
  }

  const candidates = DocumentInsightCandidates(
    correspondents: ['Telekom', 'Stadtwerke München', 'Tel'],
    documentTypes: ['Rechnung', 'Vertrag'],
    tags: ['Internet', 'Steuer', 'Auto'],
  );

  test('matches labels by whole words and picks the first date', () async {
    final path = await writeText('''
Telekom Deutschland GmbH
Rechnung vom 03.11.2025
Ihr Internet-Anschluss, fällig am 17.11.2025
Automatische Abbuchung.
''');

    final insight = await DocumentInsightService.instance.analyze(
      path,
      candidates: candidates,
      languageCode: 'de',
    );

    expect(insight.correspondent, 'Telekom');
    expect(insight.documentType, 'Rechnung');
    expect(insight.tags, ['Internet']);
    expect(insight.date, DateTime(2025, 11, 3));
    expect(insight.usedAi, isFalse);
  });

  test('prefers the earliest correspondent in the text', () async {
    final path = await writeText(
      'Stadtwerke München\nKundenservice der Telekom\nVertrag 2024-02-29',
    );

    final insight = await DocumentInsightService.instance.analyze(
      path,
      candidates: candidates,
      languageCode: 'de',
    );

    expect(insight.correspondent, 'Stadtwerke München');
    expect(insight.documentType, 'Vertrag');
    expect(insight.date, DateTime(2024, 2, 29));
  });

  test('ignores invalid and future dates', () async {
    final path = await writeText('Datum 31.02.2025, gültig bis 01.01.2999');

    final insight = await DocumentInsightService.instance.analyze(
      path,
      candidates: candidates,
      languageCode: 'de',
    );

    expect(insight.date, isNull);
    expect(insight.isEmpty, isTrue);
  });

  test('returns no text for unsupported files', () async {
    final file = File('${dir.path}/doc.bin');
    await file.writeAsBytes([0, 1, 2]);

    final insight = await DocumentInsightService.instance.analyze(
      file.path,
      candidates: candidates,
      languageCode: 'en',
    );

    expect(insight.hasText, isFalse);
  });
}
