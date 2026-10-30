import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.totpRotationPending,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(l10n.totpRotationPendingDescription),
              const SizedBox(height: 16),
              if (busy)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: onResume,
                  child: Text(l10n.totpRotationResume),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
