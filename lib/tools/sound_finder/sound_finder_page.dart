import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'sound_finder_state.dart';
import 'widgets/sf_clip_recorder.dart';
import 'widgets/sf_counter_view.dart';
import 'widgets/sf_gain_control.dart';
import 'widgets/sf_generator_view.dart';
import 'widgets/sf_mic_selector.dart';
import 'widgets/sf_mode_tabs.dart';
import 'widgets/sf_tracker_view.dart';

class SoundFinderPage extends StatefulWidget {
  const SoundFinderPage({super.key});

  @override
  State<SoundFinderPage> createState() => _SoundFinderPageState();
}

class _SoundFinderPageState extends State<SoundFinderPage>
    with DisposeCleanup<SoundFinderPage>, WidgetsBindingObserver {
  WakeLockLease? _wakeLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(() => unawaited(state.onPageLeave()));
    onDispose(() {
      final lease = _wakeLock;
      _wakeLock = null;
      if (lease != null) unawaited(lease.release());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    if (!mounted) return;
    final sfState = context.read<SoundFinderState>();
    if (active) {
      unawaited(sfState.onAppForegrounded());
    } else {
      unawaited(sfState.onAppBackgrounded());
    }
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
    final bool isMicRunning = context.select<SoundFinderState, bool>(
      (s) => s.micStatus == MicStatus.running,
    );

    final Widget view = switch (mode) {
      SfMode.tracker => const SfTrackerView(),
      SfMode.counter => const SfCounterView(),
      SfMode.generator => const SfGeneratorView(),
    };

    final String title = switch (mode) {
      SfMode.tracker => l10n.sfTitleFinder,
      SfMode.counter => l10n.sfTitleCounter,
      SfMode.generator => l10n.sfTitleGenerator,
    };

    return ToolLayout(
      title: title,
      actions: [
        if (mode != SfMode.generator && isMicRunning)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.sfInputSettings,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ResponsiveAlertDialog(
                  title: Text(l10n.sfInputSettings),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SfMicSelector(),
                      SizedBox(height: 16),
                      SfGainControl(),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonClose),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SfModeTabs(),
          ),
          if (mode != SfMode.generator && isMicRunning)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SfClipRecorder(),
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
