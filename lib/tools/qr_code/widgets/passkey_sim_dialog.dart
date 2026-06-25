import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PasskeySimDialog extends StatefulWidget {
  final String text;
  final Color accentColor;

  const PasskeySimDialog({
    super.key,
    required this.text,
    required this.accentColor,
  });

  static Future<void> show(
    BuildContext context,
    String text,
    Color accentColor,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          PasskeySimDialog(text: text, accentColor: accentColor),
    );
  }

  @override
  State<PasskeySimDialog> createState() => _PasskeySimDialogState();
}

class _PasskeySimDialogState extends State<PasskeySimDialog> {
  bool _isLoading = false;
  bool _isSuccess = false;

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
    });
    // Simulate biometric check / network delay
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isSuccess) {
      return ResponsiveAlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: widget.accentColor,
          size: 48,
        ),
        title: Text(l10n.qrPasskeySimTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.qrPasskeySimSuccess,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                '{\n  "status": "success",\n  "clientDataJSON": "eyJjaGFsbGVuZ2UiOiJleGFtcGxlX2NoYWxsZW5nZSIsIm9yaWdpbiI6Imh0dHBzOi8vc2VjdXJlLmxvZ2luIiwidHlwZSI6IndlYmF1dGhuLmdldCJ9",\n  "authenticatorData": "SZYN5YgOjGh0NBcP56...",\n  "signature": "MEUCIQDM8U3Xv8BfL...",\n  "userHandle": "YWxpY2VAZXhhbXBsZS5jb20"\n}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      );
    }

    return ResponsiveAlertDialog(
      icon: Icon(
        Icons.fingerprint_outlined,
        color: widget.accentColor,
        size: 48,
      ),
      title: Text(l10n.qrPasskeySimTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.qrPasskeySimPrompt,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.qrPasskeySimUser,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            l10n.qrPasskeySimDomain,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          if (_isLoading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (!_isLoading)
          FilledButton(
            onPressed: _authenticate,
            style: FilledButton.styleFrom(backgroundColor: widget.accentColor),
            child: Text(l10n.qrResultSimulatePasskey),
          ),
      ],
    );
  }
}
