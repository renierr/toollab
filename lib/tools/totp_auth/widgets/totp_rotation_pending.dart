import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';

class TotpRotationPending extends StatelessWidget {
  const TotpRotationPending({
    super.key,
    required this.busy,
    required this.onResume,
  });

  final bool busy;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InfoCard(
        icon: Icons.lock_clock_outlined,
        title: l10n.totpRotationPending,
        titleColor: AppTheme.statusAmber,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.totpRotationPendingDescription),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FilledButton(
                onPressed: onResume,
                child: Text(l10n.totpRotationResume),
              ),
          ],
        ),
      ),
    );
  }
}
