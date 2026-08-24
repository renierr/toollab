import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../config.dart';
import '../chiptune_playback_state.dart';
import '../engine/chiptune_player.dart' as engine;

/// Floating bottom-left mini player shown whenever the shared chiptune player
/// is active (playing or paused) and the user is anywhere but the chiptune
/// tool. Expands into a compact info card with transport controls and a jump
/// back to the player page.
///
/// Lives above the app Navigator (MaterialApp.builder), which provides no
/// Overlay — so it deliberately avoids FABs, Tooltips and dialogs, and
/// navigates through the passed [router] instead of context lookups.
class ChiptuneMiniPlayer extends StatefulWidget {
  final GoRouter router;

  const ChiptuneMiniPlayer({super.key, required this.router});

  @override
  State<ChiptuneMiniPlayer> createState() => _ChiptuneMiniPlayerState();
}

class _ChiptuneMiniPlayerState extends State<ChiptuneMiniPlayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final delegate = widget.router.routerDelegate;
    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) {
        // Not .uri: it ignores pushed (imperative) routes, so the guard would
        // miss the player page when it was reached via router.push.
        final matches = delegate.currentConfiguration.matches;
        final path = matches.isEmpty ? '/' : matches.last.matchedLocation;
        final playerRoute = ChiptuneTool.config.route;
        if (path == playerRoute || path.startsWith('$playerRoute/')) {
          return const SizedBox.shrink();
        }
        final playback = context.watch<ChiptunePlaybackState>();
        return ValueListenableBuilder<engine.ChiptunePlaybackState>(
          valueListenable: playback.player.state,
          builder: (context, state, _) {
            final active =
                state == engine.ChiptunePlaybackState.playing ||
                state == engine.ChiptunePlaybackState.paused;
            if (!active) {
              _expanded = false;
              return const SizedBox.shrink();
            }
            final l10n = AppLocalizations.of(context);
            return Positioned(
              left: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_expanded) ...[
                    _MiniPlayerCard(router: widget.router),
                    const SizedBox(height: 8),
                  ],
                  _MiniPlayerButton(
                    expanded: _expanded,
                    label: l10n.chipMiniPlayerTooltip,
                    onToggle: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniPlayerButton extends StatelessWidget {
  final bool expanded;
  final String label;
  final VoidCallback onToggle;

  const _MiniPlayerButton({
    required this.expanded,
    required this.label,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.primaryContainer,
        elevation: 6,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: SizedBox(
            width: 52,
            height: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                expanded
                    ? Icons.expand_more_outlined
                    : Icons.music_note_outlined,
                key: ValueKey(expanded),
                size: 26,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerCard extends StatelessWidget {
  final GoRouter router;

  const _MiniPlayerCard({required this.router});

  static const double _maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final playback = context.watch<ChiptunePlaybackState>();
    final player = playback.player;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxWidth, minWidth: 240),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.music_note_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      player.notificationTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<Duration>(
                valueListenable: player.elapsed,
                builder: (context, elapsed, _) {
                  final total = player.totalDuration;
                  final fraction = total > Duration.zero
                      ? (elapsed.inMilliseconds / total.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        )
                      : 0.0;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 2,
                    children: [
                      LinearProgressIndicator(value: fraction, minHeight: 4),
                      Text(
                        engine.ChiptunePlayer.formatTime(elapsed, total),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder<engine.ChiptunePlaybackState>(
                valueListenable: player.state,
                builder: (context, state, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: playback.playPause,
                      icon: Icon(
                        state == engine.ChiptunePlaybackState.playing
                            ? Icons.pause_outlined
                            : Icons.play_arrow_outlined,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => playback.stop(),
                      icon: const Icon(Icons.stop_outlined),
                    ),
                    IconButton.filledTonal(
                      onPressed: playback.hasNext ? playback.skipNext : null,
                      icon: const Icon(Icons.skip_next_outlined),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  router.push(ChiptuneTool.config.route);
                },
                icon: const Icon(Icons.open_in_full_outlined, size: 16),
                label: Text(l10n.chipMiniOpenPlayer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
