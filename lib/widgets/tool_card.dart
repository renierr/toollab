import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';

class ToolCard extends StatelessWidget {
  final ToolModel tool;
  final VoidCallback onTap;

  const ToolCard({super.key, required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tool.accentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, size: 32, color: tool.accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                tool.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  tool.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
