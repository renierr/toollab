import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Bottom sheet stepping a text size percent held in the provided state [S].
class TextSizeSheet<S> extends StatelessWidget {
  final String title;
  final int Function(S state) percentOf;
  final void Function(S state, int percent) onChanged;
  final int minPercent;
  final int maxPercent;
  final int step;

  const TextSizeSheet({
    super.key,
    required this.title,
    required this.percentOf,
    required this.onChanged,
    required this.minPercent,
    required this.maxPercent,
    required this.step,
  });

  static Future<void> show<S>(
    BuildContext context, {
    required String title,
    required int Function(S state) percentOf,
    required void Function(S state, int percent) onChanged,
    required int minPercent,
    required int maxPercent,
    required int step,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => TextSizeSheet<S>(
      title: title,
      percentOf: percentOf,
      onChanged: onChanged,
      minPercent: minPercent,
      maxPercent: maxPercent,
      step: step,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final percent = context.select<S, int>(percentOf);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: percent <= minPercent
                      ? null
                      : () => onChanged(context.read<S>(), percent - step),
                  icon: const Icon(Icons.text_decrease),
                  tooltip: l10n.commonDecreaseTextSize,
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
                  onPressed: percent >= maxPercent
                      ? null
                      : () => onChanged(context.read<S>(), percent + step),
                  icon: const Icon(Icons.text_increase),
                  tooltip: l10n.commonIncreaseTextSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
