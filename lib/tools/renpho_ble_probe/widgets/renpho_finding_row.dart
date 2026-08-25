import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../renpho_analysis_labels.dart';
import '../renpho_assessment.dart';
import '../renpho_colors.dart';

/// One rated value: what it is, what it reads, what the reference range is, and
/// — on tap — what it means for health.
class RenphoFindingRow extends StatefulWidget {
  final String label;
  final String value;
  final String reference;
  final RenphoRating rating;
  final String? guidance;

  const RenphoFindingRow({
    super.key,
    required this.label,
    required this.value,
    required this.reference,
    required this.rating,
    this.guidance,
  });

  @override
  State<RenphoFindingRow> createState() => _RenphoFindingRowState();
}

class _RenphoFindingRowState extends State<RenphoFindingRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = RenphoColors.rating(widget.rating);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.guidance == null
          ? null
          : () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  widget.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  widget.reference,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                StatusBadge(
                  label: widget.rating.label(l10n),
                  color: color,
                  showDot: true,
                ),
                if (widget.guidance != null)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
              ],
            ),
            if (_expanded && widget.guidance != null) ...[
              const SizedBox(height: 6),
              Text(widget.guidance!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
