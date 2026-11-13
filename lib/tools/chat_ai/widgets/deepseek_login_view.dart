import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import '../config.dart';
import '../deepseek/deepseek_login_actions.dart';

class DeepSeekLoginView extends StatefulWidget {
  const DeepSeekLoginView({super.key});

  @override
  State<DeepSeekLoginView> createState() => _DeepSeekLoginViewState();
}

class _DeepSeekLoginViewState extends State<DeepSeekLoginView> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<String?> Function(BuildContext) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action(context);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ReadableWidth(
          maxWidth: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 56,
                color: ChatAiTool.config.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.chatAiDeepSeekLoginTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.chatAiDeepSeekLoginBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_busy)
                const CircularProgressIndicator()
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (WebLogin.isSupported)
                      FilledButton.icon(
                        onPressed: () => _run(DeepSeekLoginActions.webLogin),
                        icon: const Icon(Icons.login),
                        label: Text(l10n.chatAiDeepSeekLoginButton),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _run(DeepSeekLoginActions.pasteToken),
                      icon: const Icon(Icons.key_outlined),
                      label: Text(l10n.chatAiDeepSeekPasteToken),
                    ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
