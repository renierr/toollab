import 'package:material_ui/material_ui.dart';

/// Round checkbox that fills with the list color.
class TodoCheckCircle extends StatelessWidget {
  final bool checked;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const TodoCheckCircle({
    super.key,
    required this.checked,
    required this.color,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: checked,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked ? color : Colors.transparent,
              border: Border.all(
                color: checked ? color : scheme.outline,
                width: 2,
              ),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: checked ? 1 : 0,
              child: Icon(Icons.check, size: size * 0.7, color: scheme.surface),
            ),
          ),
        ),
      ),
    );
  }
}
