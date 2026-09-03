import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/luma_well_engine.dart';

class LumaWellStatsSheet extends StatelessWidget {
  final LumaWellEngine engine;

  const LumaWellStatsSheet({super.key, required this.engine});

  static Future<void> show(BuildContext context, LumaWellEngine engine) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => LumaWellStatsSheet(engine: engine),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.lumaWellStatsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bolt_outlined),
                      title: Text(l10n.lumaWellBestCombo),
                      trailing: Text(
                        'x${engine.bestCombo}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.track_changes_outlined),
                      title: Text(l10n.lumaWellAccuracy),
                      trailing: Text(
                        '${(engine.accuracy * 100).round()}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.touch_app_outlined),
                      title: Text(l10n.lumaWellAttempts),
                      trailing: Text(
                        '${engine.attempts}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.merge_rounded),
                      title: Text(l10n.lumaWellMerges),
                      trailing: Text(
                        '${engine.merges}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
