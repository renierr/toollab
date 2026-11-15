import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/video_player/video_player_settings.dart';

void main() {
  test('missing or invalid values fall back to the defaults', () {
    final settings = VideoPlayerSettings.fromSettings({
      'video_skip_seconds': '7',
      'video_default_speed': 'fast',
      'video_double_tap': 'unknown',
    });
    expect(settings.skipSeconds, 10);
    expect(settings.defaultSpeed, 1);
    expect(settings.doubleTap, VideoDoubleTap.sidesSkip);
    expect(settings.pipOnLeave, isTrue);
    expect(settings.mediaControls, isTrue);
    expect(settings.hardwareDecoding, isTrue);
    expect(settings.swipeSkip, isTrue);
    expect(settings.swipeVolume, isTrue);
    expect(settings.volumeTarget, VideoVolumeTarget.system);
  });

  test('stored values survive a round trip', () {
    const stored = VideoPlayerSettings(
      skipSeconds: 30,
      defaultSpeed: 1.5,
      doubleTap: VideoDoubleTap.playPause,
      pipOnLeave: false,
      mediaControls: false,
      hardwareDecoding: false,
      swipeSkip: false,
      swipeVolume: false,
      volumeTarget: VideoVolumeTarget.player,
    );
    final loaded = VideoPlayerSettings.fromSettings(stored.toSettings());
    expect(loaded.skipSeconds, 30);
    expect(loaded.defaultSpeed, 1.5);
    expect(loaded.doubleTap, VideoDoubleTap.playPause);
    expect(loaded.pipOnLeave, isFalse);
    expect(loaded.mediaControls, isFalse);
    expect(loaded.hardwareDecoding, isFalse);
    expect(loaded.swipeSkip, isFalse);
    expect(loaded.swipeVolume, isFalse);
    expect(loaded.volumeTarget, VideoVolumeTarget.player);
  });
}
