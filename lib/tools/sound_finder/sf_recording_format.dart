import 'package:flutter_soloud/flutter_soloud.dart';

/// Output formats a stored mic recording can be exported to.
enum SfRecordingFormat {
  wav(MixerOutputFormat.pcmS16le, 'wav', 'WAV'),
  ogg(MixerOutputFormat.vorbis, 'ogg', 'OGG (Vorbis)'),
  opus(MixerOutputFormat.opus, 'opus', 'Opus'),
  flac(MixerOutputFormat.flac, 'flac', 'FLAC');

  const SfRecordingFormat(this.mixerFormat, this.extension, this.label);

  final MixerOutputFormat mixerFormat;
  final String extension;
  final String label;

  bool get isPcm => mixerFormat.isPcm;
}
