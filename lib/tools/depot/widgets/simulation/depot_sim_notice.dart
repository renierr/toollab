import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/theme/theme.dart';

class DepotSimNotice extends StatelessWidget {
  final String text;
  final bool warning;

  const DepotSimNotice({super.key, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning ? AppTheme.statusAmber : theme.hintColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: warning ? null : theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
