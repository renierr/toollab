import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/wav_utils.dart';
import 'memo_clip.dart';
import 'memo_settings.dart';

/// Files of the memo recorder. Every write bumps [revision] so open lists
/// reload, including saves made while the recordings page was closed.
class MemoStore {
  MemoStore._();

  static const Set<String> _playable = {'wav', 'flac', 'mp3', 'ogg', 'opus'};
  static const int peakCount = 160;

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static String? _dirPath;

  static Future<String> dir() async {
    if (_dirPath != null) return _dirPath!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dirPath = dir.path;
  }

  static Future<List<MemoClip>> list() async {
    final files = await Directory(await dir())
        .list()
        .where((e) => e is File && _playable.contains(_ext(e.path)))
        .cast<File>()
        .toList();
    final clips = await Future.wait(files.map(MemoClip.probe));
    // Drop empty files left by a recording that failed to start.
    clips.removeWhere((c) => c.sizeBytes <= 64 && c.duration == Duration.zero);
    clips.sort((a, b) => b.modified.compareTo(a.modified));
    return clips;
  }

  static Future<String> newRecordingPath(MemoFormat format) async {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stem =
        'Memo ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    return _uniquePath(await dir(), stem, format.extension);
  }

  static Future<String> _uniquePath(String dir, String stem, String ext) async {
    String candidate = '$dir/$stem.$ext';
    int n = 2;
    while (await File(candidate).exists()) {
      candidate = '$dir/$stem ($n).$ext';
      n++;
    }
    return candidate;
  }

  /// Characters Windows or Android refuse in a file name.
  static String sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();

  static Future<String?> rename(MemoClip clip, String newName) async {
    final stem = sanitize(newName);
    if (stem.isEmpty || stem == clip.name) return null;
    final target = await _uniquePath(await dir(), stem, clip.extension);
    final renamed = await File(clip.path).rename(target);
    _bump();
    return renamed.path;
  }

  static Future<void> delete(MemoClip clip) async {
    final f = File(clip.path);
    if (await f.exists()) await f.delete();
    _peakCache.remove(clip.path);
    _bump();
  }

  /// Cuts a WAV to [start]..[end]. [asCopy] keeps the original untouched.
  static Future<String?> trim(
    MemoClip clip,
    Duration start,
    Duration end, {
    required bool asCopy,
  }) async {
    final target = asCopy
        ? await _uniquePath(await dir(), '${clip.name} (cut)', clip.extension)
        : clip.path;
    final ok = await Isolate.run(
      () => _trimWav(
        clip.path,
        target,
        start.inMicroseconds / 1e6,
        end.inMicroseconds / 1e6,
      ),
    );
    if (!ok) return null;
    _peakCache.remove(target);
    _bump();
    return target;
  }

  /// Scales a 16-bit WAV so its loudest sample peaks just below full scale.
  static Future<bool> normalize(MemoClip clip) async {
    final path = clip.path;
    final ok = await Isolate.run(() => _normalizeWav(path));
    if (ok) {
      _peakCache.remove(path);
      _bump();
    }
    return ok;
  }

  static final Map<String, ({DateTime modified, Float32List peaks})>
  _peakCache = {};

  static Future<void> _peakQueue = Future.value();

  /// RMS envelope of the whole clip, decoded off the UI isolate. Decodes run
  /// one at a time so a long list does not spawn an isolate per row at once.
  static Future<Float32List?> peaks(MemoClip clip) {
    final cached = _peakCache[clip.path];
    if (cached != null && cached.modified == clip.modified) {
      return Future.value(cached.peaks);
    }
    final Future<Float32List?> run = _peakQueue.then((_) => _decodePeaks(clip));
    _peakQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<Float32List?> _decodePeaks(MemoClip clip) async {
    final cached = _peakCache[clip.path];
    if (cached != null && cached.modified == clip.modified) {
      return cached.peaks;
    }
    try {
      final raw = await SoLoud.instance.readSamplesFromFile(
        clip.path,
        peakCount,
        average: true,
      );
      double max = 0;
      for (final v in raw) {
        if (v.abs() > max) max = v.abs();
      }
      final peaks = Float32List(raw.length);
      if (max > 0) {
        for (int i = 0; i < raw.length; i++) {
          peaks[i] = (raw[i].abs() / max).clamp(0.0, 1.0);
        }
      }
      _peakCache[clip.path] = (modified: clip.modified, peaks: peaks);
      return peaks;
    } catch (_) {
      return null;
    }
  }

  static void notifyChanged() => _bump();

  static void _bump() => revision.value++;

  static String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }
}

bool _trimWav(String source, String target, double startSec, double endSec) {
  final bytes = File(source).readAsBytesSync();
  final info = readWavInfo(bytes);
  if (info == null || !info.isPcm) return false;
  final startFrame = (startSec * info.sampleRate).round().clamp(0, info.frames);
  final endFrame = (endSec * info.sampleRate).round().clamp(
    startFrame,
    info.frames,
  );
  if (endFrame <= startFrame) return false;
  final pcm = Uint8List.sublistView(
    bytes,
    info.dataOffset + startFrame * info.blockAlign,
    info.dataOffset + endFrame * info.blockAlign,
  );
  final out = buildPcmWav(
    pcm: pcm,
    sampleRate: info.sampleRate,
    channels: info.channels,
    bitsPerSample: info.bitsPerSample,
    format: info.format,
  );
  File(target).writeAsBytesSync(out, flush: true);
  return true;
}

bool _normalizeWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final info = readWavInfo(bytes);
  if (info == null || info.format != 1 || info.bitsPerSample != 16) {
    return false;
  }
  final data = ByteData.sublistView(
    bytes,
    info.dataOffset,
    info.dataOffset + info.dataLength - info.dataLength % 2,
  );
  final count = data.lengthInBytes ~/ 2;
  int peak = 0;
  for (int i = 0; i < count; i++) {
    final v = data.getInt16(i * 2, Endian.little).abs();
    if (v > peak) peak = v;
  }
  if (peak == 0) return false;
  // -0.5 dBFS headroom keeps lossy re-encodes of the file from clipping.
  final scale = 32767 * 0.944 / peak;
  for (int i = 0; i < count; i++) {
    final v = (data.getInt16(i * 2, Endian.little) * scale).round().clamp(
      -32768,
      32767,
    );
    data.setInt16(i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(bytes, flush: true);
  return true;
}
