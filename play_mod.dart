import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:tool_lab/tools/chiptune/engine/parser.dart';
import 'package:tool_lab/tools/chiptune/engine/mixer.dart';
import 'package:tool_lab/tools/chiptune/engine/module.dart';

// ============================================================================
// AUDIO OUTPUT INTERFACE
// ============================================================================
abstract class AudioOutput {
  void write(Int16List data);
  void close();
}

// ============================================================================
// LINUX ALSA IMPLEMENTATION
// ============================================================================
typedef SndPcmOpenC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Pointer<ffi.Void>> pcm,
      ffi.Pointer<Utf8> name,
      ffi.Int32 stream,
      ffi.Int32 mode,
    );
typedef SndPcmOpenDart =
    int Function(
      ffi.Pointer<ffi.Pointer<ffi.Void>> pcm,
      ffi.Pointer<Utf8> name,
      int stream,
      int mode,
    );

typedef SndPcmSetParamsC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> pcm,
      ffi.Int32 format,
      ffi.Int32 access,
      ffi.Uint32 channels,
      ffi.Uint32 rate,
      ffi.Int32 softResample,
      ffi.Uint32 latency,
    );
typedef SndPcmSetParamsDart =
    int Function(
      ffi.Pointer<ffi.Void> pcm,
      int format,
      int access,
      int channels,
      int rate,
      int softResample,
      int latency,
    );

typedef SndPcmWriteiC =
    ffi.Long Function(
      ffi.Pointer<ffi.Void> pcm,
      ffi.Pointer<ffi.Void> buffer,
      ffi.UnsignedLong size,
    );
typedef SndPcmWriteiDart =
    int Function(
      ffi.Pointer<ffi.Void> pcm,
      ffi.Pointer<ffi.Void> buffer,
      int size,
    );

typedef SndPcmRecoverC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> pcm,
      ffi.Int32 err,
      ffi.Int32 silent,
    );
typedef SndPcmRecoverDart =
    int Function(ffi.Pointer<ffi.Void> pcm, int err, int silent);

typedef SndPcmCloseC = ffi.Int32 Function(ffi.Pointer<ffi.Void> pcm);
typedef SndPcmCloseDart = int Function(ffi.Pointer<ffi.Void> pcm);

class AlsaAudioOutput implements AudioOutput {
  final ffi.Pointer<ffi.Void> pcm;
  final SndPcmWriteiDart sndPcmWritei;
  final SndPcmRecoverDart sndPcmRecover;
  final SndPcmCloseDart sndPcmClose;
  final ffi.Pointer<ffi.Int16> nativeBuffer;

  AlsaAudioOutput({
    required this.pcm,
    required this.sndPcmWritei,
    required this.sndPcmRecover,
    required this.sndPcmClose,
    required this.nativeBuffer,
  });

  @override
  void write(Int16List data) {
    nativeBuffer.asTypedList(data.length).setAll(0, data);
    final frames = data.length ~/ 2;
    final written = sndPcmWritei(pcm, nativeBuffer.cast(), frames);
    if (written < 0) {
      sndPcmRecover(pcm, written, 1);
    }
  }

  @override
  void close() {
    calloc.free(nativeBuffer);
    sndPcmClose(pcm);
  }
}

// ============================================================================
// WINDOWS WAVEOUT IMPLEMENTATION
// ============================================================================
typedef WaveOutOpenC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Pointer<ffi.Void>> phwo,
      ffi.Uint32 uDeviceID,
      ffi.Pointer<ffi.Void> pwfx,
      ffi.Pointer<ffi.Void> dwCallback,
      ffi.Pointer<ffi.Void> dwCallbackInstance,
      ffi.Uint32 fdwOpen,
    );
typedef WaveOutOpenDart =
    int Function(
      ffi.Pointer<ffi.Pointer<ffi.Void>> phwo,
      int uDeviceID,
      ffi.Pointer<ffi.Void> pwfx,
      ffi.Pointer<ffi.Void> dwCallback,
      ffi.Pointer<ffi.Void> dwCallbackInstance,
      int fdwOpen,
    );

