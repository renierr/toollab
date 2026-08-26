import 'package:flutter/material.dart';

class PdfRedactOverlay extends StatefulWidget {
  final List<Rect> marks;
  final double dispLeft;
  final double dispTop;
  final double dispW;
  final double dispH;
  final ValueChanged<int> onDeleteMark;
  final ValueChanged<Rect> onNewMark;
  final bool isDrawing;

  const PdfRedactOverlay({
    super.key,
    required this.marks,
    required this.dispLeft,
    required this.dispTop,
    required this.dispW,
    required this.dispH,
    required this.onDeleteMark,
    required this.onNewMark,
    this.isDrawing = false,
  });

  @override
  State<PdfRedactOverlay> createState() => _PdfRedactOverlayState();
}

class _PdfRedactOverlayState extends State<PdfRedactOverlay> {
  Offset? _dragStart;
  Offset? _dragEnd;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragEnd = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragEnd = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final start = _dragStart;
    final end = _dragEnd;
    if (start == null || end == null) {
      _dragStart = null;
      _dragEnd = null;
      return;
    }

    final fx1 = (start.dx - widget.dispLeft) / widget.dispW;
    final fy1 = (start.dy - widget.dispTop) / widget.dispH;
    final fx2 = (end.dx - widget.dispLeft) / widget.dispW;
    final fy2 = (end.dy - widget.dispTop) / widget.dispH;

    final left = fx1.clamp(0.0, 1.0);
    final top = fy1.clamp(0.0, 1.0);
    final right = fx2.clamp(0.0, 1.0);
    final bottom = fy2.clamp(0.0, 1.0);

    final mark = Rect.fromLTRB(
      left < right ? left : right,
      top < bottom ? top : bottom,
      left < right ? right : left,
      top < bottom ? bottom : top,
    );

    if (mark.width > 0.008 && mark.height > 0.008) {
      widget.onNewMark(mark);
    }

    setState(() {
      _dragStart = null;
      _dragEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.isDrawing)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: const SizedBox.expand(),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _MarkPainter(
                marks: widget.marks,
                dispLeft: widget.dispLeft,
                dispTop: widget.dispTop,
                dispW: widget.dispW,
                dispH: widget.dispH,
              ),
            ),
          ),
        ),
        for (int i = 0; i < widget.marks.length; i++)
          _MarkDeleteButton(
            mark: widget.marks[i],
            dispLeft: widget.dispLeft,
            dispTop: widget.dispTop,
            dispW: widget.dispW,
            dispH: widget.dispH,
            onDelete: () => widget.onDeleteMark(i),
          ),
        if (_dragStart != null && _dragEnd != null)
          _DragRect(start: _dragStart!, end: _dragEnd!),
      ],
    );
  }
}

class _MarkDeleteButton extends StatelessWidget {
  static const _size = 24.0;

  final Rect mark;
  final double dispLeft;
  final double dispTop;
  final double dispW;
  final double dispH;
  final VoidCallback onDelete;

  const _MarkDeleteButton({
    required this.mark,
    required this.dispLeft,
    required this.dispTop,
    required this.dispW,
    required this.dispH,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: dispLeft + mark.right * dispW,
      top: dispTop + mark.top * dispH - _size / 2,
      width: _size,
      height: _size,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: onDelete,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DragRect extends StatelessWidget {
  final Offset start;
  final Offset end;

  const _DragRect({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: start.dx < end.dx ? start.dx : end.dx,
      top: start.dy < end.dy ? start.dy : end.dy,
      width: (start.dx - end.dx).abs(),
      height: (start.dy - end.dy).abs(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final List<Rect> marks;
  final double dispLeft;
  final double dispTop;
  final double dispW;
  final double dispH;

  _MarkPainter({
    required this.marks,
    required this.dispLeft,
    required this.dispTop,
    required this.dispW,
    required this.dispH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final mark in marks) {
      final r = Rect.fromLTRB(
        dispLeft + mark.left * dispW,
        dispTop + mark.top * dispH,
        dispLeft + mark.right * dispW,
        dispTop + mark.bottom * dispH,
      );
      canvas.drawRect(r, fillPaint);
      canvas.drawRect(r, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.marks != marks;
}
