import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../../../helpers/wav_utils.dart';
import '../audio/sleep_flac_codec.dart';

/// Whisper reads 16 kHz mono 16-bit PCM WAV.
const int whisperSampleRate = 16000;

/// Converts a memo (16/24-bit WAV or FLAC, any rate >= 16 kHz, any channel
/// count) into a 16 kHz mono WAV at [target]. Runs synchronously; call it in
/// an isolate. Returns false for unsupported input.
bool convertMemoForWhisper(String source, String target) {
  final lower = source.toLowerCase();
  final pcm = lower.endsWith('.flac')
      ? _decodeFlac(source)
      : lower.endsWith('.wav')
      ? _decodeWav(source)
      : null;
  if (pcm == null) return false;
  File(target).writeAsBytesSync(
    buildPcmWav(
      pcm: pcm,
      sampleRate: whisperSampleRate,
      channels: 1,
      bitsPerSample: 16,
    ),
    flush: true,
  );
  return true;
}

/// Downmixes and resamples to 16 kHz by averaging the input frames that fall
/// into each output sample, which also acts as the low-pass filter.
class WhisperDownsampler {
  WhisperDownsampler(this.sampleRate);

  final int sampleRate;
  final BytesBuilder _out = BytesBuilder(copy: false);
  final Int16List _buffer = Int16List(4096);
  int _buffered = 0;
  int _frame = 0;
  int _bucket = 0;
  double _sum = 0;
  int _count = 0;

  /// [sample] is the mono mix in -1..1.
  void add(double sample) {
    final bucket = (_frame * whisperSampleRate) ~/ sampleRate;
    if (bucket != _bucket && _count > 0) _emit();
    _bucket = bucket;
    _sum += sample;
    _count++;
    _frame++;
  }

  void _emit() {
    _buffer[_buffered++] = (_sum / _count * 32767).round().clamp(-32768, 32767);
    _sum = 0;
    _count = 0;
    if (_buffered == _buffer.length) _flush();
  }

  void _flush() {
    _out.add(Uint8List.fromList(_buffer.buffer.asUint8List(0, _buffered * 2)));
    _buffered = 0;
  }

  Uint8List finish() {
    if (_count > 0) _emit();
    _flush();
    return _out.takeBytes();
  }
}

Uint8List? _decodeWav(String source) {
  final input = File(source).openSync();
  try {
    final head = input.readSync(64 * 1024);
    final info = readWavInfo(head);
    if (info == null ||
        info.format != 1 ||
        (info.bitsPerSample != 16 && info.bitsPerSample != 24) ||
        info.sampleRate < whisperSampleRate) {
      return null;
    }
    final channels = info.channels;
    final bytesPerSample = info.bitsPerSample ~/ 8;
    final frameBytes = info.blockAlign;
    final available = input.lengthSync() - info.dataOffset;
    final declared = ByteData.sublistView(
      head,
    ).getUint32(info.dataOffset - 4, Endian.little);
    // A header never finalized after a crash declares 0 or too much.
    final total = declared == 0 || declared > available ? available : declared;
    input.setPositionSync(info.dataOffset);

    final down = WhisperDownsampler(info.sampleRate);
    final scale = 1 / (channels * (bytesPerSample == 2 ? 32768 : 8388608));
    var read = 0;
    while (read < total) {
      final frames = ((total - read) ~/ frameBytes).clamp(0, 16384);
      if (frames == 0) break;
      final bytes = input.readSync(frames * frameBytes);
      if (bytes.isEmpty) break;
      read += bytes.length;
      final view = ByteData.sublistView(bytes);
      for (var f = 0; f + frameBytes <= bytes.length; f += frameBytes) {
        var mix = 0;
        for (var c = 0; c < channels; c++) {
          final at = f + c * bytesPerSample;
          mix += bytesPerSample == 2
              ? view.getInt16(at, Endian.little)
              : (bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16) <<
                    8 >>
                    8;
        }
        down.add(mix * scale);
      }
    }
    return down.finish();
  } finally {
    input.closeSync();
  }
}

typedef _ReadDecoder =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Pointer<IntPtr>,
      Pointer<Void>,
    );
typedef _WriteDecoder =
    Int32 Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Int32>>,
      Pointer<Void>,
    );
typedef _ErrorDecoder = Void Function(Pointer<Void>, Int32, Pointer<Void>);

