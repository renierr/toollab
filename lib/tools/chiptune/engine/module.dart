import 'dart:math' as math;
import 'dart:typed_data';

/// Chiptune module model. Parsers produce a [ModuleFile];
/// [serializeModuleForWorklet] flattens it into a [WorkletModule] that the
/// software mixer consumes.

class EnvelopePoint {
  final int tick;
  final int value;
  const EnvelopePoint(this.tick, this.value);
}

class Envelope {
  List<EnvelopePoint> points;
  int? loopStart;
  int? loopEnd;
  int? sustainStart;
  int? sustainEnd;

  /// bitmask: 1=enabled, 2=sustain, 4=loop
  int type;

  Envelope({
    List<EnvelopePoint>? points,
    this.loopStart,
    this.loopEnd,
    this.sustainStart,
    this.sustainEnd,
    this.type = 0,
  }) : points = points ?? [];
}

class Sample {
  String name;
  int length;

  /// in octaves for XM/IT or simple nibble for MOD
  double finetune;

  /// 0-64
  int volume;
  int loopStart;

  /// 0 means no loop
  int loopLength;

  /// 0-255, 128 is center
  int panning;
  Float32List data;

  /// Used for XM specific relative note mappings
  int? baseNote;

  /// Base frequency (IT)
  int? c5speed;
  int? vibratoType;
  int? vibratoSweep;
  int? vibratoDepth;
  int? vibratoRate;

  Sample({
    this.name = '',
    this.length = 0,
    this.finetune = 0,
    this.volume = 64,
    this.loopStart = 0,
    this.loopLength = 0,
    this.panning = 128,
    Float32List? data,
    this.baseNote,
    this.c5speed,
    this.vibratoType,
    this.vibratoSweep,
    this.vibratoDepth,
    this.vibratoRate,
  }) : data = data ?? Float32List(0);
}

class Instrument {
  String name;
  List<Sample> samples;

  /// 0-95 array mapping note index to sample index
  List<int> sampleMap;

  /// IT: note-to-note translation (maps input note -> output note)
  List<int>? noteMap;
  Envelope? volumeEnv;
  Envelope? panningEnv;

  /// 0-32768
  int volumeFadeout;

  /// IT: New Note Action (0=cut, 1=continue, 2=noteOff, 3=fade)
  int? nna;

  /// IT: Duplicate Check Type (0=off, 1=note, 2=sample, 3=instrument)
  int? dct;

  /// IT: Duplicate Check Action (0=cut, 1=off, 2=fade)
  int? dca;

  Instrument({
    this.name = '',
    List<Sample>? samples,
    List<int>? sampleMap,
    this.noteMap,
    this.volumeEnv,
    this.panningEnv,
    this.volumeFadeout = 0,
    this.nna,
    this.dct,
    this.dca,
  }) : samples = samples ?? [],
       sampleMap = sampleMap ?? List<int>.filled(96, 0);
}

class Note {
  /// 1-120 notes, 97=KeyOff, 98=NoteCut, 99=NoteFade, null=Empty
  int? note;

  /// Raw exact tracker period, if standard.
  int? period;

  /// 1-128, 0=Empty
  int instrument;

  /// 0-64
  int? volume;

  /// Raw volume column byte for XM
  int? volumeColumn;

  /// 0-255 (effect type)
  int effect;

  /// 0-255 (effect parameter)
  int effectParam;

  /// IT-only secondary effect from volume column
  int? itVolumeEffect;

  /// IT-only secondary effect parameter
  int? itVolumeEffectParam;

  Note({
    this.note,
    this.period,
    this.instrument = 0,
    this.volume,
    this.volumeColumn,
    this.effect = 0,
    this.effectParam = 0,
    this.itVolumeEffect,
    this.itVolumeEffectParam,
  });
}

class Pattern {
  /// rows[rowIndex][channelIndex]
  List<List<Note>> rows;
  Pattern({List<List<Note>>? rows}) : rows = rows ?? [];
}

class ModuleFile {
  String type; // 'MOD' | 'XM' | 'IT'
  String title;
  List<Instrument> instruments;
  List<Pattern> patterns;
  List<int> sequence;
  int channels;
  int defaultBpm;
  int defaultSpeed;
  int rowsPerPattern;
  bool linearFrequencies;
  double? clock;
  int? restartPosition;

  /// IT: initial global volume (0-128)
  int? globalVolume;

  /// IT: mix volume (0-128)
  int? mixingVolume;

