import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({
    super.key,
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: hidden ? l10n.toolLockShowPassword : l10n.toolLockHidePassword,
      onPressed: onPressed,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}
