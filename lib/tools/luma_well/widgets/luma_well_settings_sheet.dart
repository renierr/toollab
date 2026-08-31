import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../luma_well_state.dart';
import 'luma_well_help_page.dart';

IconData _directionIcon(LumaWellTouchOffsetDirection direction) =>
    switch (direction) {
      LumaWellTouchOffsetDirection.none => Icons.block,
      LumaWellTouchOffsetDirection.north => Icons.north,
      LumaWellTouchOffsetDirection.northEast => Icons.north_east,
      LumaWellTouchOffsetDirection.east => Icons.east,
      LumaWellTouchOffsetDirection.southEast => Icons.south_east,
      LumaWellTouchOffsetDirection.south => Icons.south,
      LumaWellTouchOffsetDirection.southWest => Icons.south_west,
      LumaWellTouchOffsetDirection.west => Icons.west,
      LumaWellTouchOffsetDirection.northWest => Icons.north_west,
    };

String _directionLabel(
  AppLocalizations l10n,
  LumaWellTouchOffsetDirection direction,
) => switch (direction) {
  LumaWellTouchOffsetDirection.none => l10n.lumaWellTouchOffsetDirectionNone,
  LumaWellTouchOffsetDirection.north => l10n.lumaWellTouchOffsetDirectionNorth,
  LumaWellTouchOffsetDirection.northEast =>
    l10n.lumaWellTouchOffsetDirectionNorthEast,
  LumaWellTouchOffsetDirection.east => l10n.lumaWellTouchOffsetDirectionEast,
  LumaWellTouchOffsetDirection.southEast =>
    l10n.lumaWellTouchOffsetDirectionSouthEast,
  LumaWellTouchOffsetDirection.south => l10n.lumaWellTouchOffsetDirectionSouth,
  LumaWellTouchOffsetDirection.southWest =>
    l10n.lumaWellTouchOffsetDirectionSouthWest,
  LumaWellTouchOffsetDirection.west => l10n.lumaWellTouchOffsetDirectionWest,
  LumaWellTouchOffsetDirection.northWest =>
    l10n.lumaWellTouchOffsetDirectionNorthWest,
};

class LumaWellSettingsSheet extends StatelessWidget {
  const LumaWellSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const LumaWellSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<LumaWellState>();
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
                l10n.lumaWellSettingsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration),
                      title: Text(l10n.lumaWellHaptics),
                      subtitle: Text(l10n.lumaWellHapticsSubtitle),
                      value: state.hapticsEnabled,
                      onChanged: state.setHapticsEnabled,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.lumaWellHelpTitle),
                      subtitle: Text(l10n.lumaWellHelpSubtitle),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LumaWellHelpPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                      ),
                      title: Text(l10n.lumaWellEasyMode),
                      subtitle: Text(l10n.lumaWellEasyModeSubtitle),
                      value: state.easyMode,
                      onChanged: state.setEasyMode,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(l10n.lumaWellCaptureTime),
                      subtitle: Text(l10n.lumaWellCaptureTimeSubtitle),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<double>(
                        segments: [
                          for (final option in const [1.0, 1.5, 2.0])
                            ButtonSegment(
                              value: option,
                              label: Text(
                                l10n.lumaWellCaptureTimeOptionSeconds(
                                  option.toStringAsFixed(1),
                                ),
                              ),
                            ),
                        ],
                        selected: {state.captureTime},
                        onSelectionChanged: (value) =>
                            state.setCaptureTime(value.first),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.pan_tool_alt_outlined),
                      title: Text(l10n.lumaWellTouchOffset),
                      subtitle: Text(l10n.lumaWellTouchOffsetSubtitle),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final direction
                              in LumaWellTouchOffsetDirection.values)
                            Tooltip(
                              message: _directionLabel(l10n, direction),
                              child: ChoiceChip(
                                label: Icon(
                                  _directionIcon(direction),
                                  size: 18,
                                ),
                                selected:
                                    state.touchOffsetDirection == direction,
                                onSelected: (_) =>
                                    state.setTouchOffsetDirection(direction),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (state.touchOffsetDirection !=
                        LumaWellTouchOffsetDirection.none)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text(l10n.lumaWellTouchOffsetDistance),
                            Expanded(
                              child: Slider(
                                value: state.touchOffsetDistance,
                                min: 0,
                                max: 120,
                                divisions: 12,
                                label: l10n.lumaWellTouchOffsetDistancePixels(
                                  state.touchOffsetDistance.round(),
                                ),
                                onChanged: (value) =>
                                    state.setTouchOffsetDistance(value),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                l10n.lumaWellTouchOffsetDistancePixels(
                                  state.touchOffsetDistance.round(),
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.all_inclusive),
                      title: Text(l10n.lumaWellUnlimitedPowers),
                      subtitle: Text(l10n.lumaWellUnlimitedPowersSubtitle),
                      value: state.unlimitedPowers,
                      onChanged: state.setUnlimitedPowers,
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
