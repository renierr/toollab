import 'package:flutter/material.dart';

class OscilloscopeHeader extends StatelessWidget {
  const OscilloscopeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(
          'SCROLLING OSCILLOSCOPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        Text(
          'TIME DOMAIN HISTORY',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
