import 'dart:convert';
import 'dart:typed_data';

/// A packed blob this build cannot read, because a later one wrote it.
///
/// Thrown rather than swallowed: skipping the rows would settle the chunk as
/// though it had been applied, and the readings would never arrive again. Failing
/// leaves the chunk unsettled, so updating the app is enough to pick it up. A
/// blob that is merely corrupt is dropped instead - nothing will ever fix it,
/// and retrying it forever is worse than losing it.
class HealthChunkVersionException implements Exception {
  final int version;

  const HealthChunkVersionException(this.version);

  @override
  String toString() =>
      'Health chunk blob is version $version; this build reads up to '
      '${HealthChunkCodec.version}. Update the app to sync this data.';
}

/// Packs a chunk's dense rows into a byte blob instead of JSON.
///
/// A reading as JSON is around 45 bytes - `["heart_rate",1778803200000,61,null]`
/// - and almost all of that is the repeated metric name and a 13-digit
/// timestamp. Grouped by metric, delta-encoded and varint-packed, the same
/// reading is about three. That ratio is what decides whether a decade of
/// history is a few megabytes or a few hundred.
///
/// **Values must round-trip exactly.** `health_point` is keyed on
/// `(metric, t, v)`, so a value that comes back as 10.554 instead of
/// 10.553866523510644 is not a rounding error - it is a different primary key,
/// and the receiver inserts a second row beside the first. Every metric
/// therefore picks the smallest decimal scale that reproduces all of its values
/// bit-for-bit, and falls back to a full float64 when none does.
class HealthChunkCodec {
  HealthChunkCodec._();

  /// First byte of every blob. Bump it only for a change that an older reader
  /// would misparse; anything a reader can skip past belongs behind a flag
  /// inside the format instead.
  static const version = 1;

  /// Scales tried before giving up and storing the double itself. A heart rate
  /// needs none, a weight needs two decimals; a speed carrying the full result
  /// of a division needs the fallback.
  static const _scales = [1, 10, 100, 1000, 10000, 100000, 1000000];

  static const _encodingFloat64 = 0;

  /// Points as `[metricKey, t, v]`, already free of the paired `v2` readings the
  /// caller keeps in plain JSON. Null when there is nothing to pack.
  static String? encodePoints(List<List<Object?>> points) {
    if (points.isEmpty) return null;
    final writer = _Writer()..byte(version);
    final grouped = _groupByMetric(points);
    writer.varint(grouped.length);
    for (final entry in grouped.entries) {
      final rows = entry.value..sort((a, b) => (a[1] as int) - (b[1] as int));
      writer.string(entry.key);
      writer.varint(rows.length);
      final scale = _scaleFor(rows.map((row) => row[2] as double));
      _writeValueHeader(writer, scale);
      var previousTime = 0;
      var previousValue = 0;
      for (final row in rows) {
        final time = row[1] as int;
        writer.zigzag(time - previousTime);
        previousTime = time;
        previousValue = _writeValue(
          writer,
          row[2] as double,
          scale,
          previousValue,
        );
      }
    }
    return base64Encode(writer.takeBytes());
  }

  /// Intervals as `[metricKey, t0, t1, v]`.
  static String? encodeIntervals(List<List<Object?>> intervals) {
    if (intervals.isEmpty) return null;
    final writer = _Writer()..byte(version);
    final grouped = _groupByMetric(intervals);
    writer.varint(grouped.length);
    for (final entry in grouped.entries) {
      final rows = entry.value..sort((a, b) => (a[1] as int) - (b[1] as int));
      writer.string(entry.key);
      writer.varint(rows.length);
      final scale = _scaleFor(rows.map((row) => row[3] as double));
      _writeValueHeader(writer, scale);
      var previousTime = 0;
      var previousValue = 0;
      for (final row in rows) {
        final t0 = row[1] as int;
        writer.zigzag(t0 - previousTime);
        previousTime = t0;
        // Duration rather than an absolute end: it is small and never negative,
        // where the end repeats all thirteen digits of the start.
        writer.varint((row[2] as int) - t0);
        previousValue = _writeValue(
          writer,
          row[3] as double,
          scale,
          previousValue,
        );
      }
    }
    return base64Encode(writer.takeBytes());
  }

