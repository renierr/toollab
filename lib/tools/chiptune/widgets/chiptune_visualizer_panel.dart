import 'package:flutter/material.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';
import 'visualizations/chiptune_viz_registry.dart';

/// Paged visualization panel with horizontal swipe between modes.
class ChiptuneVisualizerPanel extends StatefulWidget {
  final ChiptunePlayer player;
  final String currentVizId;
  final ValueChanged<String> onVizChanged;

  const ChiptuneVisualizerPanel({
    super.key,
    required this.player,
    required this.currentVizId,
    required this.onVizChanged,
  });

  @override
  State<ChiptuneVisualizerPanel> createState() =>
      _ChiptuneVisualizerPanelState();
}

class _ChiptuneVisualizerPanelState extends State<ChiptuneVisualizerPanel> {
  late final PageController _pageController;
  bool _initialPageSet = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ChiptuneVizRegistry.indexForId(widget.currentVizId),
    );
  }

  @override
  void didUpdateWidget(ChiptuneVisualizerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentVizId != widget.currentVizId && _initialPageSet) {
      final idx = ChiptuneVizRegistry.indexForId(widget.currentVizId);
      if (idx != _pageController.page?.round()) {
        _pageController.jumpToPage(idx);
      }
    }
  }

  @override
  void dispose() {
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

    return ValueListenableBuilder<ChiptunePlaybackState>(
      valueListenable: widget.player.state,
      builder: (context, state, _) {
        if (state != ChiptunePlaybackState.playing) {
          return const SizedBox.shrink();
        }

        final width = MediaQuery.sizeOf(context).width;
        final height = (width * 6 / 16).clamp(80.0, 180.0);

        final prev = index > 0;
        final next = index < vizList.length - 1;

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
                        onPageChanged: (page) {
                          _initialPageSet = true;
                          widget.onVizChanged(vizList[page].id);
                        },
                        itemBuilder: (_, idx) =>
                            vizList[idx].create(active: true),
                      ),
                      if (multi && prev)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: _VizArrow(
                            icon: Icons.chevron_left,
                            onTap: () => _goTo(index - 1),
                          ),
                        ),
                      if (multi && next)
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
      },
    );
  }
}

class _VizArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _VizArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: IconButton(
        icon: Icon(icon),
        iconSize: 20,
        color: ChiptuneColors.visPeak.withValues(alpha: 0.6),
        style: IconButton.styleFrom(
          backgroundColor: ChiptuneColors.visualizerBg.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
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
