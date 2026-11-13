import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// The signed-in DeepSeek web account, kept in secure storage.
class DeepSeekAccount {
  final String token;
  final String? name;

  const DeepSeekAccount({required this.token, this.name});

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'chat_ai_deepseek_token';
  static const _nameKey = 'chat_ai_deepseek_name';

  static Future<DeepSeekAccount?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;
      return DeepSeekAccount(
        token: token,
        name: await _storage.read(key: _nameKey),
      );
    } catch (e) {
      errorLog('[DeepSeekAccount] Reading account failed: $e');
      return null;
    }
  }

  Future<void> save() async {
    await _storage.write(key: _tokenKey, value: token);
    if (name == null) {
      await _storage.delete(key: _nameKey);
    } else {
      await _storage.write(key: _nameKey, value: name);
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _nameKey);
  }
}
