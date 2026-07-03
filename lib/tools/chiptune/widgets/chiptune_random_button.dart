import 'package:flutter/material.dart';

/// AppBar action for random playback. Spins its dice icon while [busy]
/// (a tune fetch is in flight). When [onServerCollection] is provided, tapping
/// opens a menu to choose the source (The Mod Archive vs the user's own backend
/// collection); otherwise it is a plain button that triggers [onModArchive].
class ChiptuneRandomButton extends StatefulWidget {
  final bool busy;
  final String tooltip;
  final VoidCallback onModArchive;
  final VoidCallback? onServerCollection;
  final String modArchiveLabel;
  final String serverLabel;

  const ChiptuneRandomButton({
    super.key,
    required this.busy,
    required this.tooltip,
    required this.onModArchive,
    this.onServerCollection,
    this.modArchiveLabel = '',
    this.serverLabel = '',
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

  Widget get _dice => RotationTransition(
    turns: _controller,
    child: const Icon(Icons.casino_outlined),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.onServerCollection == null) {
      return IconButton(
        tooltip: widget.tooltip,
        onPressed: widget.onModArchive,
        icon: _dice,
      );
    }
    return PopupMenuButton<int>(
      tooltip: widget.tooltip,
      icon: _dice,
      onSelected: (value) =>
          value == 0 ? widget.onModArchive() : widget.onServerCollection!(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public_outlined),
            title: Text(widget.modArchiveLabel),
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: Text(widget.serverLabel),
          ),
        ),
      ],
    );
  }
}
