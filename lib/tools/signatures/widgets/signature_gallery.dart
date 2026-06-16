import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../signature_models.dart';
import '../signatures_state.dart';
import 'signature_gallery_item.dart';

/// Grid of saved signatures with per-item actions.
class SignatureGallery extends StatelessWidget {
  final void Function(SignatureRecord) onLoad;
  final void Function(SignatureRecord) onDelete;
  final void Function(SignatureRecord) onExportPng;
  final void Function(SignatureRecord) onExportSvg;

  const SignatureGallery({
    super.key,
    required this.onLoad,
    required this.onDelete,
    required this.onExportPng,
    required this.onExportSvg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<SignaturesState>().saved;

    if (saved.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No saved signatures yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        final record = saved[index];
        return SignatureGalleryItem(
          record: record,
          onLoad: () => onLoad(record),
          onDelete: () => onDelete(record),
          onExportPng: () => onExportPng(record),
          onExportSvg: () => onExportSvg(record),
        );
      },
    );
  }
}
