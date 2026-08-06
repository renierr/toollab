import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FileManagerFileDropZone extends StatefulWidget {
  final bool enabled;
  final Widget child;
  final Future<void> Function(List<String> paths, bool chooseAction) onDrop;

  const FileManagerFileDropZone({
    super.key,
    required this.enabled,
    required this.child,
    required this.onDrop,
  });

  @override
  State<FileManagerFileDropZone> createState() =>
      _FileManagerFileDropZoneState();
}

class _FileManagerFileDropZoneState extends State<FileManagerFileDropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Never swap the subtree on enable/disable — that recreates the child's
    // scroll position and drops the list scroll offset mid-operation.
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        final paths = details.files
            .map((file) => file.path)
            .where((path) => path.isNotEmpty)
            .toList();
        if (paths.isEmpty) return;
        await widget.onDrop(paths, HardwareKeyboard.instance.isShiftPressed);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(
            color: _dragging && widget.enabled
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
