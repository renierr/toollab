import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;
import 'scan_profile.dart';

class NfcScanStatusCard extends StatelessWidget {
  final bool isScanning;
  final bool hasNfcSupport;
  final NfcScanProfile profile;
  final String tagUid;
  final String tagTechs;
  final String tagCapacity;
  final String tagWritable;
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
    required this.onStartScan,
    required this.onStopScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(profile.categoryId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NFC Scanner',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isScanning
                          ? 'Approach an NFC tag to scan'
                          : 'Scanner is inactive',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
                if (hasNfcSupport)
                  isScanning
                      ? ElevatedButton.icon(
                          onPressed: onStopScan,
                          icon: const Icon(Icons.stop_rounded, size: 18),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer,
                            foregroundColor: theme.colorScheme.onErrorContainer,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: onStartScan,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No Hardware',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            // Profile & Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual classification badge
                Container(
                  padding: const EdgeInsets.all(12),
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
                    size: 32,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.categoryLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        label: 'Card Brand',
                        value: profile.cardBrand ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: 'Card Number',
                        value: profile.cardNumber ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: 'Cardholder Name',
                        value: profile.cardHolder ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: 'Expiration Date',
                        value: profile.cardExpiry ?? '-',
                      ),
                      const Divider(height: 12),
                      shared.InfoRow(
                        label: 'Application AID',
                        value: profile.cardAid ?? '-',
                      ),
                      const Divider(height: 12),
                    ],
                    shared.InfoRow(label: 'UID / Serial', value: tagUid),
                    const Divider(height: 12),
                    shared.InfoRow(label: 'Technologies', value: tagTechs),
                    const Divider(height: 12),
                    shared.InfoRow(label: 'Capacity', value: tagCapacity),
                    const Divider(height: 12),
                    shared.InfoRow(label: 'Writable', value: tagWritable),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(NfcCategoryId cat) {
    return switch (cat) {
      NfcCategoryId.ndefData => Colors.greenAccent.shade700,
      NfcCategoryId.paymentCard => Colors.blueAccent.shade400,
      NfcCategoryId.passport => Colors.purpleAccent.shade400,
      NfcCategoryId.idCard => Colors.amberAccent.shade700,
      NfcCategoryId.secureCard => Colors.orangeAccent.shade700,
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
    final cardBrand = profile.cardBrand ?? 'Payment Card';
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

    return Container(
      width: double.infinity,
      height: 190,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cardBrand.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Icon(
                Icons.contactless_outlined,
                color: Colors.white70,
                size: 24,
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 30,
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
            ],
          ),
          Text(
            maskedNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
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
                    const Text(
                      'CARDHOLDER',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cardHolder.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 8,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
  }
}
