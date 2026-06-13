import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;
import '../tag_tech_data.dart';

class TagTechPanel extends StatelessWidget {
  final TagTechData data;

  const TagTechPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final sections = data.sections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Technology Details',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${sections.length} sections',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 6 : 8),
        ...sections.map(
          (section) => _TechSectionCard(section: section, isCompact: isCompact),
        ),
      ],
    );
  }
}

class _TechSectionCard extends StatelessWidget {
  final TechSection section;
  final bool isCompact;

  const _TechSectionCard({required this.section, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isCompact ? 10 : 12),
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
                fontSize: isCompact ? 10 : null,
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            ...section.items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 2 : 4),
                child: _ResponsiveTechRow(item: item, isCompact: isCompact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveTechRow extends StatelessWidget {
  final TechItem item;
  final bool isCompact;

  const _ResponsiveTechRow({required this.item, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (!isCompact) {
      return shared.InfoRow(label: item.label, value: item.value);
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          item.value.isNotEmpty ? item.value : '-',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
