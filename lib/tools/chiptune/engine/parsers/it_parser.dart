// ignore_for_file: constant_identifier_names

import 'dart:math' as math;
import 'dart:typed_data';

import '../module.dart';
import 'it_decompress.dart';

/// IT-specific effect constants (0x20+) to avoid collisions with MOD/XM effects.
/// These are handled specially by the mixer for IT format.
const int IT_EFFECT_SET_SPEED = 0x20; // Axx: always speed (ticks/row)
const int IT_EFFECT_SET_TEMPO = 0x21; // Txx: always tempo (BPM)
const int IT_EFFECT_FINE_VOLSLIDE_UP = 0x22; // DxF fine volume slide up
const int IT_EFFECT_FINE_VOLSLIDE_DOWN = 0x23; // DFy fine volume slide down
const int IT_EFFECT_FINE_PORTA_DOWN = 0x24; // EFx fine portamento down
const int IT_EFFECT_FINE_PORTA_UP = 0x25; // FFx fine portamento up
const int IT_EFFECT_EXTRA_FINE_PORTA_DOWN = 0x26; // EEx extra-fine porta down
const int IT_EFFECT_EXTRA_FINE_PORTA_UP = 0x27; // FEx extra-fine porta up
const int IT_EFFECT_SET_CHANNEL_VOLUME = 0x28; // Mxx set channel volume
const int IT_EFFECT_CHANNEL_VOL_SLIDE = 0x29; // Nxx channel volume slide
const int IT_EFFECT_FINE_VIBRATO = 0x2a; // Uxx fine vibrato
const int IT_EFFECT_TEMPO_SLIDE = 0x2b; // T0x / Tx0 tempo slide
const int IT_EFFECT_SET_FILTER_CUTOFF = 0x2c; // Zxx default macro cutoff

/// IT effect letter -> effect number translation.
/// IT stores effects as 1-based letter indices (A=1, B=2, ...).
/// We translate to MOD/XM-compatible numbering where possible, and use
/// IT-specific constants (0x20+) for effects that differ from MOD/XM semantics.
List<int> _translateItEffect(int itCmd, int itParam) {
  // itCmd: 0=none, 1=A, 2=B, 3=C, ...
  switch (itCmd) {
    case 0:
      return [0, 0]; // No effect
    case 1: // A: Set Speed (ticks/row) - IT A is ALWAYS speed, never tempo
      return [IT_EFFECT_SET_SPEED, itParam];
    case 2: // B: Position Jump -> MOD 0x0B
      return [0x0b, itParam];
    case 3: // C: Pattern Break -> MOD 0x0D (IT uses hex param, NOT BCD)
      return [0x0d, itParam];
    case 4: // D: Volume Slide - detect fine variants
      return _translateItVolSlide(itParam);
    case 5: // E: Portamento Down - detect fine/extra-fine variants
      return _translateItPortaDown(itParam);
    case 6: // F: Portamento Up - detect fine/extra-fine variants
      return _translateItPortaUp(itParam);
    case 7: // G: Tone Portamento -> MOD 0x03
      return [0x03, itParam];
    case 8: // H: Vibrato -> MOD 0x04
      return [0x04, itParam];
    case 9: // I: Tremor -> 0x1D (already defined in worklet)
      return [0x1d, itParam];
    case 10: // J: Arpeggio -> MOD 0x00
      return [0x00, itParam];
    case 11: // K: Vibrato + Volume Slide -> MOD 0x06
      return [0x06, itParam];
    case 12: // L: Tone Porta + Volume Slide -> MOD 0x05
      return [0x05, itParam];
    case 13: // M: Set Channel Volume (IT-specific)
      return [IT_EFFECT_SET_CHANNEL_VOLUME, math.min(itParam, 64)];
    case 14: // N: Channel Volume Slide (IT-specific)
      return [IT_EFFECT_CHANNEL_VOL_SLIDE, itParam];
    case 15: // O: Sample Offset -> MOD 0x09
      return [0x09, itParam];
    case 16: // P: Panning Slide -> 0x19
      return [0x19, itParam];
    case 17: // Q: Retrigger + Volume Slide -> 0x1B
      return [0x1b, itParam];
    case 18: // R: Tremolo -> MOD 0x07
      return [0x07, itParam];
    case 19: // S: Special/Extended -> MOD 0x0E
      return _translateItSCommand(itParam);
    case 20: // T: Tempo command
      // IT: T20..FF set tempo, T0x/Tx0 slide tempo.
      if (itParam >= 0x20) return [IT_EFFECT_SET_TEMPO, itParam];
      return [IT_EFFECT_TEMPO_SLIDE, itParam];
    case 21: // U: Fine Vibrato (IT-specific)
      return [IT_EFFECT_FINE_VIBRATO, itParam];
    case 22: // V: Set Global Volume -> 0x10
      // IT Vxx is 0-128, internal engine uses 0-64.
      return [0x10, math.min(64, (itParam / 2).round())];
    case 23: // W: Global Volume Slide -> 0x11
      return _translateItGlobalVolSlide(itParam);
    case 24: // X: Set Panning -> MOD 0x08
      // IT X panning: 0x00=left, 0x80=center, 0xFF=right
      return [0x08, itParam];
    case 25: // Y: Panbrello (ignore)
      return [0, 0];
    case 26: // Z: MIDI Macro (default IT macro commonly maps to filter cutoff)
      return [IT_EFFECT_SET_FILTER_CUTOFF, itParam & 0x7f];
    default:
      return [0, 0];
  }
}

