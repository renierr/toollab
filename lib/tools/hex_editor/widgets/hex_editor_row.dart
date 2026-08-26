import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

/// One 16-byte line of the hex dump: offset, hex cells, optional ASCII cells.
class HexEditorRow extends StatelessWidget {
  static const double height = 28.0;
  static const int bytesPerRow = 16;

  final int rowIndex;
  final List<int>? rowBytes;
  final int totalSize;
  final int? selectedOffset;
  final int? searchMatchOffset;
  final int? searchMatchLength;
  final bool showAscii;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onEditByte;

  const HexEditorRow({
    super.key,
    required this.rowIndex,
    required this.rowBytes,
    required this.totalSize,
    required this.selectedOffset,
    required this.searchMatchOffset,
    required this.searchMatchLength,
    required this.showAscii,
    required this.onSelect,
    required this.onEditByte,
  });

  static String _formatAscii(int byte) {
    if (byte < 32 || byte > 126) return '.';
    return String.fromCharCode(byte);
  }

  bool _isMatch(int offset) {
    final start = searchMatchOffset;
    final length = searchMatchLength;
    if (start == null || length == null) return false;
    return offset >= start && offset < start + length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rowOffset = rowIndex * bytesPerRow;

    final hexCells = <Widget>[];
    final asciiCells = <Widget>[];

    for (int i = 0; i < bytesPerRow; i++) {
      final cellOffset = rowOffset + i;
      if (cellOffset >= totalSize) {
        hexCells.add(
          const SizedBox(
            width: 24,
            child: Text('  ', style: TextStyle(fontFamily: 'monospace')),
          ),
        );
        asciiCells.add(const SizedBox(width: 9));
        continue;
      }

      final bytes = rowBytes;
      final byteVal = bytes != null && i < bytes.length ? bytes[i] : null;
      final byteStr = byteVal != null
          ? byteVal.toRadixString(16).padLeft(2, '0').toUpperCase()
          : '??';
      final charStr = byteVal != null ? _formatAscii(byteVal) : '.';

      final isSelected = cellOffset == selectedOffset;
      final isMatch = _isMatch(cellOffset);

      Color? bg;
      Color textColor = isDark ? Colors.white70 : Colors.black87;
      if (isSelected) {
        bg = AppTheme.accentPurple.withValues(alpha: 0.4);
        textColor = Colors.white;
      } else if (isMatch) {
        bg = AppTheme.accentAmber.withValues(alpha: 0.3);
      }

      hexCells.add(
        GestureDetector(
          onTap: () => onSelect(cellOffset),
          onDoubleTap: () => onEditByte(cellOffset),
          child: Container(
            width: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              byteStr,
              style: TextStyle(
                fontFamily: 'monospace',
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

      Color asciiTextColor = isDark ? Colors.tealAccent : Colors.teal.shade700;
      Color? asciiBg;
      if (isSelected) {
        asciiBg = AppTheme.accentPurple.withValues(alpha: 0.4);
        asciiTextColor = Colors.white;
      } else if (isMatch) {
        asciiBg = AppTheme.accentAmber.withValues(alpha: 0.3);
      }

      asciiCells.add(
        GestureDetector(
          onTap: () => onSelect(cellOffset),
          child: Container(
            width: 9,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: asciiBg,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              charStr,
              style: TextStyle(
                fontFamily: 'monospace',
                color: asciiTextColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

      // Small gap between columns, wider between the two blocks of 8.
      if (i == 7) {
        hexCells.add(const SizedBox(width: 12));
      } else if (i < bytesPerRow - 1) {
        hexCells.add(const SizedBox(width: 4));
      }
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      color: rowIndex.isEven
          ? (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.02))
          : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              rowOffset.toRadixString(16).padLeft(8, '0').toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: isDark ? AppTheme.accentPurple : Colors.purple.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const VerticalDivider(width: 24, indent: 4, endIndent: 4),
          Row(children: hexCells),
          if (showAscii) ...[
            const VerticalDivider(width: 24, indent: 4, endIndent: 4),
            Row(children: asciiCells),
          ],
        ],
      ),
    );
  }
}
