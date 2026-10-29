import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import 'depot_holding_avatar.dart';

/// The period's largest gains and losses as bars around a centre line.
class DepotMoversCard extends StatefulWidget {
  final List<DepotMover> movers;
  final String periodLabel;
  final DepotFormat format;

  const DepotMoversCard({
    super.key,
    required this.movers,
    required this.periodLabel,
    required this.format,
  });

  @override
  State<DepotMoversCard> createState() => _DepotMoversCardState();
}

class _DepotMoversCardState extends State<DepotMoversCard> {
  final GlobalKey _captureKey = GlobalKey();

  Future<void> _copyAsImage() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    var copied = false;
    if (boundary != null) {
      ui.Image? image;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          copied = await ClipboardHelper.copyImageBytes(
            data.buffer.asUint8List(),
          );
        }
      } catch (e) {
        errorLog('DepotMoversCard: copy as image failed: $e');
      } finally {
        image?.dispose();
      }
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.depotMoversCopied : l10n.depotMoversCopyFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final movers = widget.movers;
    final largest = movers
        .map((m) => m.returnPercent.abs())
        .fold<double>(0, math.max);

    return RepaintBoundary(
      key: _captureKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.depotMoversTitle(widget.periodLabel),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _copyAsImage,
                    tooltip: l10n.depotMoversCopy,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final mover in movers)
                _MoverRow(
                  mover: mover,
                  share: largest <= 0 ? 0 : mover.returnPercent.abs() / largest,
                  format: widget.format,
                  periodLabel: widget.periodLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  final DepotMover mover;

  /// Bar length relative to the largest move, 0..1.
  final double share;
  final DepotFormat format;
  final String periodLabel;

  const _MoverRow({
    required this.mover,
    required this.share,
    required this.format,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holding = mover.holding;
    final returnPercent = mover.returnPercent;
    final color = DepotFormat.gainColor(returnPercent) ?? theme.hintColor;
    final l10n = AppLocalizations.of(context);
    final details = <String>[
      holding.name,
      if (holding.isin != null && holding.isin!.isNotEmpty)
        '${l10n.depotDetailIsin}: ${holding.isin}'
      else if (holding.symbol != null && holding.symbol!.isNotEmpty)
        '${l10n.depotDetailSymbol}: ${holding.symbol}',
      '${l10n.depotDetailShares}: ${format.shares(holding.shares)}',
      if (holding.currentPrice != 0)
        '${l10n.depotDetailCurrentPrice}: ${format.money(holding.currentPrice)}',
      '${l10n.depotDetailCurrentValue}: ${format.money(holding.currentValue)}',
      '${l10n.depotDetailPeriodReturn(periodLabel)}: ${format.percent(returnPercent)}',
    ];

    return Tooltip(
      message: details.join('\n'),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            DepotHoldingAvatar(
              name: holding.name,
              colorSeed: holding.identifier ?? holding.id,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                holding.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _Bar(
                        share: returnPercent < 0 ? share : 0,
                        color: color,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                    Container(width: 1, color: theme.dividerColor),
                    Expanded(
                      child: _Bar(
                        share: returnPercent > 0 ? share : 0,
                        color: color,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 76),
              child: Text(
                format.percent(returnPercent),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double share;
  final Color color;
  final Alignment alignment;

  const _Bar({
    required this.share,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FractionallySizedBox(
      widthFactor: share,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
