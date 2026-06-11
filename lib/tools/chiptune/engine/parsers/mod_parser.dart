import 'dart:typed_data';

import '../module.dart';

/// Finds the closest note index (1-based) in the Amiga period table for a raw
/// MOD period. Returns null for an empty period (0).
int? getModNoteFromPeriod(int period) {
  if (period == 0) return null;
  double closestDist = double.infinity;
  int closestIdx = -1;
  for (int i = 0; i < amigaPeriodTable.length; i++) {
    final dist = (amigaPeriodTable[i] - period).abs().toDouble();
    if (dist < closestDist) {
      closestDist = dist;
      closestIdx = i;
    }
  }
  return closestIdx >= 0 ? closestIdx + 1 : null;
}

/// Parses an Amiga ProTracker / SoundTracker MOD file into a [ModuleFile].
/// Handles both standard 31-sample MODs (4-byte marker at offset 1080) and
/// legacy 15-sample SoundTracker MODs (no marker).
ModuleFile parseMod(Uint8List data) {
  int pos = 0;

  // --- Inlined BaseParser byte readers --------------------------------------
  int readU8() => data[pos++];

  int readU16BE() {
    final value = (data[pos] << 8) | data[pos + 1];
    pos += 2;
    return value;
  }

  String readStr(int length) {
    final str = readString(data, pos, length);
    pos += length;
    return str;
  }
  // --------------------------------------------------------------------------

  pos = 1080;
  final marker = readStr(4);
  int channels = 4;
  bool is15Sample = false;

  final markerUpper = marker.toUpperCase();
  // Standard 31-sample markers: M.K., M!K!, FLT4, FLT8, 4CHN, 6CHN, 8CHN, XXCH, XXCN, etc.
  if (markerUpper == 'M.K.' || markerUpper == 'M!K!' || markerUpper == 'FLT4') {
    channels = 4;
  } else if (markerUpper == 'FLT8') {
    channels = 8;
  } else if (markerUpper.endsWith('CHN') || markerUpper.endsWith('CH')) {
    final numStr = markerUpper.replaceAll(RegExp(r'[^0-9]'), '');
    channels = int.tryParse(numStr) ?? 4;
    if (channels == 0) channels = 4;
  } else if (markerUpper.endsWith('CN')) {
    // StarTrekker 4CN, 8CN
    final numStr = markerUpper.replaceAll(RegExp(r'[^0-9]'), '');
    channels = int.tryParse(numStr) ?? 4;
    if (channels == 0) channels = 4;
  } else if (markerUpper == 'OKTA' ||
      markerUpper == 'OCTA' ||
      markerUpper == 'CD81') {
    channels = 8;
  } else {
    // No standard 31-sample marker found at 1080, assume 15-sample legacy MOD
    is15Sample = true;
    channels = 4;
  }

  pos = 0;
  final title = readStr(20).trim();
  final instruments = <Instrument>[];

  // Reading samples (15 or 31)
  final numSamples = is15Sample ? 15 : 31;
  for (int i = 0; i < numSamples; i++) {
    pos = 20 + i * 30;
    final name = readStr(22).trim();
    final lenWords = readU16BE();
    final length = lenWords * 2;
    final fineNibble = readU8() & 0x0f;
    final finetune = fineNibble > 7
        ? fineNibble - 16
        : fineNibble; // 4-bit signed
    int volume = readU8();
    volume = volume < 64 ? volume : 64;
    final loopStartWords = readU16BE();
    final loopStart = loopStartWords * 2;
    final loopLenWords = readU16BE();
    final loopLength = loopLenWords > 1 ? loopLenWords * 2 : 0;

    instruments.add(
      Instrument(
        name: name.isNotEmpty ? name : 'Instrument ${i + 1}',
        samples: [
          Sample(
            name: name,
            length: length,
            finetune: finetune.toDouble(),
            volume: volume,
            loopStart: loopStart,
            loopLength: loopLength,
            panning: 128,
            data: Float32List(length),
          ),
        ],
        sampleMap: List<int>.filled(120, 0),
        volumeFadeout: 0,
      ),
    );
  }

  // Positions differ between 15 and 31 sample MODs
  final infoPos = is15Sample ? 470 : 950;
  pos = infoPos;
  final songLength = readU8();
  final restartPosition = readU8();
  final sequence = <int>[];
  for (int i = 0; i < 128; i++) {
    sequence.add(readU8());
  }

  int maxSeq = 0;
  for (int i = 0; i < songLength; i++) {
    if (sequence[i] > maxSeq) maxSeq = sequence[i];
  }
  final numPatterns = maxSeq + 1;
  final patterns = <Pattern>[];
  final patternStart = is15Sample ? 600 : 1084;
  pos = patternStart;

  for (int pat = 0; pat < numPatterns; pat++) {
    final rows = <List<Note>>[];
    for (int r = 0; r < 64; r++) {
      final row = <Note>[];
      for (int c = 0; c < channels; c++) {
        final b0 = readU8();
        final b1 = readU8();
        final b2 = readU8();
        final b3 = readU8();

        final instrument = (b0 & 0xf0) | ((b2 & 0xf0) >> 4);
        final period = ((b0 & 0x0f) << 8) | b1;
        final effect = b2 & 0x0f;
        final effectParam = b3;
        int? volume;
        if (effect == 0x0c) volume = effectParam < 64 ? effectParam : 64;

        row.add(
          Note(
            note: getModNoteFromPeriod(period),
            period: period == 0 ? null : period,
            instrument: instrument,
            volume: volume,
            volumeColumn: null,
            effect: effect,
            effectParam: effectParam,
          ),
        );
      }
      rows.add(row);
    }
    patterns.add(Pattern(rows: rows));
  }

  // Load samples (signed 8-bit PCM)
  for (int i = 0; i < instruments.length; i++) {
    final smp = instruments[i].samples[0];
    if (smp.length > 0 && pos + smp.length <= data.length) {
      for (int j = 0; j < smp.length; j++) {
        final b = data[pos++];
        final signed = b > 127 ? b - 256 : b;
        smp.data[j] = signed / 128;
      }
    }
  }

  const clock = palClock;

  return ModuleFile(
    type: 'MOD',
    title: title,
    instruments: instruments,
    patterns: patterns,
    sequence: sequence.sublist(0, songLength),
    channels: channels,
    defaultBpm: 125,
    defaultSpeed: 6,
    rowsPerPattern: 64,
    linearFrequencies: false,
    clock: clock,
    restartPosition: restartPosition < songLength ? restartPosition : 0,
  );
}