  /// Optional per-channel defaults (0-64)
  List<int>? channelVolumes;

  /// Optional per-channel defaults (0-255)
  List<int>? channelPanning;

  ModuleFile({
    this.type = 'MOD',
    this.title = '',
    List<Instrument>? instruments,
    List<Pattern>? patterns,
    List<int>? sequence,
    this.channels = 4,
    this.defaultBpm = 125,
    this.defaultSpeed = 6,
    this.rowsPerPattern = 64,
    this.linearFrequencies = false,
    this.clock,
    this.restartPosition,
    this.globalVolume,
    this.mixingVolume,
    this.channelVolumes,
    this.channelPanning,
  }) : instruments = instruments ?? [],
       patterns = patterns ?? [],
       sequence = sequence ?? [];
}

/// Reads a null-terminated ASCII string from [data] at [offset].
String readString(Uint8List data, int offset, int length) {
  final buf = StringBuffer();
  for (int i = 0; i < length; i++) {
    final charCode = data[offset + i];
    if (charCode == 0) break;
    if (charCode >= 32 && charCode <= 126) {
      buf.writeCharCode(charCode);
    }
  }
  return buf.toString();
}

// MOD Amiga periods table
const List<int> amigaPeriodTable = [
  1712,
  1616,
  1525,
  1440,
  1357,
  1281,
  1209,
  1141,
  1077,
  1017,
  961,
  907,
  856,
  808,
  762,
  720,
  678,
  640,
  604,
  570,
  538,
  508,
  480,
  453,
  428,
  404,
  381,
  360,
  339,
  320,
  302,
  285,
  269,
  254,
  240,
  226,
  214,
  202,
  190,
  180,
  170,
  160,
  151,
  143,
  135,
  127,
  120,
  113,
  107,
  101,
  95,
  90,
  85,
  80,
  76,
  71,
  67,
  64,
  60,
  57,
];

const double palClock = 7093789.2;

double periodToFrequencyAmiga(
  num period, [
  double finetune = 0,
  double clock = palClock,
]) {
  if (period <= 0) return 0;
  double adjustedPeriod = period.toDouble();
  if (finetune != 0) {
    adjustedPeriod = (period * math.pow(2, -finetune / (12 * 8))).toDouble();
  }
  return clock / (adjustedPeriod * 2);
}

double periodToFrequencyLinear(num period) {
  return 8363 * math.pow(2, (4608 - period) / 768).toDouble();
}

// ---------------------------------------------------------------------------
// Worklet (flattened) representation consumed by the mixer.
// ---------------------------------------------------------------------------

class WorkletInstrumentSample {
  int length;
  double finetune;
  int volume;
  int loopStart;
  int loopLength;
  int panning;
  Float32List data;
  int? baseNote;
  int? c5speed;
  int? vibratoType;
  int? vibratoSweep;
  int? vibratoDepth;
  int? vibratoRate;

  WorkletInstrumentSample({
    required this.length,
    required this.finetune,
    required this.volume,
    required this.loopStart,
    required this.loopLength,
    required this.panning,
    required this.data,
    this.baseNote,
    this.c5speed,
    this.vibratoType,
    this.vibratoSweep,
    this.vibratoDepth,
    this.vibratoRate,
  });
}

class WorkletInstrument {
  int index;
  String name;
  List<WorkletInstrumentSample> samples;
  List<int>? sampleMap;
  List<int>? noteMap;
  Envelope? volumeEnv;
  Envelope? panningEnv;
  int? volumeFadeout;
  int? nna;
  int? dct;
  int? dca;

  WorkletInstrument({
    required this.index,
    required this.name,
    required this.samples,
    this.sampleMap,
    this.noteMap,
    this.volumeEnv,
    this.panningEnv,
    this.volumeFadeout,
    this.nna,
    this.dct,
    this.dca,
  });
}

class WorkletNote {
  int instrument;
  int period;
  int effect;
  int effectParam;
  int? itVolumeEffect;
  int? itVolumeEffectParam;
  int? volume;
  int? volumeColumn;
  int? note;

  WorkletNote({
    required this.instrument,
    required this.period,
    required this.effect,
    required this.effectParam,
    this.itVolumeEffect,
    this.itVolumeEffectParam,
    this.volume,
    this.volumeColumn,
    this.note,
  });
}

class WorkletRow {
  List<WorkletNote> notes;
  WorkletRow(this.notes);
}

class WorkletPattern {
  List<WorkletRow> rows;
  WorkletPattern(this.rows);
}

