import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/syntax/syntax_highlighter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const code = '''
// greet
void main() {
  final String name = 'world';
  print('hello \$name');
}
''';

  test('loads a bundled grammar and tokenizes dart', () async {
    await SyntaxHighlighter.preload(['dart']);
    expect(SyntaxHighlighter.isCached('dart'), isTrue);

    final result = SyntaxHighlighter.tokenizeSync(code, 'dart');
    expect(result, isNotNull);
    expect(result!.tokens.length, greaterThan(3));
    expect(result.scopes, isNotEmpty);
  });

  test('buildSpans covers the full source and styles some tokens', () async {
    await SyntaxHighlighter.preload(['dart']);
    final result = SyntaxHighlighter.tokenizeSync(code, 'dart')!;
    final spans = SyntaxHighlighter.buildSpans(
      code,
      result.tokens,
      result.scopes,
      ThemeData.dark(),
    );

    expect(spans.map((s) => s.text).join(), code);
    expect(spans.where((s) => s.style != null), isNotEmpty);
  });

  test('skips highlighting for uncached grammars and oversized input', () {
    expect(SyntaxHighlighter.tokenizeSync(code, 'plain'), isNull);
    expect(
      SyntaxHighlighter.tokenizeSync(
        'x' * (SyntaxHighlighter.maxSyncChars + 1),
        'dart',
      ),
      isNull,
    );
    expect(
      SyntaxHighlighter.tokenizeSync(
        List.filled(
          SyntaxHighlighter.maxSyncLines + 1,
          'var a = 1;',
        ).join('\n'),
        'dart',
      ),
      isNull,
    );
  });
}
