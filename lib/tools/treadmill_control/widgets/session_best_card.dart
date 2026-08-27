import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/workout/workout_colors.dart';

class SessionBestCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const SessionBestCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: TreadmillColors.amberMetric),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  );
}
