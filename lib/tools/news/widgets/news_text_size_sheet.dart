import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../news_state.dart';

class NewsTextSizeSheet extends StatelessWidget {
  const NewsTextSizeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const NewsTextSizeSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final percent = context.select<NewsState, int>(
      (state) => state.listFontPercent,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.newsListTextSize, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: percent <= NewsState.minFontPercent
                      ? null
                      : () => context.read<NewsState>().setListFontPercent(
                          percent - NewsState.fontStep,
                        ),
                  icon: const Icon(Icons.text_decrease),
                  tooltip: l10n.newsReaderFontSmaller,
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    NumberFormat.percentPattern(locale).format(percent / 100),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: percent >= NewsState.maxFontPercent
                      ? null
                      : () => context.read<NewsState>().setListFontPercent(
                          percent + NewsState.fontStep,
                        ),
                  icon: const Icon(Icons.text_increase),
                  tooltip: l10n.newsReaderFontLarger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