typedef WaveOutPrepareHeaderC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      ffi.Uint32 cbwh,
    );
typedef WaveOutPrepareHeaderDart =
    int Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      int cbwh,
    );

typedef WaveOutWriteC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      ffi.Uint32 cbwh,
    );
typedef WaveOutWriteDart =
    int Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      int cbwh,
    );

typedef WaveOutUnprepareHeaderC =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      ffi.Uint32 cbwh,
    );
typedef WaveOutUnprepareHeaderDart =
    int Function(
      ffi.Pointer<ffi.Void> hwo,
      ffi.Pointer<ffi.Void> pwh,
      int cbwh,
    );

typedef WaveOutCloseC = ffi.Int32 Function(ffi.Pointer<ffi.Void> hwo);
typedef WaveOutCloseDart = int Function(ffi.Pointer<ffi.Void> hwo);

class WinAudioOutput implements AudioOutput {
  final ffi.Pointer<ffi.Void> hwo;
  final WaveOutPrepareHeaderDart waveOutPrepareHeader;
  final WaveOutWriteDart waveOutWrite;
  final WaveOutUnprepareHeaderDart waveOutUnprepareHeader;
  final WaveOutCloseDart waveOutClose;

  final int numBuffers = 3;
  final List<ffi.Pointer<ffi.Void>> headers = [];
  final List<ffi.Pointer<ffi.Int16>> buffers = [];
  final int bufferSizeInBytes;
  final int framesPerChunk;
  int writeIndex = 0;

  WinAudioOutput({
    required this.hwo,
    required this.waveOutPrepareHeader,
    required this.waveOutWrite,
    required this.waveOutUnprepareHeader,
    required this.waveOutClose,
    required this.framesPerChunk,
  }) : bufferSizeInBytes = framesPerChunk * 2 * 2 {
    for (int i = 0; i < numBuffers; i++) {
      final header = calloc<ffi.Uint8>(48); // WAVEHDR size
      final data = calloc<ffi.Int16>(framesPerChunk * 2);

      // Set lpData (offset 0)
      header.cast<ffi.Pointer<ffi.Void>>().value = data.cast();
      // Set dwBufferLength (offset 8)
      // Set dwBufferLength (offset 8)
      (header.cast<ffi.Uint8>() + 8).cast<ffi.Uint32>().value =
          bufferSizeInBytes;
      // Set dwFlags to WHDR_DONE (0x01) (offset 24)
      (header.cast<ffi.Uint8>() + 24).cast<ffi.Uint32>().value = 0x01;

      headers.add(header.cast());
      buffers.add(data);
    }
  }

  @override
  void write(Int16List data) {
    final header = headers[writeIndex];
    final buffer = buffers[writeIndex];

    // Wait until buffer playing completes (WHDR_DONE flag is set)
    final flagsPtr = (header.cast<ffi.Uint8>() + 24).cast<ffi.Uint32>();
    while ((flagsPtr.value & 0x01) == 0) {
      sleep(const Duration(milliseconds: 2));
    }

    // Unprepare header if previously prepared
    if ((flagsPtr.value & 0x02) != 0) {
      waveOutUnprepareHeader(hwo, header, 48);
    }

    // Copy new data
    buffer.asTypedList(data.length).setAll(0, data);

    // Prepare and play buffer
    waveOutPrepareHeader(hwo, header, 48);
    waveOutWrite(hwo, header, 48);

    writeIndex = (writeIndex + 1) % numBuffers;
  }

  @override
  void close() {
    // Graceful cleanup: wait for active buffers to complete
    for (int i = 0; i < numBuffers; i++) {
      final header = headers[i];
      final flagsPtr = (header.cast<ffi.Uint8>() + 24).cast<ffi.Uint32>();
      while ((flagsPtr.value & 0x01) == 0) {
        sleep(const Duration(milliseconds: 5));
      }
      if ((flagsPtr.value & 0x02) != 0) {
        waveOutUnprepareHeader(hwo, header, 48);
      }
      calloc.free(buffers[i]);
      calloc.free(headers[i]);
    }
    waveOutClose(hwo);
  }
}