/// Translate IT Dxy (Volume Slide) with fine variant detection
List<int> _translateItVolSlide(int param) {
  final hi = (param >> 4) & 0x0f;
  final lo = param & 0x0f;
  if (hi == 0x0f && lo > 0) {
    // DFy: Fine volume slide down by y (tick 0 only)
    return [IT_EFFECT_FINE_VOLSLIDE_DOWN, lo];
  }
  if (lo == 0x0f && hi > 0) {
    // DxF: Fine volume slide up by x (tick 0 only)
    return [IT_EFFECT_FINE_VOLSLIDE_UP, hi];
  }
  // Regular volume slide
  return [0x0a, param];
}

/// Translate IT Exx (Portamento Down) with fine/extra-fine detection
List<int> _translateItPortaDown(int param) {
  if (param >= 0xf0) {
    // EFx: Fine portamento down (tick 0 only)
    return [IT_EFFECT_FINE_PORTA_DOWN, param & 0x0f];
  }
  if (param >= 0xe0) {
    // EEx: Extra-fine portamento down (tick 0 only, 4x smaller)
    return [IT_EFFECT_EXTRA_FINE_PORTA_DOWN, param & 0x0f];
  }
  // Regular portamento down
  return [0x02, param];
}

/// Translate IT Fxx (Portamento Up) with fine/extra-fine detection
List<int> _translateItPortaUp(int param) {
  if (param >= 0xf0) {
    // FFx: Fine portamento up (tick 0 only)
    return [IT_EFFECT_FINE_PORTA_UP, param & 0x0f];
  }
  if (param >= 0xe0) {
    // FEx: Extra-fine portamento up (tick 0 only, 4x smaller)
    return [IT_EFFECT_EXTRA_FINE_PORTA_UP, param & 0x0f];
  }
  // Regular portamento up
  return [0x01, param];
}

/// Translate IT Wxy (Global Volume Slide) from 0-128 domain to internal 0-64 domain
List<int> _translateItGlobalVolSlide(int param) {
  final up = (param >> 4) & 0x0f;
  final down = param & 0x0f;

  if (up > 0 && down == 0) {
    final scaledUp = math.max(1, (up / 2).round());
    return [0x11, scaledUp << 4];
  }

  if (down > 0 && up == 0) {
    final scaledDown = math.max(1, (down / 2).round());
    return [0x11, scaledDown];
  }

  // Mixed nibbles are uncommon; keep original encoding.
  return [0x11, param];
}

/// Translate IT S (Special) sub-commands to MOD E sub-commands
List<int> _translateItSCommand(int param) {
  final sub = (param >> 4) & 0x0f;
  final subParam = param & 0x0f;
  switch (sub) {
    case 0x0: // S0x: Set Filter -> E0x
      return [0x0e, param];
    case 0x1: // S1x: Set Glissando -> E3x
      return [0x0e, 0x30 | subParam];
    case 0x3: // S3x: Vibrato Waveform -> E4x
      return [0x0e, 0x40 | subParam];
    case 0x4: // S4x: Tremolo Waveform -> E7x
      return [0x0e, 0x70 | subParam];
    case 0x8: // S8x: Set Panning (coarse) -> E8x
      return [0x08, subParam * 17]; // 0-F -> 0-255
    case 0xb: // SBx: Pattern Loop -> E6x
      return [0x0e, 0x60 | subParam];
    case 0xc: // SCx: Note Cut -> ECx
      return [0x0e, 0xc0 | subParam];
    case 0xd: // SDx: Note Delay -> EDx
      return [0x0e, 0xd0 | subParam];
    case 0xe: // SEx: Pattern Delay -> EEx
      return [0x0e, 0xe0 | subParam];
    default:
      return [0x0e, param];
  }
}

