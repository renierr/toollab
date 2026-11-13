import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_stream.dart';

DeepSeekReply _parse(String stream) {
  final parser = DeepSeekStreamParser();
  for (final line in stream.split('\n')) {
    parser.addLine(line);
  }
  return parser.reply;
}

void main() {
  test('collects a plain reply', () {
    final reply = _parse('''
event: ready
data: {"request_message_id":5,"response_message_id":6,"model_type":"default"}

event: update_session
data: {"updated_at":1794607336.19}

data: {"v":{"response":{"message_id":6,"parent_id":5,"status":"WIP","fragments":[{"id":2,"type":"RESPONSE","content":"Emp","references":[]}]}}}

data: {"p":"response/fragments/-1/content","o":"APPEND","v":"f"}

data: {"v":"angen"}

data: {"v":"!"}

data: {"p":"response","o":"BATCH","v":[{"p":"accumulated_token_usage","v":301},{"p":"quasi_status","v":"FINISHED"}]}

data: {"p":"response/status","o":"SET","v":"FINISHED"}

event: close
data: {"click_behavior":"none","auto_resume":false}
''');
    expect(reply.text, 'Empfangen!');
    expect(reply.thinking, isEmpty);
    expect(reply.responseMessageId, 6);
    expect(reply.finished, isTrue);
  });

  test('separates thinking from the answer', () {
    final reply = _parse('''
event: ready
data: {"request_message_id":7,"response_message_id":8}

data: {"v":{"response":{"message_id":8,"status":"WIP","fragments":[{"id":2,"type":"THINK","content":"We","elapsed_secs":null}]}}}

data: {"p":"response/fragments/-1/content","o":"APPEND","v":" need"}

data: {"v":" German."}

data: {"p":"response/fragments/-1/elapsed_secs","o":"SET","v":0.71}

data: {"p":"response/fragments","o":"APPEND","v":[{"id":3,"type":"RESPONSE","content":"Hal"}]}

data: {"p":"response/fragments/-1/content","o":"APPEND","v":"lo"}

data: {"v":"!"}

data: {"p":"response/status","o":"SET","v":"FINISHED"}
''');
    expect(reply.thinking, 'We need German.');
    expect(reply.text, 'Hallo!');
    expect(reply.finished, isTrue);
  });

  test('a fragments set replaces the list', () {
    final reply = _parse('''
data: {"v":{"response":{"fragments":[{"type":"THINK","content":"a"}]}}}

data: {"p":"response/fragments","v":[{"type":"THINK","content":"abc"},{"type":"RESPONSE","content":"x"}]}

data: {"p":"response/fragments/-1/content","o":"APPEND","v":"y"}
''');
    expect(reply.thinking, 'abc');
    expect(reply.text, 'xy');
    expect(reply.finished, isFalse);
  });

  test('keeps title and hints, ignores junk', () {
    final reply = _parse('''
event: title
data: {"content":"Greeting"}

event: hint
data: {"type":"error","content":"Server busy"}

data: not json
''');
    expect(reply.title, 'Greeting');
    expect(reply.notice, 'Server busy');
  });
}
