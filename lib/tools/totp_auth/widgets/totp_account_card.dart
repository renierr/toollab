import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../totp.dart';
import '../totp_account.dart';
import 'totp_countdown_ring.dart';
import 'totp_issuer_avatar.dart';

enum TotpCardAction { edit, copyUri, delete }

class TotpAccountCard extends StatelessWidget {
  final TotpAccount account;
  final String code;
  final int remaining;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onCopyUri;
  final VoidCallback onDelete;
  final VoidCallback onAdvance;

  const TotpAccountCard({
    super.key,
    required this.account,
    required this.code,
    required this.remaining,
    required this.onCopy,
    required this.onEdit,
    required this.onCopyUri,
    required this.onDelete,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urgent = account.type == TotpType.totp && remaining <= 5;
    final progress = account.period <= 0
        ? 0.0
        : (remaining / account.period).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TotpIssuerAvatar(label: account.title),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.title.isEmpty
                              ? l10n.totpUnnamedAccount
                              : account.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (account.subtitle.isNotEmpty)
                          Text(
                            account.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<TotpCardAction>(
                    tooltip: l10n.totpAccountActions,
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onSelected: (action) {
                      switch (action) {
                        case TotpCardAction.edit:
                          onEdit();
                        case TotpCardAction.copyUri:
                          onCopyUri();
                        case TotpCardAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: TotpCardAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.commonEdit),
                        ),
                      ),
                      PopupMenuItem(
                        value: TotpCardAction.copyUri,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link_outlined),
                          title: Text(l10n.totpCopyUri),
                        ),
                      ),
                      PopupMenuItem(
                        value: TotpCardAction.delete,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.accentRed,
                          ),
                          title: Text(
                            l10n.totpDeleteAccount,
                            style: const TextStyle(color: AppTheme.accentRed),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: l10n.totpCopyCode,
                      button: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Totp.groupedCode(code),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: urgent ? AppTheme.accentRed : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (account.type == TotpType.totp)
                    TotpCountdownRing(
                      remaining: remaining,
                      period: account.period,
                    )
                  else
                    IconButton.filledTonal(
                      tooltip: l10n.totpHotpNext,
                      iconSize: 20,
                      onPressed: onAdvance,
                      icon: const Icon(Icons.refresh),
                    ),
                  IconButton(
                    tooltip: l10n.totpCopyCode,
                    iconSize: 20,
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              const Spacer(),
              if (account.type == TotpType.totp)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    color: urgent
                        ? AppTheme.accentRed
                        : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                  ),
                )
              else
                const SizedBox(height: 3),
            ],
          ),
        ),
      ),
    );
  }
}
