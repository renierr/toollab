/// [off] lets a single tap react without waiting for a second one.
enum VideoDoubleTap { sidesSkip, playPause, off }

/// What a vertical swipe changes on Android.
enum VideoVolumeTarget { system, player }

/// User options for the video player, stored with the app settings.
class VideoPlayerSettings {
  static const List<int> skipOptions = [5, 10, 15, 20, 30, 60];
  static const List<int> arrowSeekOptions = [5, 10, 15, 30];
  static const List<int> hideDelayOptions = [2, 3, 5, 8, 10];
  static const List<double> subtitleScaleOptions = [0.75, 1, 1.25, 1.5, 2];
  static const List<double> speedOptions = [
    0.25,
    0.5,
    0.75,
    1,
    1.25,
    1.5,
    1.75,
    2,
  ];

  /// ISO 639-1 codes offered for the preferred track languages.
  static const List<String> languageOptions = [
    'en',
    'de',
    'fr',
    'es',
    'it',
    'pt',
    'nl',
    'pl',
    'ru',
    'tr',
    'ja',
    'ko',
    'zh',
  ];

  static const String _keySkip = 'video_skip_seconds';
  static const String _keySpeed = 'video_default_speed';
  static const String _keyDoubleTap = 'video_double_tap';
  static const String _keyPip = 'video_pip_on_leave';
  static const String _keyMediaControls = 'video_media_controls';
  static const String _keyHardwareDecoding = 'video_hardware_decoding';
  static const String _keySwipeSkip = 'video_swipe_skip';
  static const String _keySwipeVolume = 'video_swipe_volume';
  static const String _keyVolumeTarget = 'video_volume_target';
  static const String _keySwipeBrightness = 'video_swipe_brightness';
  static const String _keyArrowSeek = 'video_arrow_seek_seconds';
  static const String _keyHideDelay = 'video_hide_delay_seconds';
  static const String _keySubtitleScale = 'video_subtitle_scale';
  static const String _keySubtitleBackground = 'video_subtitle_background';
  static const String _keySidecarSubtitles = 'video_sidecar_subtitles';
  static const String _keyAudioLanguage = 'video_audio_language';
  static const String _keySubtitleLanguage = 'video_subtitle_language';

  final int skipSeconds;
  final double defaultSpeed;
  final VideoDoubleTap doubleTap;

  /// Android: enter picture-in-picture when the user leaves while playing.
  final bool pipOnLeave;

  /// The Android notification and the desktop media keys / overlay.
  final bool mediaControls;

  /// Desktop only: mpv's `hwdec`.
  final bool hardwareDecoding;
  final bool swipeSkip;
  final bool swipeVolume;
  final VideoVolumeTarget volumeTarget;

  /// Android: a vertical swipe on the left half sets the screen brightness.
  final bool swipeBrightness;

  /// Left/right arrow keys and the TV remote's D-pad.
  final int arrowSeekSeconds;
  final int hideDelaySeconds;
  final double subtitleScale;
  final bool subtitleBackground;

  /// Loads `movie.srt` / `movie.en.srt` next to a local video.
  final bool sidecarSubtitles;

  /// ISO 639-1 code; empty keeps the file's default track.
  final String audioLanguage;
  final String subtitleLanguage;

  const VideoPlayerSettings({
    this.skipSeconds = 10,
    this.defaultSpeed = 1,
    this.doubleTap = VideoDoubleTap.sidesSkip,
    this.pipOnLeave = true,
    this.mediaControls = true,
    this.hardwareDecoding = true,
    this.swipeSkip = true,
    this.swipeVolume = true,
    this.volumeTarget = VideoVolumeTarget.system,
    this.swipeBrightness = true,
    this.arrowSeekSeconds = 5,
    this.hideDelaySeconds = 3,
    this.subtitleScale = 1,
    this.subtitleBackground = true,
    this.sidecarSubtitles = true,
    this.audioLanguage = '',
    this.subtitleLanguage = '',
  });

  Duration get skip => Duration(seconds: skipSeconds);
  Duration get arrowSeek => Duration(seconds: arrowSeekSeconds);
  Duration get hideDelay => Duration(seconds: hideDelaySeconds);

