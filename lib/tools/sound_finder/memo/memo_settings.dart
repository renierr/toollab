import 'package:record/record.dart';

import '../../../services/database_service.dart';
import '../config.dart';

/// Container a memo is recorded into. Both are lossless and play back in-app.
enum MemoFormat {
  wav(AudioEncoder.wav, 'wav', 'audio/wav', 'WAV'),
  flac(AudioEncoder.flac, 'flac', 'audio/flac', 'FLAC');

  const MemoFormat(this.encoder, this.extension, this.mimeType, this.label);

  final AudioEncoder encoder;
  final String extension;
  final String mimeType;
  final String label;

  /// Trim and normalize rewrite raw PCM, so only WAV can be edited.
  bool get editable => this == wav;

  static MemoFormat? fromExtension(String ext) {
    for (final f in values) {
      if (f.extension == ext.toLowerCase()) return f;
    }
    return null;
  }
}

/// Android capture presets. Other platforms ignore the source.
enum MemoMicSource {
  standard(AndroidAudioSource.defaultSource),
  camcorder(AndroidAudioSource.camcorder),
  voice(AndroidAudioSource.voiceRecognition),
  raw(AndroidAudioSource.unprocessed);

  const MemoMicSource(this.androidSource);

  final AndroidAudioSource androidSource;
}

class MemoSettings {
  static const List<int> sampleRates = [22050, 44100, 48000];
  static const List<int> maxLengths = [0, 300, 900, 1800, 3600, 7200];

  static const String _kFormat = 'memo_format';
  static const String _kRate = 'memo_rate';
  static const String _kChannels = 'memo_channels';
  static const String _kSource = 'memo_source';
  static const String _kNoise = 'memo_noise';
  static const String _kEcho = 'memo_echo';
  static const String _kAgc = 'memo_agc';
  static const String _kMax = 'memo_max';
  static const String _kDevice = 'memo_device';
  static const String _kSpeed = 'memo_speed';

  final MemoFormat format;
  final int sampleRate;
  final int channels;
  final MemoMicSource source;
  final bool noiseSuppress;
  final bool echoCancel;
  final bool autoGain;

  /// Seconds before recording auto-stops; 0 records until stopped.
  final int maxSeconds;

  /// Persisted input device id; null follows the platform default.
  final String? deviceId;
  final double playbackSpeed;

  const MemoSettings({
    this.format = MemoFormat.wav,
    this.sampleRate = 48000,
    this.channels = 1,
    this.source = MemoMicSource.standard,
    this.noiseSuppress = false,
    this.echoCancel = false,
    this.autoGain = false,
    this.maxSeconds = 0,
    this.deviceId,
    this.playbackSpeed = 1.0,
  });

  MemoSettings copyWith({
    MemoFormat? format,
    int? sampleRate,
    int? channels,
    MemoMicSource? source,
    bool? noiseSuppress,
    bool? echoCancel,
    bool? autoGain,
    int? maxSeconds,
    ({String? value})? deviceId,
    double? playbackSpeed,
  }) {
    return MemoSettings(
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      source: source ?? this.source,
      noiseSuppress: noiseSuppress ?? this.noiseSuppress,
      echoCancel: echoCancel ?? this.echoCancel,
      autoGain: autoGain ?? this.autoGain,
      maxSeconds: maxSeconds ?? this.maxSeconds,
      deviceId: deviceId != null ? deviceId.value : this.deviceId,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  static Future<MemoSettings> load() async {
    final db = DatabaseService.instance;
    final id = SoundFinderTool.config.id;
    Future<String?> get(String key) => db.getSetting(id, key);

    final rate = int.tryParse(await get(_kRate) ?? '');
    final channels = int.tryParse(await get(_kChannels) ?? '');
    final max = int.tryParse(await get(_kMax) ?? '');
    final device = await get(_kDevice);
    final source = await get(_kSource);
    return MemoSettings(
      format:
          MemoFormat.fromExtension(await get(_kFormat) ?? '') ?? MemoFormat.wav,
      sampleRate: sampleRates.contains(rate) ? rate! : 48000,
      channels: channels == 2 ? 2 : 1,
      source: MemoMicSource.values.firstWhere(
        (s) => s.name == source,
        orElse: () => MemoMicSource.standard,
      ),
      noiseSuppress: await get(_kNoise) == 'true',
      echoCancel: await get(_kEcho) == 'true',
      autoGain: await get(_kAgc) == 'true',
      maxSeconds: maxLengths.contains(max) ? max! : 0,
      deviceId: (device == null || device.isEmpty) ? null : device,
      playbackSpeed:
          double.tryParse(await get(_kSpeed) ?? '')?.clamp(0.5, 2.0) ?? 1.0,
    );
  }

  Future<void> save() async {
    final db = DatabaseService.instance;
    final id = SoundFinderTool.config.id;
    await Future.wait([
      db.setSetting(id, _kFormat, format.extension),
      db.setSetting(id, _kRate, '$sampleRate'),
      db.setSetting(id, _kChannels, '$channels'),
      db.setSetting(id, _kSource, source.name),
      db.setSetting(id, _kNoise, '$noiseSuppress'),
      db.setSetting(id, _kEcho, '$echoCancel'),
      db.setSetting(id, _kAgc, '$autoGain'),
      db.setSetting(id, _kMax, '$maxSeconds'),
      db.setSetting(id, _kDevice, deviceId ?? ''),
      db.setSetting(id, _kSpeed, playbackSpeed.toStringAsFixed(2)),
    ]);
  }
}
