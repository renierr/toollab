import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../news_catalog.dart';
import '../news_l10n.dart';
import '../news_source.dart';
import '../news_state.dart';

class NewsSourceEditDialog extends StatefulWidget {
  final NewsSource source;

  const NewsSourceEditDialog({super.key, required this.source});

  static Future<bool?> show(BuildContext context, NewsSource source) {
    return showDialog<bool>(
      context: context,
      builder: (_) => NewsSourceEditDialog(source: source),
    );
  }

  @override
  State<NewsSourceEditDialog> createState() => _NewsSourceEditDialogState();
}

class _NewsSourceEditDialogState extends State<NewsSourceEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late String _category;
  late bool _enabled;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.source.title);
    _url = TextEditingController(text: widget.source.feedUrl);
    _category = widget.source.category.isEmpty
        ? NewsCatalog.customCategory
        : widget.source.category;
    _enabled = widget.source.enabled;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<NewsState>();
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = l10n.newsSourceRequired);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.isEmpty) {
      setState(() => _error = l10n.newsSourceInvalidUrl);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final existing = await state.sourceByFeedUrl(url);
    if (!mounted) return;
    if (existing != null && existing.shortId != widget.source.shortId) {
      setState(() {
        _busy = false;
        _error = l10n.newsSourceExists;
      });
      return;
    }
    final title = _title.text.trim();
    await state.updateSource(
      widget.source.copyWith(
        title: title.isEmpty ? widget.source.title : title,
        feedUrl: url,
        category: _category,
        enabled: _enabled,
      ),
      feedChanged: url != widget.source.feedUrl,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.newsEditSource),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: l10n.newsSourceName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.newsSourceUrl,
                hintText: l10n.newsSourceUrlHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.newsSourceCategory,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final category in NewsCatalog.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(newsCategoryLabel(l10n, category.id)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.newsSourceEnabled),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