// ============================================================================
// MAIN RUNTIME ENTRY
// ============================================================================
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run play_mod.dart <path_to_mod_file>');
    return;
  }

  final filePath = args[0];
  final modFile = File(filePath);
  if (!modFile.existsSync()) {
    print('Error: File not found at "$filePath"');
    return;
  }

  const sampleRate = 44100;
  const framesPerChunk = 1024;
  late final AudioOutput output;

  if (Platform.isLinux) {
    late final ffi.DynamicLibrary alsaLib;
    try {
      alsaLib = ffi.DynamicLibrary.open('libasound.so.2');
    } catch (e) {
      print('Error: Could not load ALSA library (libasound.so.2).');
      return;
    }

    final sndPcmOpen = alsaLib.lookupFunction<SndPcmOpenC, SndPcmOpenDart>(
      'snd_pcm_open',
    );
    final sndPcmSetParams = alsaLib
        .lookupFunction<SndPcmSetParamsC, SndPcmSetParamsDart>(
          'snd_pcm_set_params',
        );
    final sndPcmWritei = alsaLib
        .lookupFunction<SndPcmWriteiC, SndPcmWriteiDart>('snd_pcm_writei');
    final sndPcmRecover = alsaLib
        .lookupFunction<SndPcmRecoverC, SndPcmRecoverDart>('snd_pcm_recover');
    final sndPcmClose = alsaLib.lookupFunction<SndPcmCloseC, SndPcmCloseDart>(
      'snd_pcm_close',
    );

    final pcmPtrPtr = calloc<ffi.Pointer<ffi.Void>>();
    final deviceName = 'default'.toNativeUtf8();

    int err = sndPcmOpen(pcmPtrPtr, deviceName, 0, 0);
    calloc.free(deviceName);

    if (err < 0) {
      print('Error opening ALSA device: $err');
      calloc.free(pcmPtrPtr);
      return;
    }

    final pcm = pcmPtrPtr.value;
    calloc.free(pcmPtrPtr);

    // format: S16_LE (2), access: RW_INTERLEAVED (3), stereo channels (2), 50ms latency (50000us)
    err = sndPcmSetParams(pcm, 2, 3, 2, sampleRate, 1, 50000);
    if (err < 0) {
      print('Error setting ALSA PCM parameters: $err');
      sndPcmClose(pcm);
      return;
    }

    final nativeBuffer = calloc<ffi.Int16>(framesPerChunk * 2);
    output = AlsaAudioOutput(
      pcm: pcm,
      sndPcmWritei: sndPcmWritei,
      sndPcmRecover: sndPcmRecover,
      sndPcmClose: sndPcmClose,
      nativeBuffer: nativeBuffer,
    );
  } else if (Platform.isWindows) {
    late final ffi.DynamicLibrary winmmLib;
    try {
      winmmLib = ffi.DynamicLibrary.open('winmm.dll');
    } catch (e) {
      print('Error: Could not load WinMM library (winmm.dll).');
      return;
    }

    final waveOutOpen = winmmLib.lookupFunction<WaveOutOpenC, WaveOutOpenDart>(
      'waveOutOpen',
    );
    final waveOutPrepareHeader = winmmLib
        .lookupFunction<WaveOutPrepareHeaderC, WaveOutPrepareHeaderDart>(
          'waveOutPrepareHeader',
        );
    final waveOutWrite = winmmLib
        .lookupFunction<WaveOutWriteC, WaveOutWriteDart>('waveOutWrite');
    final waveOutUnprepareHeader = winmmLib
        .lookupFunction<WaveOutUnprepareHeaderC, WaveOutUnprepareHeaderDart>(
          'waveOutUnprepareHeader',
        );
    final waveOutClose = winmmLib
        .lookupFunction<WaveOutCloseC, WaveOutCloseDart>('waveOutClose');

    final hwoPtr = calloc<ffi.Pointer<ffi.Void>>();
    final wfx = calloc<ffi.Uint8>(18); // WAVEFORMATEX struct size

    wfx.cast<ffi.Uint16>().value = 1; // wFormatTag (PCM)
    (wfx.cast<ffi.Uint16>() + 1).value = 2; // nChannels (2)
    (wfx.cast<ffi.Uint8>() + 4).cast<ffi.Uint32>().value =
        sampleRate; // nSamplesPerSec
    (wfx.cast<ffi.Uint8>() + 8).cast<ffi.Uint32>().value =
        sampleRate * 4; // nAvgBytesPerSec
    (wfx.cast<ffi.Uint8>() + 12).cast<ffi.Uint16>().value = 4; // nBlockAlign
    (wfx.cast<ffi.Uint8>() + 14).cast<ffi.Uint16>().value =
        16; // wBitsPerSample
    (wfx.cast<ffi.Uint8>() + 16).cast<ffi.Uint16>().value = 0; // cbSize

    // WAVE_MAPPER is 0xFFFFFFFF
    int err = waveOutOpen(
      hwoPtr,
      0xFFFFFFFF,
      wfx.cast(),
      ffi.nullptr,
      ffi.nullptr,
      0,
    );
    calloc.free(wfx);

    if (err != 0) {
      print('Error opening Windows waveOut device: $err');
      calloc.free(hwoPtr);
      return;
    }

    final hwo = hwoPtr.value;
    calloc.free(hwoPtr);

    output = WinAudioOutput(
      hwo: hwo,
      waveOutPrepareHeader: waveOutPrepareHeader,
      waveOutWrite: waveOutWrite,
      waveOutUnprepareHeader: waveOutUnprepareHeader,
      waveOutClose: waveOutClose,
      framesPerChunk: framesPerChunk,
    );
  } else {
    print('Unsupported platform: ${Platform.operatingSystem}');
    return;
  }

  // --- Parse module using our engine's parser ---
  final bytes = modFile.readAsBytesSync();
  final mod = parseModule(bytes);

  // --- Print detailed Module Metadata info ---
  print(
    '========================================================================',
  );
  print('MODULE METADATA');
  print(
    '========================================================================',
  );
  print('Title:         ${mod.title.isNotEmpty ? mod.title : "<Untitled>"}');
  print('Format Type:   ${mod.type}');
  print('Channels:      ${mod.channels}');
  print('Patterns:      ${mod.patterns.length}');
  print('Song Length:   ${mod.sequence.length} positions');
  print('Instruments:   ${mod.instruments.length}');
  print('Default BPM:   ${mod.defaultBpm}');
  print('Default Speed: ${mod.defaultSpeed} ticks/row');
  print(
    '========================================================================',
  );
  print('INSTRUMENTS & SAMPLES');
  print(
    '========================================================================',
  );
  for (int i = 0; i < mod.instruments.length; i++) {
    final inst = mod.instruments[i];
    if (inst.samples.isEmpty) continue;
    final samplesInfo = inst.samples
        .where((s) => s.length > 0)
        .map(
          (s) => 'Sample(name="${s.name}", len=${s.length}, vol=${s.volume})',
        )
        .join(', ');
    if (samplesInfo.isNotEmpty || inst.name.trim().isNotEmpty) {
      print(
        'Instrument #${(i + 1).toString().padRight(2)}: "${inst.name.trim()}" ${samplesInfo.isNotEmpty ? "[$samplesInfo]" : ""}',
      );
    }
  }
  print(
    '========================================================================',
  );
  print('Live playing... Press Ctrl+C to stop.');

  final mixer = ChiptuneMixer();
  mixer.loadAndPlay(serializeModuleForWorklet(mod), sampleRate, looping: true);

  final tempBuffer = Float32List(framesPerChunk * 2);
  final pcmBuffer = Int16List(framesPerChunk * 2);

  try {
    while (mixer.playing) {
      mixer.render(tempBuffer, framesPerChunk);
      if (!mixer.playing) break;

      // Scale float samples to 16-bit PCM
      for (int i = 0; i < framesPerChunk * 2; i++) {
        final scaledVal = (tempBuffer[i] * 32767.0).round();
        pcmBuffer[i] = scaledVal.clamp(-32768, 32767);
      }

      // Write PCM data to device
      output.write(pcmBuffer);
    }
  } finally {
    output.close();
    print('\nPlayback stopped.');
  }
}
