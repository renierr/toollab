import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import '../hex_editor_state.dart';

class StringsScanDialog extends StatefulWidget {
  final void Function(int offset) onNavigateToOffset;

  const StringsScanDialog({super.key, required this.onNavigateToOffset});

  static void show(
    BuildContext context,
    void Function(int offset) onNavigateToOffset,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          StringsScanDialog(onNavigateToOffset: onNavigateToOffset),
    );
  }

  @override
  State<StringsScanDialog> createState() => _StringsScanDialogState();
}

class _StringsScanDialogState extends State<StringsScanDialog> {
  final TextEditingController _minLenController = TextEditingController(
    text: '4',
  );

  @override
  void dispose() {
    _minLenController.dispose();
    super.dispose();
  }

  Future<void> _exportStrings(List<StringResult> results) async {
    final buffer = StringBuffer();
    for (final r in results) {
      buffer.writeln(
        '${r.offset.toRadixString(16).padLeft(8, '0').toUpperCase()}: ${r.text}',
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'strings_export.txt',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<HexEditorState>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.hexEditorStringsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!state.isScanningStrings)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!state.isScanningStrings && state.stringsResults.isEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minLenController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.hexEditorMinLength,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      final minLen = int.tryParse(_minLenController.text) ?? 4;
                      state.scanForStrings(minLen);
                    },
                    icon: const Icon(Icons.search),
                    label: Text(l10n.hexEditorScan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Center(
                child: Icon(Icons.abc, size: 80, color: Colors.grey),
              ),
              const Spacer(),
            ] else if (state.isScanningStrings) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.hexEditorScanning,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.hexEditorScannedBytes(
                        (state.scanProgress * state.totalSize)
                            .toInt()
                            .toString(),
                        state.totalSize.toString(),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => state.cancelScan(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusRed,
                      ),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.hexEditorFoundStrings(state.stringsResults.length),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _exportStrings(state.stringsResults),
                        icon: const Icon(Icons.download),
                        label: Text(l10n.commonExport),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            state.loadFile(state.filePath!, state.fileName!),
                        child: Text(l10n.commonReset),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: state.stringsResults.isEmpty
                    ? Center(
                        child: Text(
                          l10n.hexEditorNoStringsFound,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.stringsResults.length,
                        itemBuilder: (context, index) {
                          final r = state.stringsResults[index];
                          final offsetStr =
                              '0x${r.offset.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.text,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            subtitle: Text(
                              offsetStr,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            onTap: () {
                              widget.onNavigateToOffset(r.offset);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
