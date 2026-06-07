import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/markdown_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownView extends StatelessWidget {
  final String data;
  final bool selectable;
  final Color accentColor;
  final double scale;

  const MarkdownView({
    super.key,
    required this.data,
    this.selectable = true,
    this.accentColor = AppTheme.accentBlue,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget markdownWidget = MarkdownBody(
      data: data,
      selectable: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      checkboxBuilder: (checked) =>
          MarkdownCheckbox(checked: checked, checkedColor: accentColor),
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        textScaler: TextScaler.linear(scale),
        blockquoteDecoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.blue.shade100,
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
    );

    if (selectable) {
      markdownWidget = SelectionArea(child: markdownWidget);
    }

    return markdownWidget;
  }
}
