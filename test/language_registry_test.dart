import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/syntax/language_registry.dart';

void main() {
  group('LanguageRegistry.resolveAlias', () {
    test('resolves supported names identically', () {
      for (final language in LanguageRegistry.supportedLanguages) {
        expect(LanguageRegistry.resolveAlias(language), language);
      }
    });

    test('resolves common fence aliases', () {
      expect(LanguageRegistry.resolveAlias('js'), 'javascript');
      expect(LanguageRegistry.resolveAlias('TS'), 'typescript');
      expect(LanguageRegistry.resolveAlias('py'), 'python');
      expect(LanguageRegistry.resolveAlias('shell'), 'bash');
      expect(LanguageRegistry.resolveAlias('yml'), 'yaml');
      expect(LanguageRegistry.resolveAlias('kt'), 'kotlin');
      expect(LanguageRegistry.resolveAlias(' rs '), 'rust');
    });

    test('returns null for unknown or empty input', () {
      expect(LanguageRegistry.resolveAlias(null), isNull);
      expect(LanguageRegistry.resolveAlias(''), isNull);
      expect(LanguageRegistry.resolveAlias('notalang'), isNull);
      expect(LanguageRegistry.resolveAlias('cobol'), isNull);
    });
  });

  group('LanguageRegistry.fromFileName', () {
    test('maps extensions like the code-highlight tool did', () {
      expect(LanguageRegistry.fromFileName('main.dart'), 'dart');
      expect(LanguageRegistry.fromFileName('a.mjs'), 'javascript');
      expect(LanguageRegistry.fromFileName('a.cts'), 'typescript');
      expect(LanguageRegistry.fromFileName('a.pyw'), 'python');
      expect(LanguageRegistry.fromFileName('a.yml'), 'yaml');
      expect(LanguageRegistry.fromFileName('a.htm'), 'html');
      expect(LanguageRegistry.fromFileName('a.kts'), 'kotlin');
      expect(LanguageRegistry.fromFileName('a.sh'), 'bash');
      expect(LanguageRegistry.fromFileName('README.markdown'), 'markdown');
    });

    test('falls back to plain', () {
      expect(LanguageRegistry.fromFileName('Makefile'), 'plain');
      expect(LanguageRegistry.fromFileName('a.xyz'), 'plain');
    });
  });
}
