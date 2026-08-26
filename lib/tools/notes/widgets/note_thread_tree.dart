import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_title.dart';

/// Renders a note thread as an indented tree with connector rails.
/// Shared by the overview card expansion and the viewer's outline.
class NoteThreadTree extends StatelessWidget {
  final List<NoteThreadNode> nodes;
  final String? currentShortId;
  final ValueChanged<NoteThreadNode> onTap;
  final Color accentColor;
  final bool dense;

  const NoteThreadTree({
    super.key,
    required this.nodes,
    required this.onTap,
    required this.accentColor,
    this.currentShortId,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_ThreadRow>[];
    void visit(NoteThreadNode node, List<bool> rails, bool isLast) {
      rows.add(_ThreadRow(node: node, rails: rails, isLast: isLast));
      for (var i = 0; i < node.children.length; i++) {
        visit(node.children[i], [
          ...rails,
          !isLast,
        ], i == node.children.length - 1);
      }
    }

    for (var i = 0; i < nodes.length; i++) {
      visit(nodes[i], const [], i == nodes.length - 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          _NoteThreadRow(
            row: row,
            current: row.node.shortId == currentShortId,
            accentColor: accentColor,
            dense: dense,
            onTap: () => onTap(row.node),
          ),
      ],
    );
  }
}

class _ThreadRow {
  final NoteThreadNode node;

  /// Whether a vertical rail continues at each ancestor depth.
  final List<bool> rails;
  final bool isLast;

  const _ThreadRow({
    required this.node,
    required this.rails,
    required this.isLast,
  });
}

class _NoteThreadRow extends StatelessWidget {
  final _ThreadRow row;
  final bool current;
  final Color accentColor;
  final bool dense;
  final VoidCallback onTap;

  const _NoteThreadRow({
    required this.row,
    required this.current,
    required this.accentColor,
    required this.dense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final node = row.node;
    final depth = node.depth;
    final height = dense ? 30.0 : 38.0;
    final lineColor = theme.colorScheme.outline.withValues(alpha: 0.35);
    final title = noteTitle(
      node.note['content'] as String? ?? '',
      fallback: l10n.notesUntitledNote,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (depth > 0)
              CustomPaint(
                size: Size(depth * 16.0, height),
                painter: _ThreadRailPainter(
                  rails: row.rails,
                  isLast: row.isLast,
                  color: lineColor,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: current ? 10 : 8,
                height: current ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current
                      ? accentColor
                      : accentColor.withValues(alpha: 0.35),
                  border: current
                      ? Border.all(color: accentColor.withValues(alpha: 0.4))
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (dense
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: current
                              ? accentColor
                              : theme.colorScheme.onSurface,
                        ),
              ),
            ),
            if (node.children.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${node.descendantCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              FormatHelper.epoch(node.createdAt, style: DateStyle.dateOnly),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRailPainter extends CustomPainter {
  final List<bool> rails;
  final bool isLast;
  final Color color;

  const _ThreadRailPainter({
    required this.rails,
    required this.isLast,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const cell = 16.0;
    final mid = size.height / 2;

    // rails[i] marks an ancestor with further siblings; its guide line runs
    // through the full row. The last cell carries this node's own elbow.
    for (var i = 0; i < rails.length - 1; i++) {
      if (!rails[i]) continue;
      final x = i * cell + cell / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final x = (rails.length - 1) * cell + cell / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, isLast ? mid : size.height), paint);
    canvas.drawLine(Offset(x, mid), Offset(size.width, mid), paint);
  }

  @override
  bool shouldRepaint(_ThreadRailPainter oldDelegate) =>
      oldDelegate.isLast != isLast ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.rails, rails);
}
