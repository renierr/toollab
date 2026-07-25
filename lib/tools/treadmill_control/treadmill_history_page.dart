import 'package:flutter/material.dart';
import '../../widgets/tool_layout.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/session_history_dashboard.dart';
import 'widgets/session_history_list.dart';

class TreadmillHistoryPage extends StatelessWidget {
  const TreadmillHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: ToolLayout(
        title: l10n.historyTitle,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l10n.treadmillHistoryDashboard),
                Tab(text: l10n.treadmillHistoryWorkouts),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [SessionHistoryDashboard(), SessionHistoryList()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
