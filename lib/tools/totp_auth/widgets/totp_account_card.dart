import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../totp_account.dart';
import '../totp_auth_state.dart';

class TotpAccountCard extends StatelessWidget {
  const TotpAccountCard({super.key, required this.account, required this.state});

  final TotpAccount account;
  final TotpAuthState state;

  @override
  Widget build(BuildContext context) {
    final code = state.currentCode(account);
    final remaining = state.secondsRemaining(account);
    final progress = remaining / account.period;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.issuer.isEmpty ? account.accountName : account.issuer,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (account.accountName.isNotEmpty)
                    Text(
                      account.accountName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text('$remaining'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete account?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) await state.deleteAccount(account.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
