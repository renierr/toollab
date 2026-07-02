import 'package:flutter/material.dart';

/// AppBar action that starts random playback and spins its dice icon while
/// [busy] (a next-tune (pre)fetch is in flight).
class ChiptuneRandomButton extends StatefulWidget {
  final bool busy;
  final String tooltip;
  final VoidCallback onPressed;

  const ChiptuneRandomButton({
    super.key,
    required this.busy,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<ChiptuneRandomButton> createState() => _ChiptuneRandomButtonState();
}

class _ChiptuneRandomButtonState extends State<ChiptuneRandomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.busy) _controller.repeat();
  }

  @override
  void didUpdateWidget(ChiptuneRandomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.busy && _controller.isAnimating) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      icon: RotationTransition(
        turns: _controller,
        child: const Icon(Icons.casino_outlined),
      ),
    );
  }
}
