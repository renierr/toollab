import 'package:flutter/material.dart';
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
            if (tagUid.isNotEmpty || tagTechs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _DetailRow(label: 'UID / Serial', value: tagUid),
                    const Divider(height: 12),
                    _DetailRow(label: 'Technologies', value: tagTechs),
                    const Divider(height: 12),
                    _DetailRow(label: 'Capacity', value: tagCapacity),
                    const Divider(height: 12),
                    _DetailRow(label: 'Writable', value: tagWritable),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value.isNotEmpty ? value : '-',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
