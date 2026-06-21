import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/theme/theme.dart';
import '../hex_editor_state.dart';
import 'byte_edit_dialog.dart';

class HexEditorDisplay extends StatefulWidget {
  final ScrollController scrollController;

  const HexEditorDisplay({super.key, required this.scrollController});

  @override
  State<HexEditorDisplay> createState() => _HexEditorDisplayState();
}

class _HexEditorDisplayState extends State<HexEditorDisplay> {
  final FocusNode _focusNode = FocusNode();
  late final ScrollController _horizontalScrollController;
  int? _highNibble;

  static const double _rowHeight = 28.0;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final state = context.read<HexEditorState>();
    final selected = state.selectedOffset;
    if (selected == null) return false;

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.arrowRight) {
      state.setSelectedOffset(min(state.totalSize - 1, selected + 1));
      _highNibble = null;
      _scrollToOffset(state.selectedOffset!);
      return true;
    } else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      state.setSelectedOffset(max(0, selected - 1));
      _highNibble = null;
      _scrollToOffset(state.selectedOffset!);
      return true;
    } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
      state.setSelectedOffset(min(state.totalSize - 1, selected + 16));
      _highNibble = null;
      _scrollToOffset(state.selectedOffset!);
      return true;
    } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
      state.setSelectedOffset(max(0, selected - 16));
      _highNibble = null;
      _scrollToOffset(state.selectedOffset!);
      return true;
    } else if (logicalKey == LogicalKeyboardKey.enter) {
      _editByte(selected);
      return true;
    } else {
      // Handle hex typing (0-9, a-f)
      final char = event.character?.toLowerCase() ?? '';
      if (RegExp(r'^[0-9a-f]$').hasMatch(char)) {
        final val = int.parse(char, radix: 16);
        if (_highNibble == null) {
          _highNibble = val;
          // Temporarily overlay value with high nibble only
          state.setByte(selected, val << 4);
        } else {
          final finalVal = (_highNibble! << 4) | val;
          state.setByte(selected, finalVal);
          _highNibble = null;
          // Advance cursor to next byte
          if (selected < state.totalSize - 1) {
            state.setSelectedOffset(selected + 1);
            _scrollToOffset(state.selectedOffset!);
          }
        }
        return true;
      }
    }
    return false;
  }

  void _scrollToOffset(int offset) {
    if (!widget.scrollController.hasClients) return;
    final rowIndex = offset ~/ 16;
    final scrollOffset = widget.scrollController.offset;
    final viewportHeight = widget.scrollController.position.viewportDimension;

    final rowTop = rowIndex * _rowHeight;
    final rowBottom = rowTop + _rowHeight;

    // Check if row is already fully visible (with 1 row padding margin)
    final isVisible =
        rowTop >= scrollOffset + _rowHeight &&
        rowBottom <= scrollOffset + viewportHeight - _rowHeight;

    if (isVisible) return;

    final targetScroll = max(0.0, rowIndex * _rowHeight - viewportHeight / 2);
    widget.scrollController.jumpTo(targetScroll);
  }

  void _editByte(int offset) async {
    final state = context.read<HexEditorState>();
    final manager = state.bufferManager;
    if (manager == null) return;

    final initial = await manager.getByte(offset);
    if (!mounted) return;

    final newVal = await ByteEditDialog.show(
      context: context,
      offset: offset,
      initialValue: initial,
    );

    if (newVal != null && mounted) {
      state.setByte(offset, newVal);
    }
    _focusNode.requestFocus();
  }

  String _formatAscii(int byte) {
    if (byte < 32 || byte > 126) return '.';
    return String.fromCharCode(byte);
  }

  Widget _buildRow(BuildContext context, int rowIndex, HexEditorState state) {
    final rowOffset = rowIndex * 16;
    final rowBytes = state.getCachedRow(rowIndex);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final offsetText = rowOffset
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();

    // 16 cells for hex bytes and ASCII characters
    final List<Widget> hexCells = [];
    final List<Widget> asciiCells = [];

    for (int i = 0; i < 16; i++) {
      final cellOffset = rowOffset + i;
      if (cellOffset >= state.totalSize) {
        hexCells.add(
          const SizedBox(
            width: 24,
            child: Text('  ', style: TextStyle(fontFamily: 'monospace')),
          ),
        );
        asciiCells.add(const SizedBox(width: 9));
        continue;
      }

      final byteVal = rowBytes != null && i < rowBytes.length
          ? rowBytes[i]
          : null;
      final byteStr = byteVal != null
          ? byteVal.toRadixString(16).padLeft(2, '0').toUpperCase()
          : '??';
      final charStr = byteVal != null ? _formatAscii(byteVal) : '.';

      final isSelected = cellOffset == state.selectedOffset;
      final isMatch =
          state.searchMatchOffset != null &&
          cellOffset >= state.searchMatchOffset! &&
          cellOffset < state.searchMatchOffset! + state.searchMatchLength!;

      Color? bg;
      Color textStyleColor = isDark ? Colors.white70 : Colors.black87;

      if (isSelected) {
        bg = AppTheme.accentPurple.withValues(alpha: 0.4);
        textStyleColor = Colors.white;
      } else if (isMatch) {
        bg = AppTheme.accentAmber.withValues(alpha: 0.3);
      }

      hexCells.add(
        GestureDetector(
          onTap: () {
            state.setSelectedOffset(cellOffset);
            _highNibble = null;
            _focusNode.requestFocus();
          },
          onDoubleTap: () => _editByte(cellOffset),
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
                color: textStyleColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

      // ASCII cells
      Color asciiTextStyleColor = isDark
          ? Colors.tealAccent
          : Colors.teal.shade700;
      Color? asciiBg;
      if (isSelected) {
        asciiBg = AppTheme.accentPurple.withValues(alpha: 0.4);
        asciiTextStyleColor = Colors.white;
      } else if (isMatch) {
        asciiBg = AppTheme.accentAmber.withValues(alpha: 0.3);
      }

      asciiCells.add(
        GestureDetector(
          onTap: () {
            state.setSelectedOffset(cellOffset);
            _highNibble = null;
            _focusNode.requestFocus();
          },
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
                color: asciiTextStyleColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

      // Add small gap between columns, and extra space between blocks of 8
      if (i == 7) {
        hexCells.add(const SizedBox(width: 12));
      } else if (i < 15) {
        hexCells.add(const SizedBox(width: 4));
      }
    }

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      color: rowIndex % 2 == 0
          ? (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.02))
          : Colors.transparent,
      child: Row(
        children: [
          // Offset
          SizedBox(
            width: 75,
            child: Text(
              offsetText,
              style: TextStyle(
                fontFamily: 'monospace',
                color: isDark ? AppTheme.accentPurple : Colors.purple.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const VerticalDivider(width: 24, indent: 4, endIndent: 4),
          // Hex representation
          Row(children: hexCells),
          if (state.showAscii) ...[
            const VerticalDivider(width: 24, indent: 4, endIndent: 4),
            // ASCII representation
            Row(children: asciiCells),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HexEditorState>();
    final rowCount = (state.totalSize / 16).ceil();
    final tableWidth = state.showAscii ? 760.0 : 600.0;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          final handled = _handleKeyEvent(event);
          return handled ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        autofocus: true,
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: ListView.builder(
                controller: widget.scrollController,
                itemCount: rowCount,
                itemExtent: _rowHeight,
                itemBuilder: (context, index) =>
                    _buildRow(context, index, state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
