import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

class DepotSectionLink<T> {
  final T id;
  final String label;
  final IconData? icon;

  const DepotSectionLink({required this.id, required this.label, this.icon});
}

/// A scrolling row of jump links to the sections of a long view.
class DepotSectionNav<T> extends StatelessWidget {
  final List<DepotSectionLink<T>> links;
  final T? active;
  final ValueChanged<T> onSelect;

  const DepotSectionNav({
    super.key,
    required this.links,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: links.length,
      separatorBuilder: (_, _) => const SizedBox(width: 4),
      itemBuilder: (context, index) {
        final link = links[index];
        return Center(
          child: ToolChip(
            icon: link.icon,
            label: link.label,
            selected: link.id == active,
            onTap: () => onSelect(link.id),
          ),
        );
      },
    ),
  );
}
