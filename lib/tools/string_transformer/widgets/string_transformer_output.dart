import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import '../string_transformer_state.dart';
import 'package:tool_lab/widgets/info_card.dart';

class StringTransformerOutput extends StatefulWidget {
  const StringTransformerOutput({super.key});

  @override
  State<StringTransformerOutput> createState() =>
      _StringTransformerOutputState();
}

class _StringTransformerOutputState extends State<StringTransformerOutput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<StringTransformerState>();
    _controller = TextEditingController(text: state.outputText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<StringTransformerState>();
    if (_controller.text != state.outputText) {
      _controller.text = state.outputText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String text,
    AppLocalizations l10n,
  ) async {
    try {
      await ClipboardHelper.setText(text);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.stringTransformerCopied)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.stringTransformerFailedToCopy(e.toString())),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<StringTransformerState>();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.stringTransformerOutputLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.outputText.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l10n.commonCopy,
                    onPressed: () =>
                        _copyToClipboard(context, state.outputText, l10n),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.errorMessage != null
                  ? Center(
                      child: SingleChildScrollView(
                        child: InfoCard(
                          icon: Icons.error_outline,
                          title: l10n.commonError,
                          titleColor: theme.colorScheme.error,
                          backgroundColor: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.15),
                          borderColor: theme.colorScheme.error.withValues(
                            alpha: 0.3,
                          ),
                          child: Text(
                            l10n.stringTransformerInvalidInput(
                              state.errorMessage!,
                            ),
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      readOnly: true,
                      maxLines: null,
                      minLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.stringTransformerPlaceholderOutput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.2),
                        filled: true,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n.stringTransformerCharsCount(state.outputText.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
