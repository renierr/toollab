import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../sound_finder_state.dart';

/// Shown when the mic is unavailable or denied. On unsupported platforms it
/// nudges the user toward the generator; on denial it retries permission.
class SfPermissionNotice extends StatelessWidget {
  final MicStatus status;

  const SfPermissionNotice({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool denied = status == MicStatus.denied;

    return InfoCard(
      icon: denied
          ? Icons.mic_off_outlined
          : Icons.desktop_access_disabled_outlined,
      title: denied ? l10n.sfMicDeniedTitle : l10n.sfMicUnavailableTitle,
      titleColor: AppTheme.statusAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(denied ? l10n.sfMicDeniedBody : l10n.sfMicUnavailableBody),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: denied
                ? FilledButton.tonalIcon(
                    onPressed: () =>
                        context.read<SoundFinderState>().ensureMic(),
                    icon: const Icon(Icons.mic_outlined),
                    label: Text(l10n.sfGrantPermission),
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => context.read<SoundFinderState>().setMode(
                      SfMode.generator,
                    ),
                    icon: const Icon(Icons.tune_outlined),
                    label: Text(l10n.sfOpenGenerator),
                  ),
          ),
        ],
      ),
    );
  }
}