/// Streams the file through libFLAC (bundled by flutter_soloud).
Uint8List? _decodeFlac(String source) {
  final lib = SleepFlacCodec.library();
  final create = lib
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'FLAC__stream_decoder_new',
      );
  final destroy = lib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FLAC__stream_decoder_delete');
  final finish = lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('FLAC__stream_decoder_finish');
  final process = lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('FLAC__stream_decoder_process_until_end_of_stream');
  int Function(Pointer<Void>) get(String name) =>
      lib.lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >(name);
  final blockSize = get('FLAC__stream_decoder_get_blocksize');
  final sampleRate = get('FLAC__stream_decoder_get_sample_rate');
  final channels = get('FLAC__stream_decoder_get_channels');
  final bits = get('FLAC__stream_decoder_get_bits_per_sample');
  final init = lib
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<NativeFunction<_ReadDecoder>>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<NativeFunction<_WriteDecoder>>,
          Pointer<Void>,
          Pointer<NativeFunction<_ErrorDecoder>>,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<NativeFunction<_ReadDecoder>>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<NativeFunction<_WriteDecoder>>,
          Pointer<Void>,
          Pointer<NativeFunction<_ErrorDecoder>>,
          Pointer<Void>,
        )
      >('FLAC__stream_decoder_init_stream');

  final file = File(source).openSync();
  final decoder = create();
  if (decoder == nullptr) {
    file.closeSync();
    return null;
  }
  WhisperDownsampler? down;
  var failed = false;
  final read = NativeCallable<_ReadDecoder>.isolateLocal((
    Pointer<Void> _,
    Pointer<Uint8> target,
    Pointer<IntPtr> length,
    Pointer<Void> _,
  ) {
    final count = file.readIntoSync(target.asTypedList(length.value));
    length.value = count;
    return count == 0 ? 1 : 0;
  }, exceptionalReturn: 2);
  final write = NativeCallable<_WriteDecoder>.isolateLocal((
    Pointer<Void> d,
    Pointer<Void> _,
    Pointer<Pointer<Int32>> buffers,
    Pointer<Void> _,
  ) {
    final rate = sampleRate(d);
    final count = channels(d);
    if (rate < whisperSampleRate || count == 0) {
      failed = true;
      return 1;
    }
    down ??= WhisperDownsampler(rate);
    final scale = 1 / (count * (1 << (bits(d) - 1)));
    final size = blockSize(d);
    final planes = [
      for (var c = 0; c < count; c++) (buffers + c).value.asTypedList(size),
    ];
    for (var i = 0; i < size; i++) {
      var mix = 0;
      for (final plane in planes) {
        mix += plane[i];
      }
      down!.add(mix * scale);
    }
    return 0;
  }, exceptionalReturn: 1);
  final error = NativeCallable<_ErrorDecoder>.isolateLocal((
    Pointer<Void> _,
    int _,
    Pointer<Void> _,
  ) {
    failed = true;
  });
  var initialized = false;
  try {
    if (init(
          decoder,
          read.nativeFunction,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
          write.nativeFunction,
          nullptr,
          error.nativeFunction,
          nullptr,
        ) !=
        0) {
      return null;
    }
    initialized = true;
    if (process(decoder) == 0 || failed) return null;
    return down?.finish();
  } finally {
    if (initialized) finish(decoder);
    destroy(decoder);
    read.close();
    write.close();
    error.close();
    file.closeSync();
  }
}

/// Whisper encodes fixed 30 s windows and pads anything shorter, so audio is
/// split into as few pieces as possible, all of similar length and none over
/// 30 s. Each cut lands on the quietest 100 ms within [search] samples of its
/// even split point so words stay whole. Returns the start offsets, from 0.
List<int> whisperChunkStarts(
  Int16List pcm, {
  int maxChunk = 29 * whisperSampleRate,
  int search = whisperSampleRate ~/ 2,
}) {
  const window = whisperSampleRate ~/ 10;
  final count = (pcm.length / maxChunk).ceil();
  final starts = <int>[0];
  for (var c = 1; c < count; c++) {
    final target = pcm.length * c ~/ count;
    var best = target;
    var bestEnergy = double.infinity;
    for (var w = target - search; w + window <= target + search; w += window) {
      var energy = 0.0;
      for (var i = w; i < w + window; i++) {
        energy += pcm[i] * pcm[i];
      }
      if (energy < bestEnergy) {
        bestEnergy = energy;
        best = w + window ~/ 2;
      }
    }
    starts.add(best);
  }
  return starts;
}

/// Writes the 16 kHz mono WAV at [source] as chunk files `[prefix]_N.wav`.
/// Returns each chunk's path and start offset in samples.
List<({String path, int start})> splitWhisperWav(String source, String prefix) {
  final bytes = File(source).readAsBytesSync();
  final info = readWavInfo(bytes);
  if (info == null) return const [];
  final pcm = Int16List.sublistView(
    bytes,
    info.dataOffset,
    info.dataOffset + info.dataLength - info.dataLength % 2,
  );
  final starts = whisperChunkStarts(Int16List.fromList(pcm));
  final chunks = <({String path, int start})>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : pcm.length;
    final path = '${prefix}_$i.wav';
    File(path).writeAsBytesSync(
      buildPcmWav(
        pcm: Uint8List.sublistView(
          bytes,
          info.dataOffset + starts[i] * 2,
          info.dataOffset + end * 2,
        ),
        sampleRate: whisperSampleRate,
        channels: 1,
        bitsPerSample: 16,
      ),
    );
    chunks.add((path: path, start: starts[i]));
  }
  return chunks;
}
