import 'package:flutter/material.dart';

class AxisBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxExpected;
  final Color activeColor;
  final bool isScanning;
  const AxisBar({
    super.key,
    required this.label,
    required this.value,
    this.maxExpected = 100.0,
    required this.activeColor,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    // Normalize value ratio between -1.0 and 1.0
    final double ratio = (value / maxExpected).clamp(-1.0, 1.0);
    final String sign = value >= 0 ? '+' : '';
    final String valueText = isScanning
        ? '$sign${value.toStringAsFixed(1)}'
        : '0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Axis label (X, Y, or Z)
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isScanning ? activeColor : Colors.grey[600],
              ),
            ),
          ),

          // Bidirectional strength bar
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final double center = width / 2;
                    final double barWidth = ratio.abs() * center;

                    return Stack(
                      children: [
                        // Center 0 line indicator
                        Center(
                          child: Container(
                            width: 1.5,
                            height: 12,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),

                        // Active colored bar
                        Positioned(
                          left: ratio < 0 ? center - barWidth : center,
                          width: barWidth > 0 ? barWidth : 0.01,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              color: isScanning
                                  ? activeColor
                                  : Colors.grey[800],
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: isScanning
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 4,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Digital numeric readout
          SizedBox(
            width: 60,
            child: Text(
              valueText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isScanning ? Colors.grey[200] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
