import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/video_player/video_player_settings.dart';

void main() {
  test('missing or invalid values fall back to the defaults', () {
    final settings = VideoPlayerSettings.fromSettings({
      'video_skip_seconds': '7',
      'video_default_speed': 'fast',
      'video_double_tap': 'unknown',
      'video_hide_delay_seconds': '4',
      'video_audio_language': 'xx',
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
    expect(settings.swipeBrightness, isTrue);
    expect(settings.arrowSeekSeconds, 5);
    expect(settings.hideDelaySeconds, 3);
    expect(settings.subtitleScale, 1);
    expect(settings.subtitleBackground, isTrue);
    expect(settings.sidecarSubtitles, isTrue);
    expect(settings.audioLanguage, '');
    expect(settings.subtitleLanguage, '');
    expect(settings.resumePlayback, isTrue);
  });

  test('stored values survive a round trip', () {
    const stored = VideoPlayerSettings(
      skipSeconds: 30,
      defaultSpeed: 1.5,
      doubleTap: VideoDoubleTap.off,
      pipOnLeave: false,
      mediaControls: false,
      hardwareDecoding: false,
      swipeSkip: false,
      swipeVolume: false,
      volumeTarget: VideoVolumeTarget.player,
      swipeBrightness: false,
      arrowSeekSeconds: 15,
      hideDelaySeconds: 8,
      subtitleScale: 1.5,
      subtitleBackground: false,
      sidecarSubtitles: false,
      audioLanguage: 'ja',
      subtitleLanguage: 'de',
      resumePlayback: false,
    );
    final loaded = VideoPlayerSettings.fromSettings(stored.toSettings());
    expect(loaded.skipSeconds, 30);
    expect(loaded.defaultSpeed, 1.5);
    expect(loaded.doubleTap, VideoDoubleTap.off);
    expect(loaded.pipOnLeave, isFalse);
    expect(loaded.mediaControls, isFalse);
    expect(loaded.hardwareDecoding, isFalse);
    expect(loaded.swipeSkip, isFalse);
    expect(loaded.swipeVolume, isFalse);
    expect(loaded.volumeTarget, VideoVolumeTarget.player);
    expect(loaded.swipeBrightness, isFalse);
    expect(loaded.arrowSeekSeconds, 15);
    expect(loaded.hideDelaySeconds, 8);
    expect(loaded.subtitleScale, 1.5);
    expect(loaded.subtitleBackground, isFalse);
    expect(loaded.sidecarSubtitles, isFalse);
    expect(loaded.audioLanguage, 'ja');
    expect(loaded.subtitleLanguage, 'de');
    expect(loaded.resumePlayback, isFalse);
  });

  test('track languages match in both code forms', () {
    expect(videoLanguageMatches('en', 'en'), isTrue);
    expect(videoLanguageMatches('eng', 'en'), isTrue);
    expect(videoLanguageMatches('ger', 'de'), isTrue);
    expect(videoLanguageMatches('en-US', 'en'), isTrue);
    expect(videoLanguageMatches('fre', 'en'), isFalse);
    expect(videoLanguageMatches(null, 'en'), isFalse);
    expect(videoLanguageMatches('en', ''), isFalse);
    expect(videoLanguageCodes('de'), ['de', 'ger', 'deu']);
    expect(videoLanguageCodes(''), isEmpty);
  });
}
