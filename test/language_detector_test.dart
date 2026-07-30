import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/syntax/language_detector.dart';

void main() {
  group('LanguageDetector.detect', () {
    test('detects json', () {
      expect(
        LanguageDetector.detect('{"name": "tool_lab", "count": 3}'),
        'json',
      );
    });

    test('detects dart', () {
      expect(
        LanguageDetector.detect('''
class Foo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
'''),
        'dart',
      );
    });

    test('detects python', () {
      expect(
        LanguageDetector.detect('''
def main():
    if x:
        print("hi")
    elif y:
        pass
'''),
        'python',
      );
    });

    test('detects bash from shebang', () {
      expect(
        LanguageDetector.detect('''
#!/usr/bin/env bash
cd /tmp && echo "\$HOME"
'''),
        'bash',
      );
    });

    test('detects sql', () {
      expect(
        LanguageDetector.detect('select id, name from users where id = 1;'),
        'sql',
      );
    });

    test('detects html', () {
      expect(
        LanguageDetector.detect('<div class="x"><p>hello</p></div>'),
        'html',
      );
    });

    test('detects go', () {
      expect(
        LanguageDetector.detect('''
package main

func main() {
	msg := "hi"
	fmt.Println(msg)
}
'''),
        'go',
      );
    });

    test('detects rust', () {
      expect(
        LanguageDetector.detect('''
fn main() {
    let mut total = 0;
    println!("{}", total);
}
'''),
        'rust',
      );
    });

    test('returns null for prose', () {
      expect(
        LanguageDetector.detect(
          'This is just a plain paragraph of text without any code in it.',
        ),
        isNull,
      );
    });

    test('returns null for very short input', () {
      expect(LanguageDetector.detect('x = 1'), isNull);
    });

    test('returns null for malformed json-ish text', () {
      expect(
        LanguageDetector.detect('{ not really json at all, is it }'),
        isNull,
      );
    });
  });
}
