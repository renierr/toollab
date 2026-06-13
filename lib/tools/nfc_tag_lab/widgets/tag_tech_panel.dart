import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;
import '../tag_tech_data.dart';

class TagTechPanel extends StatelessWidget {
  final TagTechData data;

  const TagTechPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = data.sections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Technology Details',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...sections.map((s) => _TechSectionCard(section: s)),
      ],
    );
  }
}

class _TechSectionCard extends StatelessWidget {
  final TechSection section;

  const _TechSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: shared.InfoRow(label: item.label, value: item.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
