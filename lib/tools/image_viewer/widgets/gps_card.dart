import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tool_lab/widgets/info_card.dart';

class GpsCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? dms;

  const GpsCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.dms,
  });

  Future<void> _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InfoCard(
      icon: Icons.location_on,
      title: 'GPS Location Information',
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.25,
      ),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(label: 'Latitude', value: latitude.toStringAsFixed(6)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Longitude', value: longitude.toStringAsFixed(6)),
          if (dms != null && dms!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailRow(label: 'Coordinates (DMS)', value: dms!),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openMap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open in Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
