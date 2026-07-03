import 'package:flutter/material.dart';

/// A titled section whose body can be collapsed by tapping the header.
///
/// The header shows a leading [icon], a [title], optional trailing [actions]
/// (buttons keep their own tap handling — tapping empty header space toggles),
/// and a chevron that rotates with the expanded state.
class CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final List<Widget> actions;
  final Widget child;
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.actions = const [],
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: widget.iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleSmall),
                ),
                ...widget.actions,
                AnimatedRotation(
                  turns: _expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: SizedBox(width: double.infinity, child: widget.child),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
