import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';
import 'package:tool_lab/tools/news/news_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async => DatabaseService.instance.close());

  test(
    'reader font size persists, clamps, and saves rapid changes in order',
    () async {
      final db = DatabaseService.instance;
      await db.setSetting(NewsTool.config.id, 'refresh_on_open', 'false');
      final state = NewsState();
      addTearDown(state.dispose);
      await state.init();
      expect(state.readerFontPercent, 100);

      await Future.wait([
        state.setReaderFontPercent(110),
        state.setReaderFontPercent(120),
        state.setReaderFontPercent(140),
      ]);
      final restored = NewsState();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.readerFontPercent, 140);
      expect(restored.readerFontScale, 1.4);

      await restored.setReaderFontPercent(999);
      expect(restored.readerFontPercent, NewsState.maxFontPercent);
      await restored.setReaderFontPercent(-1);
      expect(restored.readerFontPercent, NewsState.minFontPercent);
      final restoredAgain = NewsState();
      addTearDown(restoredAgain.dispose);
      await restoredAgain.init();
      expect(restoredAgain.readerFontPercent, NewsState.minFontPercent);

      await db.setSetting(NewsTool.config.id, 'reader_font_percent', 'invalid');
      final invalid = NewsState();
      addTearDown(invalid.dispose);
      await invalid.init();
      expect(invalid.readerFontPercent, 100);
    },
  );

  test('list font size is stored apart from the reader size', () async {
    final db = DatabaseService.instance;
    await db.setSetting(NewsTool.config.id, 'refresh_on_open', 'false');
    await db.setSetting(NewsTool.config.id, 'reader_font_percent', '100');
    final state = NewsState();
    addTearDown(state.dispose);
    await state.init();
    await state.setListFontPercent(130);
    final restored = NewsState();
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.listFontPercent, 130);
    expect(restored.readerFontPercent, 100);
    await restored.setListFontPercent(999);
    expect(restored.listFontPercent, NewsState.maxFontPercent);
  });
}
