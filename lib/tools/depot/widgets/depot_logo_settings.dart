import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_logo_state.dart';

class DepotLogoSettings extends StatelessWidget {
  const DepotLogoSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotLogoState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(
          title: l10n.depotLogosTitle,
          description: l10n.depotLogosDescription,
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(l10n.depotLogosDownload),
          subtitle: Text(
            state.isFetching
                ? l10n.depotLogosProgress(state.completed, state.total)
                : state.loadFailed
                ? l10n.depotLogosCacheError
                : state.failed > 0
                ? l10n.depotLogosFailed(state.failed)
                : l10n.depotLogosCached(state.cachedCount),
          ),
          trailing: state.isFetching
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          onTap: state.isFetching
              ? null
              : () => context.read<DepotLogoState>().downloadMissing(),
        ),
      ],
    );
  }
}
