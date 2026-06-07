import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class BubbleLevelRuler extends StatelessWidget {
  final bool visible;
  final double pixelsPerMm;

  const BubbleLevelRuler({
    super.key,
    required this.visible,
    required this.pixelsPerMm,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 64,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(240),
            border: Border(
              right: BorderSide(color: Colors.grey.shade700, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: ClipRect(
            child: CustomPaint(
              painter: _RulerPainter(pixelsPerMm: pixelsPerMm),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double pixelsPerMm;

  _RulerPainter({required this.pixelsPerMm});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1cm = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;
    final paint5mm = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.2;
    final paint1mm = Paint()
      ..color = Colors.black38
      ..strokeWidth = 0.8;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final cmPx = pixelsPerMm * 10;
    if (cmPx < 1) return;

    final tickRight1cm = 44.0;
    final tickRight5mm = 30.0;
    final tickRight1mm = 20.0;
    final numLeft = 48.0;

    var cm = 0;
    for (var y = 0.0; y < size.height; y += cmPx) {
      canvas.drawLine(Offset(0, y), Offset(tickRight1cm, y), paint1cm);

      textPainter.text = TextSpan(
        text: '$cm',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(numLeft, y - textPainter.height / 2));

      final mmPx = cmPx / 10;
      for (var mm = 1; mm <= 10; mm++) {
        final my = y + mm * mmPx;
        if (my > size.height) break;
        final right = mm % 5 == 0 ? tickRight5mm : tickRight1mm;
        canvas.drawLine(
          Offset(0, my),
          Offset(right, my),
          mm % 5 == 0 ? paint5mm : paint1mm,
        );
      }

      canvas.drawLine(
        Offset(0, 0),
        Offset(0, size.height),
        Paint()
          ..color = Colors.grey.shade700
          ..strokeWidth = 1.5,
      );
      cm++;
    }

    textPainter.text = TextSpan(
      text: 'cm',
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(numLeft, 6));
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pixelsPerMm != pixelsPerMm;
}

class RulerCalibrationDialog extends StatefulWidget {
  final double initialPxPerMm;
  final ValueChanged<double>? onChanged;

  const RulerCalibrationDialog({
    super.key,
    required this.initialPxPerMm,
    this.onChanged,
  });

  @override
  State<RulerCalibrationDialog> createState() => _RulerCalibrationDialogState();
}

class _RulerCalibrationDialogState extends State<RulerCalibrationDialog> {
  late double _pxPerMm;

  @override
  void initState() {
    super.initState();
    _pxPerMm = widget.initialPxPerMm;
  }

  void _setValue(double v) {
    setState(() => _pxPerMm = v.clamp(1.0, 10.0));
    widget.onChanged?.call(_pxPerMm);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResponsiveAlertDialog(
      title: Text(
        'Ruler Calibration',
        style: TextStyle(color: theme.colorScheme.primary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hold a physical ruler against the screen edge. Adjust the scale until the markings match exactly.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '${(_pxPerMm * 25.4).round()} DPI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_pxPerMm.toStringAsFixed(2)} px/mm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _RoundButton(
                  label: '−',
                  onTap: () => _setValue(_pxPerMm - 0.05),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Slider(
                      value: _pxPerMm,
                      min: 1.0,
                      max: 10.0,
                      divisions: 900,
                      onChanged: _setValue,
                    ),
                  ),
                ),
                _RoundButton(
                  label: '+',
                  onTap: () => _setValue(_pxPerMm + 0.05),
                ),
              ],
            ),
            SizedBox(
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _RulerPreviewPainter(pxPerMm: _pxPerMm),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_pxPerMm),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RoundButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withAlpha(20),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPreviewPainter extends CustomPainter {
  final double pxPerMm;

  _RulerPreviewPainter({required this.pxPerMm});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    final cmPx = pxPerMm * 10;
    if (cmPx < 1) return;

    final count = (size.height / cmPx).ceil();
    for (var i = 0; i <= count; i++) {
      final y = i * cmPx;
      if (y > size.height) break;
      canvas.drawLine(Offset(0, y), Offset(36, y), paint);
      if (i < count) {
        final mmPx = cmPx / 10;
        for (var mm = 1; mm < 10; mm++) {
          final my = y + mm * mmPx;
          if (my > size.height) break;
          final right = mm % 5 == 0 ? 26.0 : 16.0;
          canvas.drawLine(
            Offset(0, my),
            Offset(right, my),
            paint..strokeWidth = mm % 5 == 0 ? 1.2 : 0.6,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPreviewPainter old) => old.pxPerMm != pxPerMm;
}