class WorkletModule {
  String type;
  String name;
  int length;
  List<int> sequence;
  List<int> patternTable;
  List<WorkletInstrument> instruments;
  List<WorkletPattern> patterns;
  int channels;
  int defaultBpm;
  int defaultSpeed;
  int rowsPerPattern;
  bool linearFrequencies;
  int restartPosition;
  double clock;
  int globalVolume;
  int mixingVolume;
  List<int>? channelVolumes;
  List<int>? channelPanning;

  WorkletModule({
    required this.type,
    required this.name,
    required this.length,
    required this.sequence,
    required this.patternTable,
    required this.instruments,
    required this.patterns,
    required this.channels,
    required this.defaultBpm,
    required this.defaultSpeed,
    required this.rowsPerPattern,
    required this.linearFrequencies,
    required this.restartPosition,
    required this.clock,
    required this.globalVolume,
    required this.mixingVolume,
    this.channelVolumes,
    this.channelPanning,
  });
}

WorkletModule serializeModuleForWorklet(ModuleFile mod) {
  final instruments = <WorkletInstrument>[];

  // Cache converted samples to avoid re-converting shared sample pools
  // (critical for IT where all instruments reference the same sample array).
  final sampleCache = <Sample, WorkletInstrumentSample>{};

  WorkletInstrumentSample convertSample(Sample sample) {
    final cached = sampleCache[sample];
    if (cached != null) return cached;

    final floatData = Float32List(sample.data.length);
    floatData.setAll(0, sample.data);

    final converted = WorkletInstrumentSample(
      length: sample.length,
      finetune: sample.finetune,
      volume: sample.volume,
      loopStart: sample.loopStart,
      loopLength: sample.loopLength,
      panning: sample.panning,
      data: floatData,
      baseNote: sample.baseNote,
      c5speed: sample.c5speed,
      vibratoType: sample.vibratoType,
      vibratoSweep: sample.vibratoSweep,
      vibratoDepth: sample.vibratoDepth,
      vibratoRate: sample.vibratoRate,
    );
    sampleCache[sample] = converted;
    return converted;
  }

  for (int i = 0; i < mod.instruments.length; i++) {
    final inst = mod.instruments[i];
    final samples = <WorkletInstrumentSample>[];
    for (int s = 0; s < inst.samples.length; s++) {
      samples.add(convertSample(inst.samples[s]));
    }
    instruments.add(
      WorkletInstrument(
        index: i + 1,
        name: inst.name,
        samples: samples,
        sampleMap: inst.sampleMap,
        noteMap: inst.noteMap,
        volumeEnv: inst.volumeEnv,
        panningEnv: inst.panningEnv,
        volumeFadeout: inst.volumeFadeout,
        nna: inst.nna,
        dct: inst.dct,
        dca: inst.dca,
      ),
    );
  }

  final patterns = <WorkletPattern>[];
  for (int p = 0; p < mod.patterns.length; p++) {
    final pattern = mod.patterns[p];
    final rows = <WorkletRow>[];
    for (int r = 0; r < pattern.rows.length; r++) {
      final row = pattern.rows[r];
      final notes = <WorkletNote>[];
      for (int c = 0; c < row.length; c++) {
        final note = row[c];
        notes.add(
          WorkletNote(
            instrument: note.instrument,
            period: note.period ?? 0,
            effect: note.effect,
            effectParam: note.effectParam,
            itVolumeEffect: note.itVolumeEffect,
            itVolumeEffectParam: note.itVolumeEffectParam,
            volume: note.volume,
            volumeColumn: note.volumeColumn,
            note: note.note,
          ),
        );
      }
      rows.add(WorkletRow(notes));
    }
    patterns.add(WorkletPattern(rows));
  }

  return WorkletModule(
    type: mod.type,
    name: mod.title,
    length: mod.sequence.length,
    sequence: mod.sequence,
    patternTable: mod.sequence,
    instruments: instruments,
    patterns: patterns,
    channels: mod.channels,
    defaultBpm: mod.defaultBpm,
    defaultSpeed: mod.defaultSpeed,
    rowsPerPattern: mod.rowsPerPattern,
    linearFrequencies: mod.linearFrequencies,
    restartPosition: mod.restartPosition ?? 0,
    clock: mod.clock ?? 7093789.2,
    globalVolume: mod.globalVolume ?? 64,
    mixingVolume: mod.mixingVolume ?? 128,
    channelVolumes: mod.channelVolumes,
    channelPanning: mod.channelPanning,
  );
}