/// Parsed IT volume column result.
class _ItVolumeColumn {
  final int? volume;
  final int? volumeColumn;
  final int effect;
  final int effectParam;
  const _ItVolumeColumn(
    this.volume,
    this.volumeColumn,
    this.effect,
    this.effectParam,
  );
}

/// Parse an IT volume column byte into standard volume + volumeColumn fields
_ItVolumeColumn _parseItVolumeColumn(int vol) {
  if (vol <= 64) {
    return _ItVolumeColumn(vol, null, 0, 0);
  }
  if (vol >= 65 && vol <= 74) {
    // Fine Volume Up (tick 0 only) -> E sub-command 0xA
    final amt = vol - 65;
    return _ItVolumeColumn(null, null, 0x0e, 0xa0 | amt);
  }
  if (vol >= 75 && vol <= 84) {
    // Fine Volume Down (tick 0 only) -> E sub-command 0xB
    final amt = vol - 75;
    return _ItVolumeColumn(null, null, 0x0e, 0xb0 | amt);
  }
  if (vol >= 85 && vol <= 94) {
    // Volume Slide Up
    final amt = vol - 85;
    return _ItVolumeColumn(null, null, 0x0a, amt << 4);
  }
  if (vol >= 95 && vol <= 104) {
    // Volume Slide Down
    final amt = vol - 95;
    return _ItVolumeColumn(null, null, 0x0a, amt);
  }
  if (vol >= 128 && vol <= 192) {
    // Set Panning (0-64 -> 0-255)
    final pan = (((vol - 128) / 64) * 255).round();
    return _ItVolumeColumn(null, null, 0x08, pan);
  }
  if (vol >= 105 && vol <= 114) {
    // Portamento Down
    final spd = vol - 105;
    return _ItVolumeColumn(null, null, 0x02, spd * 4);
  }
  if (vol >= 115 && vol <= 124) {
    // Portamento Up
    final spd = vol - 115;
    return _ItVolumeColumn(null, null, 0x01, spd * 4);
  }
  if (vol >= 193 && vol <= 202) {
    // Tone Portamento
    final spd = vol - 193;
    return _ItVolumeColumn(null, null, 0x03, spd * 4);
  }
  if (vol >= 203 && vol <= 212) {
    // Vibrato Depth
    final depth = vol - 203;
    return _ItVolumeColumn(null, null, 0x04, depth);
  }
  return _ItVolumeColumn(null, null, 0, 0);
}

Float32List _decodeCompressedItSample(
  Uint8List data,
  int samplePointer,
  int sampleLength,
  bool is16Bit,
  bool preferIT215,
  bool isSigned,
) {
  return is16Bit
      ? decompressIT16(data, samplePointer, sampleLength, preferIT215, isSigned)
      : decompressIT8(data, samplePointer, sampleLength, preferIT215, isSigned);
}

/// Parses an Impulse Tracker (.it) module into a [ModuleFile].
ModuleFile parseIt(Uint8List data) {
  final parser = _ItParser(data);
  return parser.parse();
}

/// Stateful byte reader + IT decode state.
class _ItParser {
  final Uint8List data;
  int pos = 0;

  _ItParser(this.data);

  int readU8() {
    return pos < data.length ? data[pos++] : 0;
  }

  int readU16LE() {
    if (pos + 2 > data.length) return 0;
    final v = data[pos] | (data[pos + 1] << 8);
    pos += 2;
    return v;
  }

  int readU32LE() {
    if (pos + 4 > data.length) return 0;
    final v =
        (data[pos] |
            (data[pos + 1] << 8) |
            (data[pos + 2] << 16) |
            (data[pos + 3] << 24)) &
        0xFFFFFFFF;
    pos += 4;
    return v;
  }

  String readStr(int len) {
    final s = readString(data, pos, len);
    pos += len;
    return s;
  }

