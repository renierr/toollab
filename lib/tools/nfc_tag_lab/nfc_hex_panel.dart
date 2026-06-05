import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NfcHexPanel extends StatefulWidget {
  final String generatedHex;
  final Function(String hex) onParseHex;

  const NfcHexPanel({
    super.key,
    required this.generatedHex,
    required this.onParseHex,
  });

  @override
  State<NfcHexPanel> createState() => _NfcHexPanelState();
}

class _NfcHexPanelState extends State<NfcHexPanel> {
  final TextEditingController _hexInputController = TextEditingController();

  @override
  void dispose() {
    _hexInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NDEF Hex Inspector',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Validate, parse, or generate raw NDEF hex codes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 16),
            // Paste Hex section
            TextField(
              controller: _hexInputController,
              maxLines: 3,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              decoration: const InputDecoration(
                labelText: 'Paste NDEF Hex Data',
                hintText: 'D1 01 0B 55 04 65 78 61 6D 70 6C 65 2E 63 6F 6D...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _hexInputController.clear();
                    },
                    child: const Text('Clear Input'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final hex = _hexInputController.text.trim();
                      if (hex.isNotEmpty) {
                        widget.onParseHex(hex);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please paste some NDEF hex data to parse.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Parse Hex'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.generatedHex.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generated NDEF Hex',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: 'Copy Generated Hex',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.generatedHex),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Generated NDEF Hex copied to clipboard.',
                          ),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withAlpha(20),
                  ),
                ),
                child: Text(
                  widget.generatedHex,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
