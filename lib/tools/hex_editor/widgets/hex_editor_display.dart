import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../hex_editor_state.dart';
import 'byte_edit_dialog.dart';
import 'hex_editor_row.dart';

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

    final rowTop = rowIndex * HexEditorRow.height;
    final rowBottom = rowTop + HexEditorRow.height;

    // Check if row is already fully visible (with 1 row padding margin)
    final isVisible =
        rowTop >= scrollOffset + HexEditorRow.height &&
        rowBottom <= scrollOffset + viewportHeight - HexEditorRow.height;

    if (isVisible) return;

    final targetScroll = max(
      0.0,
      rowIndex * HexEditorRow.height - viewportHeight / 2,
    );
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HexEditorState>();
    final rowCount = (state.totalSize / HexEditorRow.bytesPerRow).ceil();
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
                itemExtent: HexEditorRow.height,
                itemBuilder: (context, index) => HexEditorRow(
                  rowIndex: index,
                  rowBytes: state.getCachedRow(index),
                  totalSize: state.totalSize,
                  selectedOffset: state.selectedOffset,
                  searchMatchOffset: state.searchMatchOffset,
                  searchMatchLength: state.searchMatchLength,
                  showAscii: state.showAscii,
                  onSelect: (offset) {
                    state.setSelectedOffset(offset);
                    _highNibble = null;
                    _focusNode.requestFocus();
                  },
                  onEditByte: _editByte,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
