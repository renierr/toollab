import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/frontmatter_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';

/// Renders parsed YAML frontmatter of a markdown document as a metadata card.
class FrontmatterCard extends StatelessWidget {
  final FrontmatterResult frontmatter;
  final Color accentColor;
  final bool initiallyExpanded;

  const FrontmatterCard({
    super.key,
    required this.frontmatter,
    this.accentColor = AppTheme.accentBlue,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final Widget body;
    if (frontmatter.error != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          l10n.widgetMarkdownFrontmatterInvalid(frontmatter.error!),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in frontmatter.fields.entries)
            _FrontmatterEntry(
              name: entry.key,
              value: entry.value,
              accentColor: accentColor,
            ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: CollapsibleSection(
        icon: Icons.data_object,
        iconColor: accentColor,
        title: l10n.widgetMarkdownFrontmatter,
        initiallyExpanded: initiallyExpanded,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: body,
        ),
      ),
    );
  }
}

class _FrontmatterEntry extends StatelessWidget {
  final String name;
  final dynamic value;
  final Color accentColor;
  final int depth;

  const _FrontmatterEntry({
    required this.name,
    required this.value,
    required this.accentColor,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      name,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );

    final Widget content;
    if (value is Map) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          for (final entry in (value as Map).entries)
            _FrontmatterEntry(
              name: entry.key.toString(),
              value: entry.value,
              accentColor: accentColor,
              depth: depth + 1,
            ),
        ],
      );
    } else if (value is List) {
      final items = value as List;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: 4),
          if (items.isEmpty)
            _PlainValue(text: '-')
          else if (items.any((e) => e is Map || e is List))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: _PlainValue(
                      text: '• ${FrontmatterHelper.formatValue(item)}',
                    ),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  _ValueChip(
                    text: FrontmatterHelper.formatValue(item),
                    accentColor: accentColor,
                  ),
              ],
            ),
        ],
      );
    } else if (value is bool) {
      content = Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          Icon(
            value == true ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: value == true ? AppTheme.statusGreen : AppTheme.statusRed,
          ),
        ],
      );
    } else {
      final text = FrontmatterHelper.formatValue(value);
      // Right-aligned reads fine for short values, but a wrapped paragraph with
      // a ragged left edge does not — those get their own left-aligned block.
      final isLong = text.length > 60 || text.contains('\n');
      content = isLong
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 4),
                _PlainValue(text: text),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: label),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _PlainValue(text: text, align: TextAlign.end),
                ),
              ],
            );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, top: 6),
      child: content,
    );
  }
}

class _PlainValue extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _PlainValue({required this.text, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.isNotEmpty ? text : '-',
      textAlign: align,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _ValueChip({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
