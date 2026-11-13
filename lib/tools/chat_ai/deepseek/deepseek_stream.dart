import 'dart:convert';

/// A reply as far as it has streamed in.
class DeepSeekReply {
  final String thinking;
  final String text;
  final int? responseMessageId;
  final String? title;
  final String? notice;
  final bool finished;

  const DeepSeekReply({
    this.thinking = '',
    this.text = '',
    this.responseMessageId,
    this.title,
    this.notice,
    this.finished = false,
  });
}

class _Fragment {
  final String type;
  String content;

  _Fragment(this.type, this.content);
}

/// Folds the web app's SSE patch stream (`p` path, `o` op, `v` value; lines
/// without `p` continue the previous path) into a [DeepSeekReply].
class DeepSeekStreamParser {
  final List<_Fragment> _fragments = [];
  String? _event;
  String? _path;
  String _op = 'SET';
  int? _responseMessageId;
  String? _title;
  String? _notice;
  String? _status;

  static const String _fragmentsPath = 'response/fragments';
  static const String _lastContentPath = 'response/fragments/-1/content';

  DeepSeekReply get reply {
    final thinking = StringBuffer();
    final text = StringBuffer();
    for (final fragment in _fragments) {
      switch (fragment.type) {
        case 'THINK':
          thinking.write(fragment.content);
        case 'RESPONSE':
          text.write(fragment.content);
      }
    }
    return DeepSeekReply(
      thinking: thinking.toString(),
      text: text.toString(),
      responseMessageId: _responseMessageId,
      title: _title,
      notice: _notice,
      finished: _status == 'FINISHED',
    );
  }

  /// Feeds one SSE line; true when the reply changed.
  bool addLine(String line) {
    if (line.isEmpty) {
      _event = null;
      return false;
    }
    if (line.startsWith('event:')) {
      _event = line.substring(6).trim();
      return false;
    }
    if (!line.startsWith('data:')) return false;
    final Object? data;
    try {
      data = jsonDecode(line.substring(5).trim());
    } on FormatException {
      return false;
    }
    if (data is! Map<String, dynamic>) return false;
    return switch (_event) {
      'ready' => _onReady(data),
      'title' => _onTitle(data),
      'hint' || 'toast' => _onNotice(data),
      null => _onPatch(data),
      _ => false,
    };
  }

  bool _onReady(Map<String, dynamic> data) {
    _responseMessageId = (data['response_message_id'] as num?)?.toInt();
    return true;
  }

  bool _onTitle(Map<String, dynamic> data) {
    final title = data['content'] ?? data['title'];
    if (title is! String) return false;
    _title = title;
    return true;
  }

  bool _onNotice(Map<String, dynamic> data) {
    final content = data['content'];
    if (content is! String || content.isEmpty) return false;
    _notice = content;
    return true;
  }

  bool _onPatch(Map<String, dynamic> data) {
    final path = data['p'];
    if (path is String) {
      _path = path;
      _op = data['o'] as String? ?? 'SET';
    } else if (data['o'] is String) {
      _op = data['o'] as String;
    }
    final value = data['v'];
    if (path == null && value is Map<String, dynamic>) {
      final response = value['response'];
      if (response is Map<String, dynamic>) {
        _path = null;
        return _applyResponse(response);
      }
    }
    return _apply(_path, _op, value);
  }

  bool _apply(String? path, String op, Object? value) {
    switch (path) {
      case _lastContentPath when value is String:
        if (_fragments.isEmpty) _fragments.add(_Fragment('RESPONSE', ''));
        final last = _fragments.last;
        last.content = op == 'APPEND' ? last.content + value : value;
        return true;
      case _fragmentsPath when value is List:
        final fragments = _parseFragments(value);
        if (op != 'APPEND') _fragments.clear();
        _fragments.addAll(fragments);
        return true;
      case 'response/status' when value is String:
        _status = value;
        return true;
      case 'response' when op == 'BATCH' && value is List:
        var changed = false;
        for (final item in value) {
          if (item is! Map<String, dynamic>) continue;
          final sub = item['p'];
          if (sub == 'quasi_status' && item['v'] is String) {
            _status = item['v'] as String;
            changed = true;
          } else if (sub is String) {
            changed =
                _apply(
                  'response/$sub',
                  item['o'] as String? ?? 'SET',
                  item['v'],
                ) ||
                changed;
          }
        }
        return changed;
    }
    return false;
  }

  bool _applyResponse(Map<String, dynamic> response) {
    _responseMessageId =
        (response['message_id'] as num?)?.toInt() ?? _responseMessageId;
    final status = response['status'];
    if (status is String) _status = status;
    final fragments = response['fragments'];
    if (fragments is List) {
      _fragments
        ..clear()
        ..addAll(_parseFragments(fragments));
    }
    return true;
  }

  static List<_Fragment> _parseFragments(List<dynamic> raw) => [
    for (final item in raw)
      if (item is Map<String, dynamic>)
        _Fragment(
          item['type'] as String? ?? '',
          item['content'] as String? ?? '',
        ),
  ];
}
