import 'dart:typed_data';

import '../module.dart';

/// Parses a FastTracker II Extended Module (XM) into a [ModuleFile].

class _Reader {
  final Uint8List data;
  int pos = 0;

  _Reader(this.data);

  int readU8() => pos < data.length ? data[pos++] : 0;

  int readS8() {
    final v = readU8();
    return v > 127 ? v - 256 : v;
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
}

class _SampleHeader {
  final int slen;
  final int loopStart;
  final int loopLength;
  final int sVol;
  final int sFine;
  final int type;
  final int sPan;
  final int relNote;

  _SampleHeader({
    required this.slen,
    required this.loopStart,
    required this.loopLength,
    required this.sVol,
    required this.sFine,
    required this.type,
    required this.sPan,
    required this.relNote,
  });
}

ModuleFile parseXm(Uint8List data) {
  if (data.length < 60) throw Exception('Invalid XM file size');
  final r = _Reader(data);
  r.setPos(0);
  final sig = r.readStr(17);
  if (!sig.startsWith('Extended Module:')) throw Exception('Not XM signature');
  final title = r.readStr(20).trim();
  r.readU8(); // 0x1A
  r.readStr(20); // tracker name
  r.readU16LE(); // version
  final headerSize = r.readU32LE();
  final songLength = r.readU16LE();
  final restartPosition = r.readU16LE();
  final channels = r.readU16LE();
  final numPatterns = r.readU16LE();
  final numInstruments = r.readU16LE();
  final flags = r.readU16LE();
  final linearFrequencies = (flags & 1) != 0;
  final defaultSpeed = r.readU16LE();
  final defaultBpm = r.readU16LE();

  final sequence = <int>[];
  for (int i = 0; i < 256; i++) {
    final order = r.readU8();
    if (i < songLength) sequence.add(order);
  }

  // Jump past header
  r.setPos(60 + headerSize);

  final patterns = <Pattern>[];
  for (int p = 0; p < numPatterns; p++) {
    r.readU32LE(); // _pHeaderSize
    r.readU8(); // _packingType
    final numRowsRaw = r.readU16LE();
    final numRows = numRowsRaw != 0 ? numRowsRaw : 64;
    final packedSize = r.readU16LE();

    final patDataOffset = r.pos;
    final rows = <List<Note>>[];
    int rr = 0;
    int c = 0;
    var rowData = <Note>[];

    while (rr < numRows) {
      int? note;
      int instrument = 0;
      int? volume;
      int effect = 0;
      int effectParam = 0;

      if (packedSize > 0 && r.pos < patDataOffset + packedSize) {
        int mask = r.readU8();
        if ((mask & 0x80) == 0) {
          // Uncompressed, the byte read was actually the note
          // XM note: 1-96, 97 is Key off
          note = mask;
          mask = 0x1e; // 2|4|8|16
        } else {
          if (mask & 1 != 0) note = r.readU8();
        }
        if (mask & 2 != 0) instrument = r.readU8();
        if (mask & 4 != 0) volume = r.readU8(); // 0x10-0x50 is volume 0-64
        if (mask & 8 != 0) effect = r.readU8();
        if (mask & 16 != 0) effectParam = r.readU8();
      }

      // Map volume column
      int? mappedVol;
      if (volume != null) {
        if (volume >= 0x10 && volume <= 0x50) mappedVol = volume - 0x10;
      }

      rowData.add(
        Note(
          note: note == 97
              ? 97
              : (note != null && note > 0 && note < 97 ? note : null),
          period: null,
          instrument: instrument,
          volume: mappedVol,
          volumeColumn: volume,
          effect: effect,
          effectParam: effectParam,
        ),
      );

      c++;
      if (c >= channels) {
        rows.add(rowData);
        rowData = <Note>[];
        c = 0;
        rr++;
      }
    }
    r.setPos(patDataOffset + packedSize);
    patterns.add(Pattern(rows: rows));
  }

  final instruments = <Instrument>[];
  for (int i = 0; i < numInstruments; i++) {
    final insStart = r.pos;
    final iSize = r.readU32LE();
    final name = r.readStr(22).trim();
    r.readU8(); // type
    final numSamples = r.readU16LE();

    final sampleMap = List<int>.filled(96, 0);
    int volFadeout = 0;
    Envelope? volumeEnv;
    Envelope? panningEnv;
    int vibratoType = 0;
    int vibratoSweep = 0;
    int vibratoDepth = 0;
    int vibratoRate = 0;

    if (numSamples > 0) {
      r.readU32LE(); // sh size (should be 40)
      for (int z = 0; z < 96; z++) {
        sampleMap[z] = r.readU8(); // sample map
      }

      // Volume envelope (12 points, 2 bytes each: tick + value)
      final volEnvPoints = <EnvelopePoint>[];
      for (int z = 0; z < 12; z++) {
        final tick = r.readU16LE();
        final value = r.readU16LE();
        if (tick != 0 || value != 0) {
          volEnvPoints.add(EnvelopePoint(tick, value));
        }
      }
      // Panning envelope
      final panEnvPoints = <EnvelopePoint>[];
      for (int z = 0; z < 12; z++) {
        final tick = r.readU16LE();
        final value = r.readU16LE();
        if (tick != 0 || value != 0) {
          panEnvPoints.add(EnvelopePoint(tick, value));
        }
      }

      final volEnvNum = r.readU8();
      final panEnvNum = r.readU8();
      final volEnvSus = r.readU8();
      final volEnvLoopStart = r.readU8();
      final volEnvLoopEnd = r.readU8();
      final panEnvSus = r.readU8();
      final panEnvLoopStart = r.readU8();
      final panEnvLoopEnd = r.readU8();
      final volEnvType = r.readU8();
      final panEnvType = r.readU8();
      vibratoType = r.readU8();
      vibratoSweep = r.readU8();
      vibratoDepth = r.readU8();
      vibratoRate = r.readU8();
      volFadeout = r.readU16LE();
      r.readU16LE(); // reserved

      if (volEnvPoints.isNotEmpty && (volEnvType & 1) != 0) {
        final count = volEnvNum != 0 ? volEnvNum : volEnvPoints.length;
        volumeEnv = Envelope(
          points: volEnvPoints.sublist(0, count.clamp(0, volEnvPoints.length)),
          sustainStart: volEnvSus,
          sustainEnd: volEnvSus,
          loopStart: volEnvLoopStart,
          loopEnd: volEnvLoopEnd,
          type: volEnvType,
        );
      }
      if (panEnvPoints.isNotEmpty && (panEnvType & 1) != 0) {
        final count = panEnvNum != 0 ? panEnvNum : panEnvPoints.length;
        panningEnv = Envelope(
          points: panEnvPoints.sublist(0, count.clamp(0, panEnvPoints.length)),
          sustainStart: panEnvSus,
          sustainEnd: panEnvSus,
          loopStart: panEnvLoopStart,
          loopEnd: panEnvLoopEnd,
          type: panEnvType,
        );
      }
    }
    // Accurately jump to the end of the Instrument Header using absolute starting position
    r.setPos(insStart + iSize);

    final samples = <Sample>[];
    final sampleHeaders = <_SampleHeader>[];
    // Read sample headers
    for (int s = 0; s < numSamples; s++) {
      final slen = r.readU32LE();
      final loopStart = r.readU32LE();
      final loopLength = r.readU32LE();
      final sVol = r.readU8();
      final sFine = r.readS8();
      final type = r.readU8();
      final sPan = r.readU8();
      final relNote = r.readS8();
      r.readU8(); // res
      r.readStr(22).trim(); // name
      sampleHeaders.add(
        _SampleHeader(
          slen: slen,
          loopStart: loopStart,
          loopLength: loopLength,
          sVol: sVol,
          sFine: sFine,
          type: type,
          sPan: sPan,
          relNote: relNote,
        ),
      );
    }

    // Read sample data
    for (int s = 0; s < numSamples; s++) {
      final sh = sampleHeaders[s];
      final is16 = (sh.type & 16) != 0;
      int lengthFrames = is16 ? sh.slen ~/ 2 : sh.slen;

      // Safety check to prevent memory freeze from corrupted slen
      if (lengthFrames > data.length * 2) lengthFrames = 0;

      var floatData = Float32List(lengthFrames);
      int old = 0;
      for (int j = 0; j < lengthFrames; j++) {
        if (is16) {
          final low = r.readU8();
          final high = r.readU8();
          int d = low | (high << 8);
          if (d >= 32768) d -= 65536;
          old = (old + d) & 0xffff;
          final val = old >= 32768 ? old - 65536 : old;
          floatData[j] = val / 32768;
        } else {
          final d = r.readS8();
          old = (old + d) & 0xff;
          final val = old >= 128 ? old - 256 : old;
          floatData[j] = val / 128;
        }
      }

      // Unroll ping-pong loops
      final ltype = sh.type & 3;
      final lstart = is16 ? sh.loopStart ~/ 2 : sh.loopStart;
      int llen = is16 ? sh.loopLength ~/ 2 : sh.loopLength;
      if (ltype == 0) llen = 0;

      if (ltype == 2 && llen > 0) {
        int lend = lstart + llen;
        if (lend > lengthFrames) lend = lengthFrames;
        llen = lend - lstart;
        final newData = Float32List(lend + llen);
        for (int k = 0; k < lend; k++) {
          newData[k] = floatData[k];
        }
        for (int k = 0; k < llen; k++) {
          newData[lend + k] = floatData[lend - 1 - k];
        }
        floatData = newData;
        llen *= 2;
        lengthFrames = floatData.length;
      }

      samples.add(
        Sample(
          name: name,
          length: lengthFrames,
          finetune: sh.sFine.toDouble(),
          volume: sh.sVol < 64 ? sh.sVol : 64,
          loopStart: lstart,
          loopLength: ltype != 0 ? llen : 0,
          panning: sh.sPan,
          baseNote: sh.relNote,
          data: floatData,
        ),
      );
    }

    instruments.add(
      Instrument(
        name: name.isNotEmpty ? name : 'Instrument ${i + 1}',
        samples: samples,
        sampleMap: sampleMap,
        volumeFadeout: volFadeout,
        volumeEnv: volumeEnv,
        panningEnv: panningEnv,
      ),
    );

    // Store vibrato params on first sample for convenience
    if (samples.isNotEmpty) {
      samples[0].vibratoType = vibratoType;
      samples[0].vibratoSweep = vibratoSweep;
      samples[0].vibratoDepth = vibratoDepth;
      samples[0].vibratoRate = vibratoRate;
    }
  }

  int maxRows = 64;
  for (final p in patterns) {
    if (p.rows.length > maxRows) maxRows = p.rows.length;
  }

  return ModuleFile(
    type: 'XM',
    title: title,
    instruments: instruments,
    patterns: patterns,
    sequence: sequence,
    channels: channels,
    defaultBpm: defaultBpm,
    defaultSpeed: defaultSpeed,
    rowsPerPattern: maxRows,
    linearFrequencies: linearFrequencies,
    restartPosition: restartPosition < songLength ? restartPosition : 0,
  );
}
