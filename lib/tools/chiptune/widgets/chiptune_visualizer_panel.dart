import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';
import 'visualizations/chiptune_viz_data.dart';
import 'visualizations/chiptune_viz_registry.dart';

/// Paged visualization panel with horizontal swipe between modes.
/// Owns a single [Ticker] + [AudioData] and distributes [VizData] to all pages.
class ChiptuneVisualizerPanel extends StatefulWidget {
  final ChiptunePlayer player;
  final String currentVizId;
  final ValueChanged<String> onVizChanged;
  final bool animate;

  const ChiptuneVisualizerPanel({
    super.key,
    required this.player,
    required this.currentVizId,
    required this.onVizChanged,
    this.animate = true,
  });

  @override
  State<ChiptuneVisualizerPanel> createState() =>
      _ChiptuneVisualizerPanelState();
}

class _ChiptuneVisualizerPanelState extends State<ChiptuneVisualizerPanel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final Ticker _ticker;

  AudioData? _audioData;
  VizData? _latestData;

  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ChiptuneVizRegistry.indexForId(widget.currentVizId),
    );
    _ticker = createTicker(_onTick);
    widget.player.state.addListener(_onStateChanged);
    _updateTicker();
  }

  void _onStateChanged() {
    _updateTicker();
  }

  void _updateTicker() {
    final shouldPlay =
        widget.player.state.value == ChiptunePlaybackState.playing &&
        widget.animate;
    if (shouldPlay) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      _lastElapsed = Duration.zero;
      if (widget.player.state.value != ChiptunePlaybackState.playing) {
        _latestData = null;
      }
      if (mounted) setState(() {});
    }
  }

  void _ensureAudioData() {
    if (_audioData != null) return;
    try {
      SoLoud.instance.setVisualizationEnabled(true);
      _audioData = AudioData(GetSamplesKind.linear);
    } catch (_) {
      _audioData = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    _ensureAudioData();
    final ad = _audioData;
    if (ad == null) return;

    try {
      ad.updateSamples();
      final all = ad.getAudioData();
      if (all.length < 512) return;

      final freq = <double>[];
      double bassSum = 0;
      for (int i = 0; i < 256; i++) {
        final v = all[i].clamp(0.0, 1.0);
        freq.add(v);
        if (i < 16) bassSum += v;
      }

      final wave = <double>[];
      for (int i = 0; i < 256; i++) {
        wave.add(all[256 + i]);
      }

      _latestData = VizData(
        freq: freq,
        wave: wave,
        bass: bassSum / 16,
        deltaTime: dt,
      );

      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didUpdateWidget(ChiptuneVisualizerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentVizId != widget.currentVizId) {
      final idx = ChiptuneVizRegistry.indexForId(widget.currentVizId);
      if (idx != _pageController.page?.round()) {
        _pageController.jumpToPage(idx);
      }
    }
    if (oldWidget.animate != widget.animate) {
      _updateTicker();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.player.state.removeListener(_onStateChanged);
    _audioData?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int get _currentIndex => ChiptuneVizRegistry.indexForId(widget.currentVizId);

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vizList = ChiptuneVizRegistry.all;
    if (vizList.isEmpty) return const SizedBox.shrink();
    final multi = vizList.length > 1;
    final index = _currentIndex;
    final data = _latestData;

    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 6 / 16).clamp(80.0, 180.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: ChiptuneColors.visualizerBg,
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: vizList.length,
                    onPageChanged: (page) =>
                        widget.onVizChanged(vizList[page].id),
                    itemBuilder: (_, idx) => vizList[idx].create(
                      data: data,
                      key: ValueKey(vizList[idx].id),
                    ),
                  ),
                  if (index > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _VizArrow(
                        icon: Icons.chevron_left,
                        onTap: () => _goTo(index - 1),
                      ),
                    ),
                  if (index < vizList.length - 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _VizArrow(
                        icon: Icons.chevron_right,
                        onTap: () => _goTo(index + 1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (multi) ...[
          const SizedBox(height: 6),
          Text(
            vizList[index].label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: ChiptuneColors.visPeak),
          ),
          const SizedBox(height: 2),
          _PageDots(count: vizList.length, currentIndex: index),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _VizArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _VizArrow({required this.icon, required this.onTap});

  @override
  State<_VizArrow> createState() => _VizArrowState();
}

class _VizArrowState extends State<_VizArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final alpha = (_hovered ? 0.9 : 0.4);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 36,
        child: IconButton(
          icon: Icon(widget.icon),
          iconSize: 20,
          color: ChiptuneColors.visPeak.withValues(alpha: alpha),
          style: IconButton.styleFrom(
            backgroundColor: ChiptuneColors.visualizerBg.withValues(alpha: 0.5),
            shape: const RoundedRectangleBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: widget.onTap,
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _PageDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? ChiptuneColors.visPeak
                : ChiptuneColors.visPeak.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}
