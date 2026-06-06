import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;

class InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Map<String, String> items;

  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withAlpha(240),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            top: BorderSide(color: accentColor.withAlpha(80), width: 1.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Items List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  color: theme.colorScheme.onSurface.withAlpha(15),
                  height: 16,
                ),
                itemBuilder: (context, index) {
                  final key = items.keys.elementAt(index);
                  final value = items.values.elementAt(index);
                  return shared.InfoRow(label: key, value: value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
