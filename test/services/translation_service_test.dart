import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

void main() {
  test('maps language codes with regions to translate languages', () {
    expect(TranslationService.languageFor('de'), TranslateLanguage.german);
    expect(TranslationService.languageFor('en-US'), TranslateLanguage.english);
    expect(
      TranslationService.languageFor('pt_BR'),
      TranslateLanguage.portuguese,
    );
    expect(TranslationService.languageFor('xx'), isNull);
    expect(TranslationService.languageFor(null), isNull);
  });

  test('targets the UI language unless the text is already in it', () {
    expect(
      TranslationService.defaultTarget('de', TranslateLanguage.english),
      TranslateLanguage.german,
    );
    expect(
      TranslationService.defaultTarget('de', TranslateLanguage.german),
      TranslateLanguage.english,
    );
    expect(
      TranslationService.defaultTarget('en', TranslateLanguage.english),
      TranslateLanguage.german,
    );
  });
}