  void setPos(int offset) {
    if (offset >= 0 && offset <= data.length) {
      pos = offset;
    }
  }

  ModuleFile parse() {
    if (data.length < 192 || readStr(4) != 'IMPM') {
      throw Exception('Not an IT file');
    }

    setPos(4);
    final title = readStr(26).trim();
    setPos(32);
    final ordNum = readU16LE();
    final insNum = readU16LE();
    final smpNum = readU16LE();
    final patNum = readU16LE();
    setPos(40);
    readU16LE(); // created with tracker version
    final cmwt = readU16LE(); // compatible minimum tracker version
    final flags = readU16LE();
    readU16LE(); // special
    setPos(48);
    final globalVol = readU8(); // GV (0-128)
    final mixVol = readU8(); // MV (0-128)
    final initSpeed = readU8();
    final initTempo = readU8();
    readU8(); // sep
    readU8(); // pwd

    // Jump to channel pan
    setPos(64);
    final chanPan = <int>[];
    for (int i = 0; i < 64; i++) {
      chanPan.add(readU8());
    }
    // Channel vols
    final chanVol = <int>[];
    for (int i = 0; i < 64; i++) {
      chanVol.add(readU8());
    }

    final sequence = <int>[];
    for (int i = 0; i < ordNum; i++) {
      sequence.add(readU8());
    }

    final activeChannels = <int>[];
    for (int i = 0; i < 64; i++) {
      if ((chanPan[i] & 128) == 0) activeChannels.add(i);
    }
    final channels = activeChannels.isNotEmpty
        ? activeChannels.reduce(math.max) + 1
        : 1;

    final channelVolumes = List<int>.filled(channels, 64);
    final channelPanning = List<int>.filled(channels, 128);
    for (int i = 0; i < channels; i++) {
      if ((chanPan[i] & 128) != 0) {
        channelVolumes[i] = 0; // disabled channel
        channelPanning[i] = 128;
      } else {
        channelVolumes[i] = math.max(0, math.min(64, chanVol[i] & 0x7f));
        channelPanning[i] = math.max(
          0,
          math.min(255, (((chanPan[i] & 0x7f) / 64) * 255).round()),
        );
      }
    }

    final insOffsets = <int>[];
    final smpOffsets = <int>[];
    final patOffsets = <int>[];
    for (int i = 0; i < insNum; i++) {
      insOffsets.add(readU32LE());
    }
    for (int i = 0; i < smpNum; i++) {
      smpOffsets.add(readU32LE());
    }
    for (int i = 0; i < patNum; i++) {
      patOffsets.add(readU32LE());
    }

    final rawSamples = <Sample>[];
    // IT compression mode must be consistent module-wide. Use compatibility target.
    final preferIT215ByCompat = cmwt >= 0x0215;
    for (int i = 0; i < smpNum; i++) {
      String name = 'Sample ${i + 1}';
      Float32List sampleData = Float32List(0);
      int smpLength = 0;
      int loopStart = 0;
      int loopLength = 0;
      int c5speed = 8363;
      int sVol = 64;
      int sampleGlobalVolume = 64;
      bool isPingPong = false;
      bool hasLoop = false;
      int dfp = 128; // default panning
      int vibratoType = 0;
      int vibratoSweep = 0;
      int vibratoDepth = 0;
      int vibratoRate = 0;

      if (smpOffsets[i] > 0) {
        setPos(smpOffsets[i]);
        if (readStr(4) == 'IMPS') {
          readStr(12); // dos filename
          readU8(); // zero
          sampleGlobalVolume = readU8(); // global volume (0-64)
          final sFlags = readU8();
          sVol = readU8(); // default volume (0-64)
          name = readStr(26).trim();
          final cvt = readU8();
          dfp =
              readU8(); // default pan (bit 7 = has panning, bits 0-6 = pan 0-64)
          smpLength = readU32LE();
          loopStart = readU32LE();
          final loopEnd = readU32LE();

          hasLoop = (sFlags & 0x10) != 0;
          isPingPong = (sFlags & 0x40) != 0;

          if (hasLoop) loopLength = loopEnd - loopStart;

          c5speed = readU32LE(); // C5 Speed
          readU32LE(); // susLoopStart
          readU32LE(); // susLoopEnd
          final samplePointer = readU32LE();
          // IT sample vibrato bytes: speed, depth, rate, waveform
          vibratoSweep = readU8();
          vibratoDepth = readU8();
          vibratoRate = readU8();
          vibratoType = readU8();

          int pan = 128;
          if ((dfp & 0x80) != 0) {
            pan = (((dfp & 0x7f) / 64) * 255).round();
          }

          if (samplePointer > 0 &&
              samplePointer < data.length &&
              smpLength > 0 &&
              (sFlags & 1) != 0) {
            setPos(samplePointer);
            final is16 = (sFlags & 0x02) != 0;
            final isCompressed = (sFlags & 0x08) != 0;
            // cvt bit 0: 0=unsigned, 1=signed (IT standard is signed)
            final isSigned = (cvt & 1) != 0;

            final preferIT215 = preferIT215ByCompat;

            if (isCompressed) {
              final decoded = _decodeCompressedItSample(
                data,
                pos,
                smpLength,
                is16,
                preferIT215,
                isSigned,
              );

              sampleData = Float32List(smpLength);
              sampleData.setAll(0, decoded);
            } else {
              sampleData = Float32List(smpLength);
              for (int j = 0; j < smpLength; j++) {
                if (is16) {
                  int v = readU16LE();
                  if (isSigned) {
                    if (v >= 32768) v -= 65536;
                  } else {
                    v -= 32768;
                  }
                  sampleData[j] = v / 32768;
                } else {
                  int v = readU8();
                  if (isSigned) {
                    if (v >= 128) v -= 256;
                  } else {
                    v -= 128;
                  }
                  sampleData[j] = v / 128;
                }
              }
            }

            // Unroll pingpong loops
            if (hasLoop && isPingPong && loopLength > 0) {
              int lend = loopStart + loopLength;
              if (lend > smpLength) lend = smpLength;
              loopLength = lend - loopStart;
              final newData = Float32List(lend + loopLength);
              for (int j = 0; j < lend; j++) {
                newData[j] = sampleData[j];
              }
              for (int j = 0; j < loopLength; j++) {
                newData[lend + j] = sampleData[lend - 1 - j];
              }
              sampleData = newData;
              loopLength *= 2;
              smpLength = sampleData.length;
            }
          }

          rawSamples.add(
            Sample(
              name: name,
              length: smpLength,
              finetune: 0,
              volume: math.min(
                64,
                ((math.min(sVol, 64) * math.min(sampleGlobalVolume, 64)) / 64)
                    .round(),
              ),
              loopStart: loopStart,
              loopLength: hasLoop ? loopLength : 0,
              panning: pan,
              baseNote: 0,
              data: sampleData,
              c5speed: c5speed,
              vibratoType: vibratoType,
              vibratoSweep: vibratoSweep,
              vibratoDepth: vibratoDepth,
              vibratoRate: vibratoRate,
            ),
          );
          continue;
        }
      }

      rawSamples.add(
        Sample(
          name: name,
          length: smpLength,
          finetune: 0,
          volume: math.min(
            64,
            ((math.min(sVol, 64) * math.min(sampleGlobalVolume, 64)) / 64)
                .round(),
          ),
          loopStart: loopStart,
          loopLength: 0,
          panning: 128,
          baseNote: 0,
          data: sampleData,
          c5speed: c5speed,
          vibratoType: vibratoType,
          vibratoSweep: vibratoSweep,
          vibratoDepth: vibratoDepth,
          vibratoRate: vibratoRate,
        ),
      );
    }

    final instruments = <Instrument>[];
    if ((flags & 4) != 0 && insNum > 0) {
      // Use true IT Instruments
      for (int i = 0; i < insNum; i++) {
        String name = 'Instrument ${i + 1}';
        int volFadeout = 0;
        int nna = 0; // New Note Action: 0=cut, 1=continue, 2=noteOff, 3=fade
        int dct = 0;
        int dca = 0;
        final sampleMap = List<int>.filled(120, -1);
        final noteMap = List<int>.filled(
          120,
          0,
        ); // translated note for each slot
        Envelope? volumeEnv;
        Envelope? panningEnv;

        if (insOffsets[i] > 0) {
          setPos(insOffsets[i]);
          if (readStr(4) == 'IMPI') {
            readStr(12); // dos filename
            readU8(); // zero
            nna = math.min(
              3,
              readU8(),
            ); // nna (0=cut,1=continue,2=noteOff,3=fade)
            dct = math.min(3, readU8()); // dct
            dca = math.min(2, readU8()); // dca
            volFadeout = readU16LE(); // fadeout
            readU8(); // pps
            readU8(); // ppc
            setPos(insOffsets[i] + 32);
            name = readStr(26).trim();
            readU8(); // ifc
            readU8(); // ifr
            readU8(); // mch
            readU8(); // mpr
            readU16LE(); // midibnk

            // Note-sample table at offset 64: 120 pairs of (note, sample)
            setPos(insOffsets[i] + 64);
            for (int n = 0; n < 120; n++) {
              noteMap[n] = readU8(); // translated note (0-119)
              final smp = readU8(); // 1-based sample index, 0 = no sample
              sampleMap[n] = smp == 0 ? -1 : smp - 1;
            }

            // Volume envelope at offset 304
            setPos(insOffsets[i] + 304);
            volumeEnv = parseItEnvelope();

            // Panning envelope at offset 304 + 82 = 386
            setPos(insOffsets[i] + 386);
            panningEnv = parseItEnvelope();
          }
        }
        instruments.add(
          Instrument(
            name: name,
            volumeFadeout: volFadeout,
            sampleMap: sampleMap,
            noteMap: noteMap,
            samples: rawSamples,
            volumeEnv: volumeEnv,
            panningEnv: panningEnv,
            nna: nna,
            dct: dct,
            dca: dca,
          ),
        );
      }
    } else {
      // Sample Mode: one instrument per sample.
      for (int i = 0; i < rawSamples.length; i++) {
        final smaps = List<int>.filled(120, i);
        instruments.add(
          Instrument(
            name: rawSamples[i].name,
            volumeFadeout: 0,
            sampleMap: smaps,
            samples: rawSamples,
          ),
        );
      }
    }

    final patterns = <Pattern>[];
    for (int i = 0; i < patNum; i++) {
      if (patOffsets[i] == 0) {
        patterns.add(
          Pattern(
            rows: List.generate(
              64,
              (_) => List.generate(
                channels,
                (_) => Note(
                  note: null,
                  period: null,
                  instrument: 0,
                  volume: null,
                  volumeColumn: null,
                  effect: 0,
                  effectParam: 0,
                ),
              ),
            ),
          ),
        );
        continue;
      }
      setPos(patOffsets[i]);
      final packedLen = readU16LE(); // packed pattern data length
      final pRows = readU16LE();
      readU32LE(); // reserved
      final patDataStart = pos;
      final patDataEnd = patDataStart + packedLen;

      final rows = <List<Note>>[];
      // Per-channel running state for the packed row decoder.
      final chMask = List<int>.filled(64, 0);
      final chNote = List<int>.filled(64, 0);
      final chInst = List<int>.filled(64, 0);
      final chVol = List<int>.filled(64, 255); // 255 = no volume column
      final chCmd = List<int>.filled(64, 0);
      final chParam = List<int>.filled(64, 0);

      for (int r = 0; r < pRows; r++) {
        // Safety: don't read past the packed data boundary
        if (pos >= patDataEnd) {
          // Fill remaining rows with empty data
          for (int remaining = r; remaining < pRows; remaining++) {
            rows.add(
              List.generate(
                channels,
                (_) => Note(
                  note: null,
                  period: null,
                  instrument: 0,
                  volume: null,
                  volumeColumn: null,
                  effect: 0,
                  effectParam: 0,
                ),
              ),
            );
          }
          break;
        }

        final row = List.generate(
          channels,
          (_) => Note(
            note: null,
            period: null,
            instrument: 0,
            volume: null,
            volumeColumn: null,
            effect: 0,
            effectParam: 0,
          ),
        );

        // Read packed row data until end-of-row marker (byte 0) or end of packed data
        while (pos < patDataEnd) {
          final b = readU8();
          if (b == 0) break;
          final ch = (b - 1) & 63;
          int mask;
          if ((b & 128) != 0) {
            mask = readU8();
            chMask[ch] = mask;
          } else {
            mask = chMask[ch];
          }

          // Read new values from stream (bits 0-3)
          if ((mask & 1) != 0) chNote[ch] = readU8();
          if ((mask & 2) != 0) chInst[ch] = readU8();
          if ((mask & 4) != 0) chVol[ch] = readU8();
          if ((mask & 8) != 0) {
            chCmd[ch] = readU8();
            chParam[ch] = readU8();
          }

          // Bits 4-7 mean "use last value" (already stored in state)
          final hasNote = (mask & (1 | 16)) != 0;
          final hasInst = (mask & (2 | 32)) != 0;
          final hasVol = (mask & (4 | 64)) != 0;
          final hasCmd = (mask & (8 | 128)) != 0;

          if (ch < channels) {
            // Convert IT note to our internal format
            // IT: 0=empty, 1-120=notes (1=C-0), 253=notecut, 254=noteoff, 255=notefade
            int? logicalNote;
            if (hasNote) {
              final rawNote = chNote[ch];
              if (rawNote >= 1 && rawNote <= 120) {
                // IT note 1=C-0, 61=C-5. Our internal: just store as-is (1-120)
                logicalNote = rawNote;
              } else if (rawNote == 253) {
                logicalNote = 98; // Note Cut
              } else if (rawNote == 254) {
                logicalNote = 97; // Note Off
              } else if (rawNote == 255) {
                logicalNote = 99; // Note Fade
              }
            }

            // Translate IT effects to MOD-compatible effect numbers
            int effect = 0;
            int effectParam = 0;
            if (hasCmd && chCmd[ch] > 0) {
              final translated = _translateItEffect(chCmd[ch], chParam[ch]);
              effect = translated[0];
              effectParam = translated[1];
            }

            // Handle IT volume column
            int? volume;
            int itVolumeEffect = 0;
            int itVolumeEffectParam = 0;
            if (hasVol && chVol[ch] != 255) {
              final parsed = _parseItVolumeColumn(chVol[ch]);
              volume = parsed.volume;
              if (parsed.effect != 0) {
                itVolumeEffect = parsed.effect;
                itVolumeEffectParam = parsed.effectParam;
              }
            }

            row[ch] = Note(
              note: logicalNote,
              period: null,
              instrument: hasInst ? chInst[ch] : 0,
              volume: volume,
              volumeColumn: null,
              effect: effect,
              effectParam: effectParam,
              itVolumeEffect: itVolumeEffect,
              itVolumeEffectParam: itVolumeEffectParam,
            );
          }
        }
        rows.add(row);
      }
      patterns.add(Pattern(rows: rows));
    }

    final rowsPerPattern = patterns
        .map((p) => p.rows.length)
        .fold<int>(64, (a, b) => math.max(a, b));

    return ModuleFile(
      type: 'IT',
      title: title,
      instruments: instruments,
      patterns: patterns,
      sequence: sequence.where((o) => o < 254).toList(),
      channels: channels,
      defaultBpm: initTempo,
      defaultSpeed: initSpeed,
      rowsPerPattern: rowsPerPattern,
      linearFrequencies: (flags & 8) != 0,
      // IT stores global volume in 0-128; normalize to engine range 0-64.
      globalVolume: math.min(64, (math.min(globalVol, 128) / 2).round()),
      mixingVolume: math.max(0, math.min(mixVol, 128)),
      channelVolumes: channelVolumes,
      channelPanning: channelPanning,
    );
  }

  /// Parse an IT envelope structure (volume or panning)
  Envelope? parseItEnvelope() {
    final flg = readU8(); // flags: bit 0=on, bit 1=loop, bit 2=sustain loop
    final num = readU8(); // number of node points
    final lpb = readU8(); // loop begin
    final lpe = readU8(); // loop end
    final slb = readU8(); // sustain loop begin
    final sle = readU8(); // sustain loop end

    if ((flg & 1) == 0 || num == 0) {
      // Envelope not enabled, skip the node data (25 pairs x 3 bytes each)
      pos += 75;
      return null;
    }

    final points = <EnvelopePoint>[];
    for (int j = 0; j < 25; j++) {
      final value = readU8(); // y-value (0-64)
      final tickLo = readU8();
      final tickHi = readU8();
      final tick = tickLo | (tickHi << 8);
      if (j < num) {
        points.add(EnvelopePoint(tick, value));
      }
    }

    int type = 1; // enabled
    if ((flg & 2) != 0) type |= 4; // loop
    if ((flg & 4) != 0) type |= 2; // sustain

    return Envelope(
      points: points,
      type: type,
      loopStart: lpb,
      loopEnd: lpe,
      sustainStart: slb,
      sustainEnd: sle,
    );
  }
}
