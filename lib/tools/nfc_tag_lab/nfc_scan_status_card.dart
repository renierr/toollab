import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;
import 'scan_profile.dart';
import 'tag_tech_data.dart';
import 'widgets/tag_tech_panel.dart';

class NfcScanStatusCard extends StatelessWidget {
  final bool isScanning;
  final bool hasNfcSupport;
  final NfcScanProfile profile;
  final String tagUid;
  final String tagTechs;
  final String tagCapacity;
  final String tagWritable;
  final TagTechData? techData;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;

  const NfcScanStatusCard({
    super.key,
    required this.isScanning,
    required this.hasNfcSupport,
    required this.profile,
    required this.tagUid,
    required this.tagTechs,
    required this.tagCapacity,
    required this.tagWritable,
    this.techData,
    required this.onStartScan,
    required this.onStopScan,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(profile.categoryId);
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    final Widget actionWidget;
    if (hasNfcSupport) {
      actionWidget = isScanning
          ? ElevatedButton.icon(
              onPressed: onStopScan,
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: Text(l10n.nfcStop),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            )
          : ElevatedButton.icon(
              onPressed: onStartScan,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(l10n.nfcScan),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
            );
    } else {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.nfcNoHardware,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nfcScannerTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isScanning
                        ? l10n.nfcScanningPrompt
                        : l10n.nfcScannerInactive,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actionWidget),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.nfcScannerTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isScanning
                            ? l10n.nfcScanningPrompt
                            : l10n.nfcScannerInactive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                  actionWidget,
                ],
              ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10 : 12),
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: categoryColor.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(profile.categoryId),
                    size: isCompact ? 26 : 32,
                    color: categoryColor,
                  ),
                ),
                SizedBox(width: isCompact ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            profile.categoryLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile.confidence.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.isEmv) ...[
              _PremiumCreditCard(profile: profile),
              const SizedBox(height: 16),
            ],
            if (tagUid.isNotEmpty || tagTechs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (profile.isEmv) ...[
                      shared.InfoRow(
                        label: l10n.nfcCardBrand,
                        value: profile.cardBrand ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: l10n.nfcCardNumber,
                        value: profile.cardNumber ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: l10n.nfcCardholderName,
                        value: profile.cardHolder ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: l10n.nfcExpirationDate,
                        value: profile.cardExpiry ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: l10n.nfcApplicationAid,
                        value: profile.cardAid ?? '-',
                      ),
                      const Divider(height: 12),
                    ],
                    shared.InfoRow(label: l10n.nfcUidSerial, value: tagUid),
                    const Divider(height: 12),
                    shared.InfoRow(
                      label: l10n.nfcTechnologies,
                      value: tagTechs,
                    ),
                    const Divider(height: 12),
                    shared.InfoRow(label: l10n.nfcCapacity, value: tagCapacity),
                    const Divider(height: 12),
                    shared.InfoRow(label: l10n.nfcWritable, value: tagWritable),
                  ],
                ),
              ),
              if (techData != null) TagTechPanel(data: techData!),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(NfcCategoryId cat) {
    return switch (cat) {
      NfcCategoryId.ndefData => AppTheme.accentGreen,
      NfcCategoryId.paymentCard => AppTheme.accentBlue,
      NfcCategoryId.passport => AppTheme.accentPurple,
      NfcCategoryId.idCard => AppTheme.accentAmber,
      NfcCategoryId.secureCard => AppTheme.statusOrange,
      NfcCategoryId.unknown => Colors.grey,
    };
  }

  IconData _getCategoryIcon(NfcCategoryId cat) {
    return switch (cat) {
      NfcCategoryId.ndefData => Icons.data_object,
      NfcCategoryId.paymentCard => Icons.credit_card,
      NfcCategoryId.passport => Icons.import_contacts,
      NfcCategoryId.idCard => Icons.badge,
      NfcCategoryId.secureCard => Icons.lock_person,
      NfcCategoryId.unknown => Icons.nfc_rounded,
    };
  }
}

class _PremiumCreditCard extends StatelessWidget {
  final NfcScanProfile profile;

  const _PremiumCreditCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cardBrand = profile.cardBrand ?? l10n.nfcPaymentCard;
    final cardHolder =
        (profile.cardHolder != null && profile.cardHolder!.isNotEmpty)
        ? profile.cardHolder!
        : 'CARDHOLDER NAME';
    final expiry =
        (profile.cardExpiry != null && profile.cardExpiry!.isNotEmpty)
        ? profile.cardExpiry!
        : 'MM/YY';

    String maskedNumber = '•••• •••• •••• ••••';
    final rawNum = profile.cardNumber ?? '';
    if (rawNum.isNotEmpty) {
      if (rawNum.length >= 4) {
        final last4 = rawNum.substring(rawNum.length - 4);
        maskedNumber = '•••• •••• •••• $last4';
      }
    }

    List<Color> gradientColors = [
      const Color(0xFF1E293B),
      const Color(0xFF0F172A),
    ];
    if (cardBrand.toLowerCase().contains('visa')) {
      gradientColors = [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
    } else if (cardBrand.toLowerCase().contains('mastercard')) {
      gradientColors = [const Color(0xFF3F2B96), const Color(0xFFA8C0FF)];
    } else if (cardBrand.toLowerCase().contains('american express')) {
      gradientColors = [
        const Color(0xFF0F2027),
        const Color(0xFF203A43),
        const Color(0xFF2C5364),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Container(
          width: double.infinity,
          height: isCompact ? 176 : 190,
          margin: const EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(isCompact ? 14 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cardBrand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 13 : 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isCompact ? 1.2 : 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.contactless_outlined,
                    color: Colors.white70,
                    size: isCompact ? 20 : 24,
                  ),
                ],
              ),
              Container(
                width: isCompact ? 36 : 40,
                height: isCompact ? 28 : 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5D061), Color(0xFFE6B822)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                            ),
                        itemCount: 9,
                        itemBuilder: (context, index) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black12,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                maskedNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 15 : 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: isCompact ? 1 : 2,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.nfcCardholderLabel,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: isCompact ? 7 : 8,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cardHolder.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.nfcExpiresLabel,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: isCompact ? 7 : 8,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expiry,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
