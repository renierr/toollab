import 'package:flutter_soloud/flutter_soloud.dart';

/// Formats the clip export offers. Everything but [wav] is encoded by SoLoud's
/// mixer capture into a finished container; [wav] is captured as raw PCM and
/// wrapped locally, which avoids the capture's placeholder-header caveat.
enum ClipExportFormat {
  wav(MixerOutputFormat.pcmS16le, 'wav', 'WAV'),
  ogg(MixerOutputFormat.vorbis, 'ogg', 'OGG (Vorbis)'),
  opus(MixerOutputFormat.opus, 'opus', 'Opus'),
  flac(MixerOutputFormat.flac, 'flac', 'FLAC');

  const ClipExportFormat(this.mixerFormat, this.extension, this.label);

  final MixerOutputFormat mixerFormat;
  final String extension;

  /// The format's own name — not translated.
  final String label;

  bool get isPcm => mixerFormat.isPcm;
}
