import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/focus_outline.dart';
import 'package:tool_lab/widgets/tool_card_normal.dart';
import 'package:tool_lab/widgets/tool_card_compact.dart';

class ToolCard extends StatelessWidget {
  final ToolModel tool;
  final VoidCallback onTap;
  final bool compact;
  final bool autofocus;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.compact = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusOutline(
      onTap: onTap,
      onLongPress: () => context.read<AppState>().toggleFavorite(tool.id),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: autofocus,
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return compact
                  ? ToolCardCompact(tool: tool, cardWidth: constraints.maxWidth)
                  : ToolCardNormal(tool: tool, cardWidth: constraints.maxWidth);
            },
          ),
        ),
      ),
    );
  }
}
