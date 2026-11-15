enum VideoDoubleTap { sidesSkip, playPause }

/// What a vertical swipe changes on Android.
enum VideoVolumeTarget { system, player }

/// User options for the video player, stored with the app settings.
class VideoPlayerSettings {
  static const List<int> skipOptions = [5, 10, 15, 20, 30, 60];
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

  static const String _keySkip = 'video_skip_seconds';
  static const String _keySpeed = 'video_default_speed';
  static const String _keyDoubleTap = 'video_double_tap';
  static const String _keyPip = 'video_pip_on_leave';
  static const String _keyMediaControls = 'video_media_controls';
  static const String _keyHardwareDecoding = 'video_hardware_decoding';
  static const String _keySwipeSkip = 'video_swipe_skip';
  static const String _keySwipeVolume = 'video_swipe_volume';
  static const String _keyVolumeTarget = 'video_volume_target';

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
  });

  Duration get skip => Duration(seconds: skipSeconds);

  factory VideoPlayerSettings.fromSettings(Map<String, String> settings) {
    const defaults = VideoPlayerSettings();
    final skip = int.tryParse(settings[_keySkip] ?? '');
    final speed = double.tryParse(settings[_keySpeed] ?? '');
    return VideoPlayerSettings(
      skipSeconds: skipOptions.contains(skip) ? skip! : defaults.skipSeconds,
      defaultSpeed: speedOptions.contains(speed)
          ? speed!
          : defaults.defaultSpeed,
      doubleTap:
          VideoDoubleTap.values
              .where((v) => v.name == settings[_keyDoubleTap])
              .firstOrNull ??
          defaults.doubleTap,
      pipOnLeave: settings[_keyPip] != 'false',
      mediaControls: settings[_keyMediaControls] != 'false',
      hardwareDecoding: settings[_keyHardwareDecoding] != 'false',
      swipeSkip: settings[_keySwipeSkip] != 'false',
      swipeVolume: settings[_keySwipeVolume] != 'false',
      volumeTarget:
          VideoVolumeTarget.values
              .where((v) => v.name == settings[_keyVolumeTarget])
              .firstOrNull ??
          defaults.volumeTarget,
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
  );
}
