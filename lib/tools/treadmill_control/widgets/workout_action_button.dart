import 'package:flutter/material.dart';

/// Outlined session control button — colored border and label, no bright fill,
/// to reduce OLED brightness/burn-in during long sessions.
class WorkoutActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double minWidth;

  const WorkoutActionButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.minWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: Size(minWidth, 50),
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
