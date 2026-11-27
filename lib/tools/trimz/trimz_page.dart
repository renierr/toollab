import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'trimz_state.dart';
import 'widgets/trimz_browse_view.dart';
import 'widgets/trimz_search_page.dart';
import 'widgets/trimz_settings_page.dart';

class TrimzPage extends StatefulWidget {
  const TrimzPage({super.key});

  @override
  State<TrimzPage> createState() => _TrimzPageState();
}

class _TrimzPageState extends State<TrimzPage> {
  bool _started = false;

  /// Starts once the app language is known, so the first load uses it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<TrimzState>()
      ..setAppLanguage(Localizations.localeOf(context).languageCode);
    if (_started) return;
    _started = true;
    unawaited(state.init());
  }

  void _push(Widget page) => unawaited(
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TrimzState>();
    return ToolLayout(
      title: TrimzTool.config.localizedName(l10n),
      actions: [
        IconButton(
          onPressed: () => _push(const TrimzSearchPage()),
          tooltip: l10n.commonSearch,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () => unawaited(state.refresh()),
          tooltip: l10n.trimzRefresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => _push(const TrimzSettingsPage()),
          tooltip: l10n.commonSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: const TrimzBrowseView(),
    );
  }
}
