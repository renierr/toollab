import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

void main() {
  test('toggles the n-th task checkbox and skips fenced code', () {
    const data = '- [ ] one\n```\n- [ ] code\n```\n1. [x] two\n> - [ ] three';
    expect(
      MarkdownView.toggleCheckbox(data, 0),
      '- [x] one\n```\n- [ ] code\n```\n1. [x] two\n> - [ ] three',
    );
    expect(
      MarkdownView.toggleCheckbox(data, 1),
      '- [ ] one\n```\n- [ ] code\n```\n1. [ ] two\n> - [ ] three',
    );
    expect(
      MarkdownView.toggleCheckbox(data, 2),
      '- [ ] one\n```\n- [ ] code\n```\n1. [x] two\n> - [x] three',
    );
    expect(MarkdownView.toggleCheckbox(data, 3), data);
  });
}
