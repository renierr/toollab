import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import '../grocery_item.dart';

class GroceryListItemRow extends StatelessWidget {
  final GroceryItem item;
  final Function(bool?) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GroceryListItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: item.checked ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: item.checked
                ? (isDark
                      ? Colors.grey[900]!.withValues(alpha: 0.5)
                      : Colors.grey[100]!)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.checked
                  ? (isDark ? Colors.grey[850]! : Colors.grey[200]!)
                  : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
              width: 1,
            ),
            boxShadow: item.checked
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: item.checked,
                onChanged: onToggle,
                activeColor: AppTheme.accentTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.checked
                        ? (isDark ? Colors.grey[500] : Colors.grey[400])
                        : theme.colorScheme.onSurface,
                    fontWeight: item.checked
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: item.checked
                      ? Colors.transparent
                      : (isDark
                            ? AppTheme.accentTeal.withValues(alpha: 0.15)
                            : AppTheme.accentTeal.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_formatAmount(item.amount)} ${item.unit}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: item.checked
                        ? (isDark ? Colors.grey[500] : Colors.grey[400])
                        : AppTheme.accentTeal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                color: AppTheme.statusRed,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
