import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/frontmatter_helper.dart';

void main() {
  test('parses valid frontmatter', () {
    final r = FrontmatterHelper.parse('''---
title: Hello
tags: [a, b]
draft: false
nested:
  key: value
---
# Body

Text''');
    expect(r.isValid, isTrue);
    expect(r.fields['title'], 'Hello');
    expect(r.fields['tags'], ['a', 'b']);
    expect(r.fields['draft'], false);
    expect((r.fields['nested'] as Map)['key'], 'value');
    expect(r.body.trim(), startsWith('# Body'));
  });

  test('ignores horizontal rule without closing delimiter', () {
    final r = FrontmatterHelper.parse('---\n# Title\ntext');
    expect(r.hasFrontmatter, isFalse);
    expect(r.body, '---\n# Title\ntext');
  });

  test('requires delimiter on first line', () {
    final r = FrontmatterHelper.parse('\n---\ntitle: x\n---\nbody');
    expect(r.hasFrontmatter, isFalse);
  });

  test('reports invalid yaml', () {
    final r = FrontmatterHelper.parse('---\ntitle: [unclosed\n---\nbody');
    expect(r.hasFrontmatter, isTrue);
    expect(r.error, isNotNull);
    expect(r.body, 'body');
  });

  test('accepts ... terminator and crlf', () {
    final r = FrontmatterHelper.parse('---\r\ntitle: x\r\n...\r\nbody');
    expect(r.isValid, isTrue);
    expect(r.fields['title'], 'x');
  });
}
