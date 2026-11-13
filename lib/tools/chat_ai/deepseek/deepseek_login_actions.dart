import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import '../chat_ai_state.dart';
import '../widgets/deepseek_token_dialog.dart';
import 'deepseek_api.dart';

class DeepSeekLoginActions {
  DeepSeekLoginActions._();

  static final Uri _loginUrl = Uri.parse('https://chat.deepseek.com/sign_in');
  static const String _tokenScript = "localStorage.getItem('userToken')";

  /// Null on success or cancel, else the reason the sign-in failed.
  static Future<String?> webLogin(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await WebLogin.open(
      context,
      url: _loginUrl,
      title: l10n.chatAiDeepSeekLoginTitle,
      target: WebLoginTarget.script(
        script: _tokenScript,
        isScriptComplete: (value) =>
            DeepSeekApi.tokenFromStorage(value) != null,
      ),
    );
    if (result is! WebLoginScriptValue || !context.mounted) return null;
    final token = DeepSeekApi.tokenFromStorage(result.value);
    if (token == null) return null;
    return _signIn(context, token);
  }

  static Future<String?> pasteToken(BuildContext context) async {
    final raw = await DeepSeekTokenDialog.show(context);
    final token = DeepSeekApi.tokenFromStorage(raw);
    if (token == null || !context.mounted) return null;
    return _signIn(context, token);
  }

  static Future<String?> _signIn(BuildContext context, String token) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final locale = Localizations.localeOf(context).languageCode;
    try {
      await context.read<ChatAiState>().signInDeepSeek(token, locale: locale);
    } on DeepSeekException catch (e) {
      return errorText(l10n, e.kind, e.message);
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.chatAiDeepSeekSignedIn)),
    );
    return null;
  }

  static String errorText(
    AppLocalizations l10n,
    DeepSeekErrorKind kind,
    String? detail,
  ) => switch (kind) {
    DeepSeekErrorKind.unauthorized => l10n.chatAiDeepSeekErrorUnauthorized,
    DeepSeekErrorKind.banned => l10n.chatAiDeepSeekErrorBanned,
    DeepSeekErrorKind.challenge => l10n.chatAiDeepSeekErrorChallenge,
    DeepSeekErrorKind.network => l10n.chatAiDeepSeekErrorNetwork,
    DeepSeekErrorKind.server => l10n.chatAiDeepSeekErrorServer(detail ?? ''),
  };
}
