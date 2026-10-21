import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'memo/memo_recorder.dart';
import 'sleep_labels.dart';
import 'sound_finder_state.dart';
import 'widgets/sf_clip_recorder.dart';
import 'widgets/sf_counter_view.dart';
import 'widgets/sf_generator_view.dart';
import 'widgets/sf_input_settings_dialog.dart';
import 'widgets/sf_memo_settings_dialog.dart';
import 'widgets/sf_mode_tabs.dart';
import 'widgets/sf_tracker_view.dart';
import 'widgets/sf_doppler_view.dart';
import 'widgets/sf_morse_view.dart';
import 'widgets/sf_recordings_view.dart';
import 'widgets/sf_sleep_view.dart';

class SoundFinderPage extends StatefulWidget {
  const SoundFinderPage({super.key});

  @override
  State<SoundFinderPage> createState() => _SoundFinderPageState();
}

class _SoundFinderPageState extends State<SoundFinderPage>
    with DisposeCleanup<SoundFinderPage>, WidgetsBindingObserver {
  WakeLockLease? _wakeLock;
  bool _screenOnWanted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<SoundFinderState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => state.onPageEnter());

    // A running sleep session wants the screen off, also when the page is
    // reopened during the night.
    void syncScreenOn() => _setScreenOn(!state.sleep.active);
    state.sleep.addListener(syncScreenOn);
    syncScreenOn();

    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(() => unawaited(state.onPageLeave()));
    onDispose(() {
      state.sleep.removeListener(syncScreenOn);
      _setScreenOn(false);
    });
  }

  void _setScreenOn(bool wanted) {
    if (wanted == _screenOnWanted) return;
    _screenOnWanted = wanted;
    if (!wanted) {
      final lease = _wakeLock;
      _wakeLock = null;
      if (lease != null) unawaited(lease.release());
      return;
    }
    unawaited(
      PowerWakeLockService.acquireFull().then((lease) {
        if (_screenOnWanted && _wakeLock == null) {
          _wakeLock = lease;
        } else {
          unawaited(lease.release());
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final sfState = context.read<SoundFinderState>();
    // `inactive` alone is a dialog, a share sheet or a lost window focus; the
    // mic must keep running through those.
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(sfState.onAppForegrounded());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(sfState.onAppBackgrounded());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
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
    context.read<SoundFinderState>().sleep.setNotificationText(
      title: l10n.sfSleepNotificationTitle,
      text: l10n.sfSleepNotificationText,
      waiting: (at) =>
          l10n.sfSleepNotificationWaiting(sleepClock(at, seconds: false)),
      finishing: l10n.sfSleepFinishing,
      savedChunks: l10n.sfSleepSavedChunks,
    );
    context.read<MemoRecorder>().setNotificationText(
      title: l10n.sfMemoNotificationTitle,
      recording: l10n.sfMemoNotificationRecording,
      paused: l10n.sfMemoNotificationPaused,
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
      SfMode.doppler => const SfDopplerView(),
      SfMode.morse => const SfMorseView(),
      SfMode.recordings => const SfRecordingsView(),
      SfMode.sleep => const SfSleepView(),
    };

    final String title = switch (mode) {
      SfMode.tracker => l10n.sfTitleFinder,
      SfMode.counter => l10n.sfTitleCounter,
      SfMode.generator => l10n.sfTitleGenerator,
      SfMode.doppler => l10n.sfTitleDoppler,
      SfMode.morse => l10n.sfTitleMorse,
      SfMode.recordings => l10n.sfTitleRecordings,
      SfMode.sleep => 'Sleep',
    };

    return ToolLayout(
      title: title,
      actions: [
        if (mode == SfMode.recordings)
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: l10n.sfMemoSettingsTitle,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SfMemoSettingsDialog(),
            ),
          )
        else if (mode != SfMode.generator &&
            mode != SfMode.morse &&
            isMicRunning)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.sfInputSettings,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SfInputSettingsDialog(),
            ),
          ),
      ],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SfModeTabs(),
          ),
          if (mode != SfMode.generator &&
              mode != SfMode.morse &&
              mode != SfMode.recordings &&
              mode != SfMode.sleep &&
              isMicRunning)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SfClipRecorder(),
            ),
          Expanded(
            // The memo list scrolls lazily on its own.
            child: mode == SfMode.recordings
                ? view
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: view,
                  ),
          ),
        ],
      ),
    );
  }
}
