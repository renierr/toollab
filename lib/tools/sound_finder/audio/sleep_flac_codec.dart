import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../helpers/wav_decoder.dart';

typedef _WriteEncoder =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      IntPtr,
      Uint32,
      Uint32,
      Pointer<Void>,
    );
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

/// Native FLAC codec supplied by flutter_soloud. Inputs are mono PCM16.
class SleepFlacCodec {
  SleepFlacCodec._();

  static DynamicLibrary _library() {
    if (Platform.isAndroid) return DynamicLibrary.open('libFLAC.so');
    if (Platform.isWindows) return DynamicLibrary.open('FLAC.dll');
    if (Platform.isLinux) return DynamicLibrary.open('libFLAC.so.14');
    throw UnsupportedError('FLAC is unavailable on this platform');
  }

  static Uint8List encode(Int16List samples, int sampleRate) {
    final lib = _library();
    final create = lib
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'FLAC__stream_encoder_new',
        );
    final destroy = lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('FLAC__stream_encoder_delete');
    final finish = lib
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('FLAC__stream_encoder_finish');
    int Function(Pointer<Void>, int) setter(String name) =>
        lib.lookupFunction<
          Int32 Function(Pointer<Void>, Uint32),
          int Function(Pointer<Void>, int)
        >(name);
    final init = lib
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Pointer<NativeFunction<_WriteEncoder>>,
            Pointer<Void>,
            Pointer<Void>,
            Pointer<Void>,
            Pointer<Void>,
          ),
          int Function(
            Pointer<Void>,
            Pointer<NativeFunction<_WriteEncoder>>,
            Pointer<Void>,
            Pointer<Void>,
            Pointer<Void>,
            Pointer<Void>,
          )
        >('FLAC__stream_encoder_init_stream');
    final process = lib
        .lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Int32>, Uint32),
          int Function(Pointer<Void>, Pointer<Int32>, int)
        >('FLAC__stream_encoder_process_interleaved');
    final encoder = create();
    if (encoder == nullptr) throw StateError('FLAC encoder allocation failed');
    final out = BytesBuilder(copy: false);
    Object? callbackError;
    final callback = NativeCallable<_WriteEncoder>.isolateLocal((
      Pointer<Void> _,
      Pointer<Uint8> bytes,
      int length,
      int _,
      int _,
      Pointer<Void> _,
    ) {
      try {
        out.add(Uint8List.fromList(bytes.asTypedList(length)));
        return 0;
      } catch (e) {
        callbackError = e;
        return 1;
      }
    }, exceptionalReturn: 1);
    final buffer = calloc<Int32>(samples.length);
    var initialized = false;
    try {
      if (setter('FLAC__stream_encoder_set_channels')(encoder, 1) == 0 ||
          setter('FLAC__stream_encoder_set_bits_per_sample')(encoder, 16) ==
              0 ||
          setter('FLAC__stream_encoder_set_sample_rate')(encoder, sampleRate) ==
              0 ||
          setter('FLAC__stream_encoder_set_compression_level')(encoder, 5) ==
              0 ||
          setter('FLAC__stream_encoder_set_verify')(encoder, 1) == 0) {
        throw StateError('FLAC encoder configuration failed');
      }
      final setTotal = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Uint64),
            int Function(Pointer<Void>, int)
          >('FLAC__stream_encoder_set_total_samples_estimate');
      if (setTotal(encoder, samples.length) == 0) {
        throw StateError('FLAC sample count configuration failed');
      }
      final status = init(
        encoder,
        callback.nativeFunction,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
      );
      if (status != 0) {
        final state = lib
            .lookupFunction<
              Int32 Function(Pointer<Void>),
              int Function(Pointer<Void>)
            >('FLAC__stream_encoder_get_state')(encoder);
        throw StateError(
          'FLAC encoder initialization failed: $status / $state / $callbackError',
        );
      }
      initialized = true;
      buffer.asTypedList(samples.length).setAll(0, samples);
      if (process(encoder, buffer, samples.length) == 0 ||
          finish(encoder) == 0) {
        initialized = false;
        throw StateError('FLAC encoding failed');
      }
      initialized = false;
      return out.takeBytes();
    } finally {
      if (initialized) finish(encoder);
      destroy(encoder);
      callback.close();
      calloc.free(buffer);
    }
  }

  static WavAudioData decode(Uint8List bytes) {
    final lib = _library();
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
    final decoder = create();
    if (decoder == nullptr) throw StateError('FLAC decoder allocation failed');
    var offset = 0;
    var rate = 0;
    var failed = false;
    final output = <Float32List>[];
    final read = NativeCallable<_ReadDecoder>.isolateLocal((
      Pointer<Void> _,
      Pointer<Uint8> target,
      Pointer<IntPtr> length,
      Pointer<Void> _,
    ) {
      final count = math.min(length.value, bytes.length - offset);
      if (count == 0) {
        length.value = 0;
        return 1;
      }
      target.asTypedList(count).setRange(0, count, bytes, offset);
      offset += count;
      length.value = count;
      return 0;
    }, exceptionalReturn: 2);
    final write = NativeCallable<_WriteDecoder>.isolateLocal((
      Pointer<Void> d,
      Pointer<Void> _,
      Pointer<Pointer<Int32>> buffers,
      Pointer<Void> _,
    ) {
      if (channels(d) != 1 || bits(d) != 16) {
        failed = true;
        return 1;
      }
      rate = sampleRate(d);
      final pcm = buffers.value.asTypedList(blockSize(d));
      output.add(Float32List.fromList(pcm.map((v) => v / 32768.0).toList()));
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
        throw const FormatException('FLAC decoder initialization failed');
      }
      initialized = true;
      if (process(decoder) == 0 || failed || rate == 0) {
        throw const FormatException('Invalid FLAC audio');
      }
      final samples = Float32List(
        output.fold(0, (n, chunk) => n + chunk.length),
      );
      var index = 0;
      for (final chunk in output) {
        samples.setAll(index, chunk);
        index += chunk.length;
      }
      return WavAudioData(samples: samples, sampleRate: rate, channels: 1);
    } finally {
      if (initialized) finish(decoder);
      destroy(decoder);
      read.close();
      write.close();
      error.close();
    }
  }
}
