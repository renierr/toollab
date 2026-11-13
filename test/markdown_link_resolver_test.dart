import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/tools/markdown_viewer/markdown_link_resolver.dart';

void main() {
  group('isExternal', () {
    test('web and mail links are external', () {
      expect(MarkdownLinkResolver.isExternal('https://x.org/a.md'), isTrue);
      expect(MarkdownLinkResolver.isExternal('mailto:a@b.c'), isTrue);
    });

    test('file paths are local', () {
      expect(MarkdownLinkResolver.isExternal('overview.md'), isFalse);
      expect(MarkdownLinkResolver.isExternal('../a/b.md#x'), isFalse);
      expect(MarkdownLinkResolver.isExternal(r'C:\docs\a.md'), isFalse);
      expect(MarkdownLinkResolver.isExternal('file:///tmp/a.md'), isFalse);
    });
  });

  group('resolveLocal', () {
    test('resolves relative link against the document folder', () {
      final target = MarkdownLinkResolver.resolveLocal(
        'usage.md#talking-to-the-bot',
        r'D:\dev\docs\index.md',
        context: p.windows,
      );
      expect(target?.path, r'D:\dev\docs\usage.md');
      expect(target?.fragment, 'talking-to-the-bot');
    });

    test('normalizes parent segments and decodes escapes', () {
      final target = MarkdownLinkResolver.resolveLocal(
        '../other/my%20file.md',
        '/home/u/docs/index.md',
        context: p.posix,
      );
      expect(target?.path, '/home/u/other/my file.md');
      expect(target?.fragment, isNull);
    });

    test('relative link without a base folder cannot resolve', () {
      expect(MarkdownLinkResolver.resolveLocal('a.md', null), isNull);
    });

    test('absolute paths ignore the base', () {
      final target = MarkdownLinkResolver.resolveLocal(
        '/etc/notes.md',
        '/home/u/docs/index.md',
        context: p.posix,
      );
      expect(target?.path, '/etc/notes.md');
    });
  });
}
