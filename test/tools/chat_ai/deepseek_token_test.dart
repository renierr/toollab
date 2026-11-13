import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_api.dart';

void main() {
  test('reads the stored token in its forms', () {
    expect(DeepSeekApi.tokenFromStorage('abc'), 'abc');
    expect(DeepSeekApi.tokenFromStorage(' Bearer abc '), 'abc');
    expect(
      DeepSeekApi.tokenFromStorage('{"value":"abc","__version":"0"}'),
      'abc',
    );
    // Android's WebView returns string results JSON-encoded once more.
    expect(
      DeepSeekApi.tokenFromStorage(
        r'"{\"value\":\"abc\",\"__version\":\"0\"}"',
      ),
      'abc',
    );
    expect(DeepSeekApi.tokenFromStorage({'value': 'abc'}), 'abc');
  });

  test('ignores a missing token', () {
    expect(DeepSeekApi.tokenFromStorage(null), isNull);
    expect(DeepSeekApi.tokenFromStorage('null'), isNull);
    expect(DeepSeekApi.tokenFromStorage(''), isNull);
    expect(DeepSeekApi.tokenFromStorage('{"value":null}'), isNull);
  });
}
