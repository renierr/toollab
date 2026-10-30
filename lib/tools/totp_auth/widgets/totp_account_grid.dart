import 'package:flutter/material.dart';

import '../totp_account.dart';
import '../totp_auth_state.dart';
import 'totp_account_card.dart';

class TotpAccountGrid extends StatelessWidget {
  final List<TotpAccount> accounts;
  final TotpAuthState state;
  final ValueChanged<TotpAccount> onCopy;
  final ValueChanged<TotpAccount> onEdit;
  final ValueChanged<TotpAccount> onCopyUri;
  final ValueChanged<TotpAccount> onDelete;
  final ValueChanged<TotpAccount> onAdvance;

  const TotpAccountGrid({
    super.key,
    required this.accounts,
    required this.state,
    required this.onCopy,
    required this.onEdit,
    required this.onCopyUri,
    required this.onDelete,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisExtent: 150 + (textScale - 1) * 34,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return TotpAccountCard(
          key: ValueKey(account.id),
          account: account,
          code: state.codeFor(account),
          remaining: state.secondsRemaining(account),
          onCopy: () => onCopy(account),
          onEdit: () => onEdit(account),
          onCopyUri: () => onCopyUri(account),
          onDelete: () => onDelete(account),
          onAdvance: () => onAdvance(account),
        );
      },
    );
  }
}
