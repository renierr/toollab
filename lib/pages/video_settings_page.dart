import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';
import 'package:tool_lab/widgets/video_player/video_player_settings.dart';

/// Language names in their own language, so each is found whatever the UI language.
const Map<String, String> _languageNames = {
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'ja': '日本語',
  'ko': '한국어',
  'zh': '中文',
};

class VideoSettingsPage extends StatelessWidget {
  const VideoSettingsPage({super.key});

  Future<void> _reset(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.videoSettingsReset,
      message: l10n.videoSettingsResetMessage,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonReset,
      confirmColor: AppTheme.statusRed,
    );
    if (confirmed != true || !context.mounted) return;
    unawaited(
      context.read<AppState>().setVideoPlayerSettings(
        const VideoPlayerSettings(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.select<AppState, VideoPlayerSettings>(
      (state) => state.videoPlayerSettings,
    );
    final locale = Localizations.localeOf(context).toString();
    final speedFormat = NumberFormat('0.##', locale);
    void update(VideoPlayerSettings next) =>
        context.read<AppState>().setVideoPlayerSettings(next);
    Map<int, String> seconds(List<int> options) => {
      for (final s in options) s: l10n.videoSettingsSeconds(s),
    };
    final languages = {
      '': l10n.videoSettingsLanguageDefault,
      for (final code in VideoPlayerSettings.languageOptions)
        code: _languageNames[code] ?? code,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoSettingsTitle)),
      body: ReadableScrollPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            _Section(
              title: l10n.videoSettingsSectionGestures,
              description: l10n.videoSettingsLongPressHint,
              children: [
                _ChoiceTile<VideoDoubleTap>(
                  icon: Icons.touch_app_outlined,
                  title: l10n.videoSettingsDoubleTap,
                  expanded: true,
                  value: settings.doubleTap,
                  options: {
                    VideoDoubleTap.sidesSkip: l10n.videoSettingsDoubleTapSides,
                    VideoDoubleTap.playPause:
                        l10n.videoSettingsDoubleTapPlayPause,
                    VideoDoubleTap.off: l10n.videoSettingsDoubleTapOff,
                  },
                  onChanged: (v) => update(settings.copyWith(doubleTap: v)),
                ),
                _SwitchTile(
                  icon: Icons.swipe_outlined,
                  title: l10n.videoSettingsSwipeSkip,
                  subtitle: l10n.videoSettingsSwipeSkipHint,
                  value: settings.swipeSkip,
                  onChanged: (v) => update(settings.copyWith(swipeSkip: v)),
                ),
                _SwitchTile(
                  icon: Icons.swipe_vertical_outlined,
                  title: l10n.videoSettingsSwipeVolume,
                  subtitle: l10n.videoSettingsSwipeVolumeHint,
                  value: settings.swipeVolume,
                  onChanged: (v) => update(settings.copyWith(swipeVolume: v)),
                ),
                if (Platform.isAndroid) ...[
                  _ChoiceTile<VideoVolumeTarget>(
                    icon: Icons.volume_up_outlined,
                    title: l10n.videoSettingsVolumeTarget,
                    expanded: true,
                    enabled: settings.swipeVolume,
                    value: settings.volumeTarget,
                    options: {
                      VideoVolumeTarget.system: l10n.videoSettingsVolumeSystem,
                      VideoVolumeTarget.player: l10n.videoSettingsVolumePlayer,
                    },
                    onChanged: (v) =>
                        update(settings.copyWith(volumeTarget: v)),
                  ),
                  _SwitchTile(
                    icon: Icons.brightness_6_outlined,
                    title: l10n.videoSettingsSwipeBrightness,
                    subtitle: l10n.videoSettingsSwipeBrightnessHint,
                    value: settings.swipeBrightness,
                    onChanged: (v) =>
                        update(settings.copyWith(swipeBrightness: v)),
                  ),
                ],
              ],
            ),
            _Section(
              title: l10n.videoSettingsSectionPlayback,
              children: [
                _ChoiceTile<int>(
                  icon: Icons.fast_forward_outlined,
                  title: l10n.videoSettingsSkip,
                  subtitle: l10n.videoSettingsSkipHint,
                  value: settings.skipSeconds,
                  options: seconds(VideoPlayerSettings.skipOptions),
                  onChanged: (v) => update(settings.copyWith(skipSeconds: v)),
                ),
                _ChoiceTile<int>(
                  icon: Icons.keyboard_outlined,
                  title: l10n.videoSettingsArrowSeek,
                  subtitle: l10n.videoSettingsArrowSeekHint,
                  value: settings.arrowSeekSeconds,
                  options: seconds(VideoPlayerSettings.arrowSeekOptions),
                  onChanged: (v) =>
                      update(settings.copyWith(arrowSeekSeconds: v)),
                ),
                _ChoiceTile<double>(
                  icon: Icons.speed,
                  title: l10n.videoSettingsSpeed,
                  value: settings.defaultSpeed,
                  options: {
                    for (final speed in VideoPlayerSettings.speedOptions)
                      speed: speed == 1
                          ? l10n.videoPlayerSpeedNormal
                          : '${speedFormat.format(speed)}×',
                  },
                  onChanged: (v) => update(settings.copyWith(defaultSpeed: v)),
                ),
                _SwitchTile(
                  icon: Icons.history,
                  title: l10n.videoSettingsResume,
                  subtitle: l10n.videoSettingsResumeHint,
                  value: settings.resumePlayback,
                  onChanged: (v) =>
                      update(settings.copyWith(resumePlayback: v)),
                ),
                _ChoiceTile<int>(
                  icon: Icons.visibility_off_outlined,
                  title: l10n.videoSettingsHideDelay,
                  value: settings.hideDelaySeconds,
                  options: seconds(VideoPlayerSettings.hideDelayOptions),
                  onChanged: (v) =>
                      update(settings.copyWith(hideDelaySeconds: v)),
                ),
                if (!Platform.isAndroid)
                  _SwitchTile(
                    icon: Icons.memory_outlined,
                    title: l10n.videoSettingsHardwareDecoding,
                    subtitle: l10n.videoSettingsHardwareDecodingHint,
                    value: settings.hardwareDecoding,
                    onChanged: (v) =>
                        update(settings.copyWith(hardwareDecoding: v)),
                  ),
              ],
            ),
            _Section(
              title: l10n.videoSettingsSectionSubtitles,
              children: [
                _ChoiceTile<double>(
                  icon: Icons.format_size,
                  title: l10n.videoSettingsSubtitleSize,
                  value: settings.subtitleScale,
                  options: {
                    for (final scale
                        in VideoPlayerSettings.subtitleScaleOptions)
                      scale: l10n.videoSettingsPercent((scale * 100).round()),
                  },
                  onChanged: (v) => update(settings.copyWith(subtitleScale: v)),
                ),
                _SwitchTile(
                  icon: Icons.subtitles_outlined,
                  title: l10n.videoSettingsSubtitleBackground,
                  subtitle: l10n.videoSettingsSubtitleBackgroundHint,
                  value: settings.subtitleBackground,
                  onChanged: (v) =>
                      update(settings.copyWith(subtitleBackground: v)),
                ),
                _SwitchTile(
                  icon: Icons.closed_caption_outlined,
                  title: l10n.videoSettingsSidecar,
                  subtitle: l10n.videoSettingsSidecarHint,
                  value: settings.sidecarSubtitles,
                  onChanged: (v) =>
                      update(settings.copyWith(sidecarSubtitles: v)),
                ),
                _ChoiceTile<String>(
                  icon: Icons.record_voice_over_outlined,
                  title: l10n.videoSettingsAudioLanguage,
                  value: settings.audioLanguage,
                  options: languages,
                  onChanged: (v) => update(settings.copyWith(audioLanguage: v)),
                ),
                _ChoiceTile<String>(
                  icon: Icons.translate,
                  title: l10n.videoSettingsSubtitleLanguage,
                  value: settings.subtitleLanguage,
                  options: languages,
                  onChanged: (v) =>
                      update(settings.copyWith(subtitleLanguage: v)),
                ),
              ],
            ),
            _Section(
              title: l10n.videoSettingsSectionSystem,
              children: [
                if (Platform.isAndroid)
                  _SwitchTile(
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: l10n.videoSettingsPip,
                    subtitle: l10n.videoSettingsPipHint,
                    value: settings.pipOnLeave,
                    onChanged: (v) => update(settings.copyWith(pipOnLeave: v)),
                  ),
                _SwitchTile(
                  icon: Icons.queue_music_outlined,
                  title: l10n.videoSettingsMediaControls,
                  subtitle: l10n.videoSettingsMediaControlsHint,
                  value: settings.mediaControls,
                  onChanged: (v) => update(settings.copyWith(mediaControls: v)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _reset(context),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.videoSettingsReset),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const _Section({
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(title: title, description: description),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// [expanded] puts a dropdown with long labels under the title.
class _ChoiceTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool expanded;
  final bool enabled;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expanded = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButton<T>(
      value: value,
      isExpanded: expanded,
      underline: const SizedBox(),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
    );
    final subtitle = this.subtitle;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: expanded
          ? dropdown
          : subtitle == null
          ? null
          : Text(subtitle),
      trailing: expanded ? null : dropdown,
    );
  }
}
