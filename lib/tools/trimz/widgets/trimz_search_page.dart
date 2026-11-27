import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../trimz_state.dart';
import 'trimz_message_view.dart';
import 'trimz_series_grid.dart';

class TrimzSearchPage extends StatefulWidget {
  const TrimzSearchPage({super.key});

  @override
  State<TrimzSearchPage> createState() => _TrimzSearchPageState();
}

class _TrimzSearchPageState extends State<TrimzSearchPage> with DisposeCleanup {
  static const Duration _debounce = Duration(milliseconds: 450);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final state = context.read<TrimzState>();
    _controller.text = state.query;
    onDispose(() {
      _timer?.cancel();
      _controller.dispose();
      state.clearSearch();
    });
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _search(text));
  }

  void _search(String text) {
    _timer?.cancel();
    unawaited(context.read<TrimzState>().search(text));
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 600) {
      unawaited(context.read<TrimzState>().searchMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TrimzState>();
    final results = state.results;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.trimzSearchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _search,
        ),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.commonClear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
          ),
        ],
      ),
      body: results.isEmpty
          ? switch ((
              state.query.isEmpty,
              state.searching,
              state.searchFailed,
            )) {
              (true, _, _) => TrimzMessageView(
                icon: Icons.search,
                message: l10n.trimzSearchPrompt,
              ),
              (_, true, _) => const Center(child: CircularProgressIndicator()),
              (_, _, true) => TrimzMessageView(
                icon: Icons.cloud_off_outlined,
                message: l10n.trimzLoadFailed,
                onRetry: () => _search(state.query),
              ),
              _ => TrimzMessageView(
                icon: Icons.search_off,
                message: l10n.trimzNoResults(state.query),
              ),
            }
          : NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  TrimzSeriesGrid(items: results),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: state.searching
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
