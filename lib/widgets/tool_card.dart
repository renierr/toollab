import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/widgets/tool_card_normal.dart';
import 'package:tool_lab/widgets/tool_card_compact.dart';

class ToolCard extends StatelessWidget {
  final ToolModel tool;
  final VoidCallback onTap;
  final bool compact;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return compact
                ? ToolCardCompact(tool: tool, cardWidth: constraints.maxWidth)
                : ToolCardNormal(tool: tool, cardWidth: constraints.maxWidth);
          },
        ),
      ),
    );
  }
}
