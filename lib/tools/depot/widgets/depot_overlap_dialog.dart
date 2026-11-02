import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_overlap.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';
import 'depot_holding_avatar.dart';

/// One fund pair: the overlap score and each shared holding's weight in both.
class DepotOverlapDialog extends StatelessWidget {
  final DepotOverlapPair pair;
  final DepotFormat format;

  const DepotOverlapDialog({
    super.key,
    required this.pair,
    required this.format,
  });

  static Future<void> show(
    BuildContext context,
    DepotOverlapPair pair,
    DepotFormat format,
  ) => showDialog<void>(
    context: context,
    builder: (_) => DepotOverlapDialog(pair: pair, format: format),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final color = DepotColors.overlap(pair.level);
    final widest = pair.shared.fold<double>(
      0,
      (widest, s) => math.max(widest, math.max(s.weightA, s.weightB)),
    );

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.depotOverlapTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FundRow(
                fund: pair.a,
                coverage: pair.coverageA,
                color: DepotColors.overlapFirst,
                format: format,
              ),
              const SizedBox(height: 8),
              _FundRow(
                fund: pair.b,
                coverage: pair.coverageB,
                color: DepotColors.overlapSecond,
                format: format,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      format.percent(pair.overlap * 100, signed: false),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DepotPortfolioLabels.overlapLevel(l10n, pair.level),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          l10n.depotOverlapShared(pair.shared.length),
                          style: hint,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.depotOverlapLowerBound, style: hint),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (pair.shared.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.depotOverlapNone,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final share in pair.shared)
                  _ShareRow(share: share, widest: widest, format: format),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _FundRow extends StatelessWidget {
  final DepotHolding fund;
  final double coverage;
  final Color color;
  final DepotFormat format;

  const _FundRow({
    required this.fund,
    required this.coverage,
    required this.color,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        DepotHoldingAvatar(
          name: fund.name,
          colorSeed: fund.identifier ?? fund.id,
          size: 28,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fund.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                l10n.depotOverlapCoverage(
                  format.percent(coverage * 100, signed: false),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  final DepotOverlapShare share;
  final double widest;
  final DepotFormat format;

  const _ShareRow({
    required this.share,
    required this.widest,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  share.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (share.heldDirectly)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: l10n.depotOverlapHeldDirectly,
                    child: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                format.percent(share.overlap * 100, signed: false),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _WeightBar(
            weight: share.weightA,
            widest: widest,
            color: DepotColors.overlapFirst,
            format: format,
          ),
          const SizedBox(height: 3),
          _WeightBar(
            weight: share.weightB,
            widest: widest,
            color: DepotColors.overlapSecond,
            format: format,
          ),
        ],
      ),
    );
  }
}

class _WeightBar extends StatelessWidget {
  final double weight;
  final double widest;
  final Color color;
  final DepotFormat format;

  const _WeightBar({
    required this.weight,
    required this.widest,
    required this.color,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widest > 0 ? (weight / widest).clamp(0, 1) : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            format.percent(weight * 100, signed: false),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}
