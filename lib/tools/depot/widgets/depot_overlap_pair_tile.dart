import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_overlap.dart';
import 'depot_info_row.dart';
import 'depot_overlap_avatars.dart';

class DepotOverlapPairTile extends StatelessWidget {
  final DepotOverlapPair pair;
  final DepotFormat format;
  final VoidCallback onTap;

  const DepotOverlapPairTile({
    super.key,
    required this.pair,
    required this.format,
    required this.onTap,
  });

  static const double _avatarSize = 26;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = DepotColors.overlap(pair.level);
    final name = theme.textTheme.bodyMedium;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DepotInfoRow(
              leading: DepotOverlapAvatars(
                first: pair.a,
                second: pair.b,
                size: _avatarSize,
              ),
              title: Text(
                pair.a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: name,
              ),
              subtitle: Text(
                pair.b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: name,
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    format.percent(pair.overlap * 100, signed: false),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.depotOverlapShared(pair.shared.length),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(
                left: DepotOverlapAvatars.widthOf(_avatarSize) + 8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pair.overlap,
                  minHeight: 4,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
