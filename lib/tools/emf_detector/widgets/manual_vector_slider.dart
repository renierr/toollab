import 'package:flutter/material.dart';
import '../emf_colors.dart';

class ManualVectorSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const ManualVectorSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(fontSize: 9, color: EmfColors.inkMuted),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: EmfColors.amberYellow.withValues(alpha: 0.7),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.04),
                thumbColor: EmfColors.amberYellow,
                trackHeight: 1.5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 4.5,
                ),
              ),
              child: Slider(
                value: value.clamp(-150.0, 150.0),
                min: -150.0,
                max: 150.0,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(0),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: EmfColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
