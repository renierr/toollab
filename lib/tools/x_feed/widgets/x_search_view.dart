import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../api/x_api.dart';
import '../x_feed_state.dart';
import '../x_timeline_controller.dart';
import 'x_timeline_view.dart';

class XSearchView extends StatefulWidget {
  final String? initialQuery;

  const XSearchView({super.key, this.initialQuery});

  @override
  State<XSearchView> createState() => _XSearchViewState();
}

class _XSearchViewState extends State<XSearchView> with DisposeCleanup {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialQuery,
  );
  XSearchProduct _product = XSearchProduct.top;
  XTimelineController? _results;
  String? _query;

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _text.dispose();
      _results?.dispose();
    });
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) _search(initial);
  }

  void _search(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    final state = context.read<XFeedState>();
    final product = _product;
    _results?.dispose();
    setState(() {
      _query = query;
      _results = state.timeline(
        (cursor) => state.api.search(query, product: product, cursor: cursor),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _results;

    return Column(
      children: [
        ReadableWidth(
          maxWidth: 680,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              children: [
                TextField(
                  controller: _text,
                  autofocus: widget.initialQuery == null,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.xFeedSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _search,
                ),
                const SizedBox(height: 8),
                SegmentedButton<XSearchProduct>(
                  segments: [
                    ButtonSegment(
                      value: XSearchProduct.top,
                      label: Text(l10n.xFeedSearchTop),
                    ),
                    ButtonSegment(
                      value: XSearchProduct.latest,
                      label: Text(l10n.xFeedSearchLatest),
                    ),
                    ButtonSegment(
                      value: XSearchProduct.media,
                      label: Text(l10n.xFeedMedia),
                    ),
                  ],
                  selected: {_product},
                  onSelectionChanged: (s) {
                    setState(() => _product = s.first);
                    final query = _query;
                    if (query != null) _search(query);
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: results == null
              ? const SizedBox.shrink()
              : XTimelineView(
                  key: ObjectKey(results),
                  controller: results,
                  emptyMessage: l10n.xFeedSearchEmpty,
                ),
        ),
      ],
    );
  }
}