  /// Returns rows shaped exactly like the plain JSON lists, so the receiver has
  /// one code path whichever form the sender used. An unreadable or
  /// newer-version blob yields an empty list rather than throwing: losing a
  /// chunk's dense rows is recoverable, a failed sync run is noisier.
  static List<List<Object?>> decodePoints(String encoded) =>
      _decode(encoded, interval: false);

  static List<List<Object?>> decodeIntervals(String encoded) =>
      _decode(encoded, interval: true);

  static List<List<Object?>> _decode(String encoded, {required bool interval}) {
    final Uint8List bytes;
    final int blobVersion;
    try {
      bytes = base64Decode(encoded);
      blobVersion = bytes.isEmpty ? -1 : bytes.first;
    } catch (_) {
      return const [];
    }
    if (blobVersion > version) throw HealthChunkVersionException(blobVersion);
    try {
      final reader = _Reader(bytes);
      if (reader.byte() != version) return const [];
      final rows = <List<Object?>>[];
      final metrics = reader.varint();
      for (var m = 0; m < metrics; m++) {
        final metric = reader.string();
        final count = reader.varint();
        final scale = reader.varint();
        var time = 0;
        var value = 0;
        for (var i = 0; i < count; i++) {
          time += reader.zigzag();
          final duration = interval ? reader.varint() : 0;
          final double decoded;
          if (scale == _encodingFloat64) {
            decoded = reader.float64();
          } else {
            value += reader.zigzag();
            decoded = value / scale;
          }
          rows.add(
            interval
                ? [metric, time, time + duration, decoded]
                : [metric, time, decoded],
          );
        }
      }
      return rows;
    } catch (_) {
      // Corrupt at a version this build understands. Nothing will repair it, so
      // it is dropped rather than failing the run forever.
      return const [];
    }
  }

  static Map<String, List<List<Object?>>> _groupByMetric(
    List<List<Object?>> rows,
  ) {
    final grouped = <String, List<List<Object?>>>{};
    for (final row in rows) {
      (grouped[row[0] as String] ??= <List<Object?>>[]).add(row);
    }
    return grouped;
  }

  /// The smallest scale reproducing every value exactly, or
  /// [_encodingFloat64] when none does.
  static int _scaleFor(Iterable<double> values) {
    for (final scale in _scales) {
      var exact = true;
      for (final value in values) {
        final scaled = value * scale;
        if (scaled.abs() > 9007199254740992 ||
            scaled.roundToDouble() != scaled ||
            scaled / scale != value) {
          exact = false;
          break;
        }
      }
      if (exact) return scale;
    }
    return _encodingFloat64;
  }

  static void _writeValueHeader(_Writer writer, int scale) =>
      writer.varint(scale);

  static int _writeValue(
    _Writer writer,
    double value,
    int scale,
    int previous,
  ) {
    if (scale == _encodingFloat64) {
      writer.float64(value);
      return previous;
    }
    final scaled = (value * scale).round();
    writer.zigzag(scaled - previous);
    return scaled;
  }
}

class _Writer {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void byte(int value) => _bytes.addByte(value);

  void varint(int value) {
    var remaining = value;
    while (remaining >= 0x80) {
      _bytes.addByte((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    _bytes.addByte(remaining);
  }

  /// Deltas run negative whenever rows are not perfectly ordered, and a plain
  /// varint would spend ten bytes on the sign bits.
  void zigzag(int value) => varint((value << 1) ^ (value >> 63));

  /// A fresh buffer each time, not a reused scratch one: the builder is
  /// `copy: false`, so it keeps the reference and a shared buffer would leave
  /// every value in a metric equal to the last one written.
  void float64(double value) {
    final scratch = ByteData(8)..setFloat64(0, value, Endian.little);
    _bytes.add(scratch.buffer.asUint8List());
  }

  void string(String value) {
    final utf8Bytes = utf8.encode(value);
    varint(utf8Bytes.length);
    _bytes.add(utf8Bytes);
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}

class _Reader {
  final Uint8List _bytes;
  int _offset = 0;

  _Reader(this._bytes);

  int byte() => _bytes[_offset++];

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final part = _bytes[_offset++];
      result |= (part & 0x7f) << shift;
      if (part < 0x80) return result;
      shift += 7;
    }
  }

  int zigzag() {
    final raw = varint();
    return (raw >> 1) ^ -(raw & 1);
  }

  double float64() {
    final value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 8,
    ).getFloat64(0, Endian.little);
    _offset += 8;
    return value;
  }

  String string() {
    final length = varint();
    final value = utf8.decode(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }
}
