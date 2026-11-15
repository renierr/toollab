import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/video_player/video_player_settings.dart';

class VideoSettingsPage extends StatelessWidget {
  const VideoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = context.select<AppState, VideoPlayerSettings>(
      (state) => state.videoPlayerSettings,
    );
    final speedFormat = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toString(),
    );
    void update(VideoPlayerSettings next) =>
        context.read<AppState>().setVideoPlayerSettings(next);
    Icon leading(IconData icon) => Icon(icon, color: theme.colorScheme.primary);
    const divider = Divider(height: 1, indent: 16, endIndent: 16);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoSettingsTitle)),
      body: ReadableScrollPadding(
        padding: const EdgeInsets.all(16),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: leading(Icons.fast_forward_outlined),
                    title: Text(l10n.videoSettingsSkip),
                    subtitle: Text(l10n.videoSettingsSkipHint),
                    trailing: DropdownButton<int>(
                      value: settings.skipSeconds,
                      underline: const SizedBox(),
                      items: [
                        for (final seconds in VideoPlayerSettings.skipOptions)
                          DropdownMenuItem(
                            value: seconds,
                            child: Text(l10n.videoSettingsSeconds(seconds)),
                          ),
                      ],
                      onChanged: (seconds) {
                        if (seconds != null) {
                          update(settings.copyWith(skipSeconds: seconds));
                        }
                      },
                    ),
                  ),
                  divider,
                  ListTile(
                    leading: leading(Icons.speed),
                    title: Text(l10n.videoSettingsSpeed),
                    trailing: DropdownButton<double>(
                      value: settings.defaultSpeed,
                      underline: const SizedBox(),
                      items: [
                        for (final speed in VideoPlayerSettings.speedOptions)
                          DropdownMenuItem(
                            value: speed,
                            child: Text(
                              speed == 1
                                  ? l10n.videoPlayerSpeedNormal
                                  : '${speedFormat.format(speed)}×',
                            ),
                          ),
                      ],
                      onChanged: (speed) {
                        if (speed != null) {
                          update(settings.copyWith(defaultSpeed: speed));
                        }
                      },
                    ),
                  ),
                  divider,
                  ListTile(
                    leading: leading(Icons.touch_app_outlined),
                    title: Text(l10n.videoSettingsDoubleTap),
                    subtitle: DropdownButton<VideoDoubleTap>(
                      value: settings.doubleTap,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: VideoDoubleTap.sidesSkip,
                          child: Text(l10n.videoSettingsDoubleTapSides),
                        ),
                        DropdownMenuItem(
                          value: VideoDoubleTap.playPause,
                          child: Text(l10n.videoSettingsDoubleTapPlayPause),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          update(settings.copyWith(doubleTap: mode));
                        }
                      },
                    ),
                  ),
                  divider,
                  SwitchListTile(
                    secondary: leading(Icons.swipe_outlined),
                    title: Text(l10n.videoSettingsSwipeSkip),
                    subtitle: Text(l10n.videoSettingsSwipeSkipHint),
                    value: settings.swipeSkip,
                    onChanged: (value) =>
                        update(settings.copyWith(swipeSkip: value)),
                  ),
                  divider,
                  SwitchListTile(
                    secondary: leading(Icons.swipe_vertical_outlined),
                    title: Text(l10n.videoSettingsSwipeVolume),
                    subtitle: Text(l10n.videoSettingsSwipeVolumeHint),
                    value: settings.swipeVolume,
                    onChanged: (value) =>
                        update(settings.copyWith(swipeVolume: value)),
                  ),
                  if (Platform.isAndroid) ...[
                    divider,
                    ListTile(
                      enabled: settings.swipeVolume,
                      leading: leading(Icons.volume_up_outlined),
                      title: Text(l10n.videoSettingsVolumeTarget),
                      subtitle: DropdownButton<VideoVolumeTarget>(
                        value: settings.volumeTarget,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: VideoVolumeTarget.system,
                            child: Text(l10n.videoSettingsVolumeSystem),
                          ),
                          DropdownMenuItem(
                            value: VideoVolumeTarget.player,
                            child: Text(l10n.videoSettingsVolumePlayer),
                          ),
                        ],
                        onChanged: settings.swipeVolume
                            ? (target) {
                                if (target != null) {
                                  update(
                                    settings.copyWith(volumeTarget: target),
                                  );
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                  if (Platform.isAndroid) ...[
                    divider,
                    SwitchListTile(
                      secondary: leading(Icons.picture_in_picture_alt_outlined),
                      title: Text(l10n.videoSettingsPip),
                      subtitle: Text(l10n.videoSettingsPipHint),
                      value: settings.pipOnLeave,
                      onChanged: (value) =>
                          update(settings.copyWith(pipOnLeave: value)),
                    ),
                  ],
                  divider,
                  SwitchListTile(
                    secondary: leading(Icons.queue_music_outlined),
                    title: Text(l10n.videoSettingsMediaControls),
                    subtitle: Text(l10n.videoSettingsMediaControlsHint),
                    value: settings.mediaControls,
                    onChanged: (value) =>
                        update(settings.copyWith(mediaControls: value)),
                  ),
                  if (!Platform.isAndroid) ...[
                    divider,
                    SwitchListTile(
                      secondary: leading(Icons.memory_outlined),
                      title: Text(l10n.videoSettingsHardwareDecoding),
                      subtitle: Text(l10n.videoSettingsHardwareDecodingHint),
                      value: settings.hardwareDecoding,
                      onChanged: (value) =>
                          update(settings.copyWith(hardwareDecoding: value)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
