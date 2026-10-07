import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/paperless_document.dart';
import '../paperless_state.dart';
import 'paperless_document_tile.dart';
import 'paperless_error_view.dart';
import 'paperless_filter_sheet.dart';
import 'paperless_search_bar.dart';

class PaperlessDocumentsView extends StatefulWidget {
  final ValueChanged<PaperlessDocument> onSelect;

  const PaperlessDocumentsView({super.key, required this.onSelect});

  @override
  State<PaperlessDocumentsView> createState() => _PaperlessDocumentsViewState();
}

class _PaperlessDocumentsViewState extends State<PaperlessDocumentsView>
    with DisposeCleanup {
  static const _searchDebounce = Duration(milliseconds: 400);
  static const _loadMoreThreshold = 600.0;

  final _scroll = ScrollController();
  late final TextEditingController _search;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<PaperlessState>().filter.text,
    );
    _scroll.addListener(_onScroll);
    onDispose(() {
      _debounce?.cancel();
      _scroll.dispose();
      _search.dispose();
    });
  }

  void _onScroll() {
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<PaperlessState>().loadMoreDocuments();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      final state = context.read<PaperlessState>();
      state.setFilter(state.filter.copyWith(text: text));
    });
  }

  Future<void> _openFilters() async {
    final state = context.read<PaperlessState>();
    final result = await PaperlessFilterSheet.show(context, state.filter);
    if (result != null) state.setFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<PaperlessState>();
    final documents = state.documents;
    final showFooter =
        documents.isNotEmpty &&
        (state.hasMoreDocuments || state.loadMoreError != null);

    final Widget body;
    if (documents.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: state.isLoadingDocuments
                  ? const CircularProgressIndicator()
                  : state.documentsError != null
                  ? PaperlessErrorView(
                      error: state.documentsError!,
                      onRetry: state.refreshDocuments,
                    )
                  : Text(l10n.paperlessNoDocuments),
            ),
          ),
        ],
      );
    } else {
      body = ReadableWidth(
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: documents.length + (showFooter ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == documents.length) {
              return _LoadMoreFooter(
                failed: state.loadMoreError != null,
                onRetry: state.loadMoreDocuments,
              );
            }
            final document = documents[index];
            return PaperlessDocumentTile(
              key: ValueKey(document.id),
              document: document,
              onTap: () => widget.onSelect(document),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        PaperlessSearchBar(
          controller: _search,
          onChanged: _onSearchChanged,
          sort: state.filter.sort,
          onSortChanged: (sort) =>
              state.setFilter(state.filter.copyWith(sort: sort)),
          activeFilters: state.filter.activeCount,
          onOpenFilters: _openFilters,
          resultCount: state.isLoadingDocuments && documents.isEmpty
              ? null
              : state.documentCount,
        ),
        if (state.isLoadingDocuments && documents.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                Future.wait([state.refreshDocuments(), state.loadLabels()]),
            child: body,
          ),
        ),
      ],
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;

  const _LoadMoreFooter({required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: failed
            ? OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
              )
            : const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}
