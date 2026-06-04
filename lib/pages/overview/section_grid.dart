import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_card.dart';

class SectionGrid extends StatelessWidget {
  final List<ToolModel> sectionTools;
  final int crossAxisCount;
  final bool compact;
  final double childAspectRatio;

  const SectionGrid({
    super.key,
    required this.sectionTools,
    required this.crossAxisCount,
    required this.compact,
    required this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final tool = sectionTools[index];
        return ToolCard(
          tool: tool,
          compact: compact,
          onTap: () {
            context.read<AppState>().recordToolUsage(tool.id);
            context.push(tool.route);
          },
        );
      }, childCount: sectionTools.length),
    );
  }
}