  factory VideoPlayerSettings.fromSettings(Map<String, String> settings) {
    const defaults = VideoPlayerSettings();
    T pick<T>(List<T> options, T? value, T fallback) =>
        options.contains(value) ? value as T : fallback;
    T byName<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == settings[key]).firstOrNull ?? fallback;
    int? integer(String key) => int.tryParse(settings[key] ?? '');
    double? decimal(String key) => double.tryParse(settings[key] ?? '');
    String language(String key) => pick(languageOptions, settings[key], '');
    return VideoPlayerSettings(
      skipSeconds: pick(skipOptions, integer(_keySkip), defaults.skipSeconds),
      defaultSpeed: pick(
        speedOptions,
        decimal(_keySpeed),
        defaults.defaultSpeed,
      ),
      doubleTap: byName(
        VideoDoubleTap.values,
        _keyDoubleTap,
        defaults.doubleTap,
      ),
      pipOnLeave: settings[_keyPip] != 'false',
      mediaControls: settings[_keyMediaControls] != 'false',
      hardwareDecoding: settings[_keyHardwareDecoding] != 'false',
      swipeSkip: settings[_keySwipeSkip] != 'false',
      swipeVolume: settings[_keySwipeVolume] != 'false',
      volumeTarget: byName(
        VideoVolumeTarget.values,
        _keyVolumeTarget,
        defaults.volumeTarget,
      ),
      swipeBrightness: settings[_keySwipeBrightness] != 'false',
      arrowSeekSeconds: pick(
        arrowSeekOptions,
        integer(_keyArrowSeek),
        defaults.arrowSeekSeconds,
      ),
      hideDelaySeconds: pick(
        hideDelayOptions,
        integer(_keyHideDelay),
        defaults.hideDelaySeconds,
      ),
      subtitleScale: pick(
        subtitleScaleOptions,
        decimal(_keySubtitleScale),
        defaults.subtitleScale,
      ),
      subtitleBackground: settings[_keySubtitleBackground] != 'false',
      sidecarSubtitles: settings[_keySidecarSubtitles] != 'false',
      audioLanguage: language(_keyAudioLanguage),
      subtitleLanguage: language(_keySubtitleLanguage),
    );
  }

  Map<String, String> toSettings() => {
    _keySkip: '$skipSeconds',
    _keySpeed: '$defaultSpeed',
    _keyDoubleTap: doubleTap.name,
    _keyPip: '$pipOnLeave',
    _keyMediaControls: '$mediaControls',
    _keyHardwareDecoding: '$hardwareDecoding',
    _keySwipeSkip: '$swipeSkip',
    _keySwipeVolume: '$swipeVolume',
    _keyVolumeTarget: volumeTarget.name,
    _keySwipeBrightness: '$swipeBrightness',
    _keyArrowSeek: '$arrowSeekSeconds',
    _keyHideDelay: '$hideDelaySeconds',
    _keySubtitleScale: '$subtitleScale',
    _keySubtitleBackground: '$subtitleBackground',
    _keySidecarSubtitles: '$sidecarSubtitles',
    _keyAudioLanguage: audioLanguage,
    _keySubtitleLanguage: subtitleLanguage,
  };

  VideoPlayerSettings copyWith({
    int? skipSeconds,
    double? defaultSpeed,
    VideoDoubleTap? doubleTap,
    bool? pipOnLeave,
    bool? mediaControls,
    bool? hardwareDecoding,
    bool? swipeSkip,
    bool? swipeVolume,
    VideoVolumeTarget? volumeTarget,
    bool? swipeBrightness,
    int? arrowSeekSeconds,
    int? hideDelaySeconds,
    double? subtitleScale,
    bool? subtitleBackground,
    bool? sidecarSubtitles,
    String? audioLanguage,
    String? subtitleLanguage,
  }) => VideoPlayerSettings(
    skipSeconds: skipSeconds ?? this.skipSeconds,
    defaultSpeed: defaultSpeed ?? this.defaultSpeed,
    doubleTap: doubleTap ?? this.doubleTap,
    pipOnLeave: pipOnLeave ?? this.pipOnLeave,
    mediaControls: mediaControls ?? this.mediaControls,
    hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
    swipeSkip: swipeSkip ?? this.swipeSkip,
    swipeVolume: swipeVolume ?? this.swipeVolume,
    volumeTarget: volumeTarget ?? this.volumeTarget,
    swipeBrightness: swipeBrightness ?? this.swipeBrightness,
    arrowSeekSeconds: arrowSeekSeconds ?? this.arrowSeekSeconds,
    hideDelaySeconds: hideDelaySeconds ?? this.hideDelaySeconds,
    subtitleScale: subtitleScale ?? this.subtitleScale,
    subtitleBackground: subtitleBackground ?? this.subtitleBackground,
    sidecarSubtitles: sidecarSubtitles ?? this.sidecarSubtitles,
    audioLanguage: audioLanguage ?? this.audioLanguage,
    subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
  );
}

/// Track languages come as ISO 639-1 (`en`) or 639-2 (`eng`, `ger`), sometimes
/// with a region (`en-US`).
bool videoLanguageMatches(String? track, String wanted) {
  if (track == null || wanted.isEmpty) return false;
  final code = track.toLowerCase().split(RegExp('[-_]')).first;
  return code == wanted || _iso639_2[code] == wanted;
}

/// [code] plus its ISO 639-2 forms, for players that compare tags literally.
List<String> videoLanguageCodes(String code) => [
  if (code.isNotEmpty) code,
  for (final e in _iso639_2.entries)
    if (code.isNotEmpty && e.value == code) e.key,
];

const Map<String, String> _iso639_2 = {
  'eng': 'en',
  'ger': 'de',
  'deu': 'de',
  'fre': 'fr',
  'fra': 'fr',
  'spa': 'es',
  'ita': 'it',
  'por': 'pt',
  'dut': 'nl',
  'nld': 'nl',
  'pol': 'pl',
  'rus': 'ru',
  'tur': 'tr',
  'jpn': 'ja',
  'kor': 'ko',
  'chi': 'zh',
  'zho': 'zh',
};
