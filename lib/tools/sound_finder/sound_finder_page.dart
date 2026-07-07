import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'sound_finder_state.dart';
import 'widgets/sf_counter_view.dart';
import 'widgets/sf_generator_view.dart';
import 'widgets/sf_mode_tabs.dart';
import 'widgets/sf_tracker_view.dart';

class SoundFinderPage extends StatefulWidget {
  const SoundFinderPage({super.key});

  @override
  State<SoundFinderPage> createState() => _SoundFinderPageState();
}

class _SoundFinderPageState extends State<SoundFinderPage>
    with DisposeCleanup<SoundFinderPage> {
  WakeLockLease? _wakeLock;

  @override
  void initState() {
    super.initState();
    final state = context.read<SoundFinderState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => state.onPageEnter());

    unawaited(
      PowerWakeLockService.acquireFull().then((lease) {
        if (mounted) {
          _wakeLock = lease;
        } else {
          unawaited(lease.release());
        }
      }),
    );

    onDispose(() => unawaited(state.onPageLeave()));
    onDispose(() {
      final lease = _wakeLock;
      _wakeLock = null;
      if (lease != null) unawaited(lease.release());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    context.read<SoundFinderState>().setNotificationText(
      title: l10n.sfToneNotificationTitle,
      text: l10n.sfToneNotificationText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final SfMode mode = context.select<SoundFinderState, SfMode>((s) => s.mode);

    final Widget view = switch (mode) {
      SfMode.tracker => const SfTrackerView(),
      SfMode.counter => const SfCounterView(),
      SfMode.generator => const SfGeneratorView(),
    };

    return ToolLayout(
      title: SoundFinderTool.config.localizedName(l10n),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SfModeTabs(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: view,
            ),
          ),
        ],
      ),
    );
  }
}
