import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:image/image.dart' as img;

class ImageMetadata {
  final Map<String, Map<String, String>> exifTags;
  final double? latitude;
  final double? longitude;
  final String? gpsDMS;
  final Uint8List? thumbnailBytes;

  ImageMetadata({
    required this.exifTags,
    this.latitude,
    this.longitude,
    this.gpsDMS,
    this.thumbnailBytes,
  });
}

ImageMetadata extractMetadataTask(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return ImageMetadata(exifTags: {});
    }

    final exif = decoded.exif;
    final tags = <String, Map<String, String>>{};

    void extractDirectory(String name, img.IfdDirectory? dir) {
      if (dir == null || dir.isEmpty) return;
      final map = <String, String>{};
      for (final key in dir.keys) {
        final tagName = exif.getTagName(key);
        final val = dir[key];
        if (val != null) {
          map[tagName] = val.toString();
        }
      }
      if (map.isNotEmpty) {
        tags[name] = map;
      }
    }

    extractDirectory('Image Info', exif.imageIfd);
    extractDirectory('Exif Info', exif.exifIfd);
    extractDirectory('GPS Info', exif.gpsIfd);
    extractDirectory('Thumbnail Info', exif.thumbnailIfd);
    extractDirectory('Interop Info', exif.interopIfd);

    double? lat;
    double? lon;
    String? gpsDMS;

    final gpsDir = exif.gpsIfd;
    if (!gpsDir.isEmpty) {
      final latVal = gpsDir[2]; // Tag 2 is GPSLatitude
      final latRef = gpsDir.gpsLatitudeRef;
      final lonVal = gpsDir[4]; // Tag 4 is GPSLongitude
      final lonRef = gpsDir.gpsLongitudeRef;

      final parsedLat = _parseGpsCoordinate(latVal, latRef);
      final parsedLon = _parseGpsCoordinate(lonVal, lonRef);

      if (parsedLat != null && parsedLon != null) {
        lat = parsedLat;
        lon = parsedLon;
        gpsDMS =
            '${_formatDMS(latVal, latRef)} / ${_formatDMS(lonVal, lonRef)}';
      }
    }

    final thumbnailBytes = _extractJpegThumbnail(bytes);

    return ImageMetadata(
      exifTags: tags,
      latitude: lat,
      longitude: lon,
      gpsDMS: gpsDMS,
      thumbnailBytes: thumbnailBytes,
    );
  } catch (e) {
    errorLog("Failed to extract metadata: $e");
    return ImageMetadata(exifTags: {});
  }
}

Uint8List? _extractJpegThumbnail(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }

  int i = 2;
  while (i < bytes.length - 4) {
    if (bytes[i] != 0xFF) {
      break;
    }

    final marker = bytes[i + 1];
    if (marker == 0xD8) {
      i += 2;
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) {
      break;
    }

    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final segmentEnd = i + 2 + length;

    if (segmentEnd > bytes.length) {
      break;
    }

    if (marker == 0xE1) {
      if (length >= 8 &&
          bytes[i + 4] == 0x45 && // E
          bytes[i + 5] == 0x78 && // x
          bytes[i + 6] == 0x69 && // i
          bytes[i + 7] == 0x66 && // f
          bytes[i + 8] == 0x00 &&
          bytes[i + 9] == 0x00) {
        int soiIdx = -1;
        for (int j = i + 10; j < segmentEnd - 1; j++) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD8) {
            soiIdx = j;
            break;
          }
        }

        if (soiIdx != -1) {
          int eoiIdx = -1;
          for (int j = soiIdx + 2; j < segmentEnd - 1; j++) {
            if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
              eoiIdx = j + 2;
              break;
            }
          }

          if (eoiIdx != -1) {
            return bytes.sublist(soiIdx, eoiIdx);
          }
        }
      }
    }

    i += 2 + length;
  }
  return null;
}

double? _parseGpsCoordinate(dynamic value, String? ref) {
  if (value == null) return null;
  try {
    final str = value.toString();
    final matches = RegExp(r'\d+/\d+|\d+\.\d+|\d+').allMatches(str);
    final List<double> parts = [];
    for (final m in matches) {
      final tok = m.group(0)!;
      if (tok.contains('/')) {
        final fraction = tok.split('/');
        final numVal = double.tryParse(fraction[0]);
        final denVal = double.tryParse(fraction[1]);
        if (numVal != null && denVal != null && denVal != 0) {
          parts.add(numVal / denVal);
        }
      } else {
        final parsed = double.tryParse(tok);
        if (parsed != null) parts.add(parsed);
      }
    }

    if (parts.length >= 3) {
      double decimal = parts[0] + (parts[1] / 60.0) + (parts[2] / 3600.0);
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }
      return decimal;
    } else if (parts.length == 1) {
      double decimal = parts[0];
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }
      return decimal;
    }
  } catch (e) {
    errorLog("Failed to parse GPS coordinate: $e");
  }
  return null;
}

String _formatDMS(dynamic value, String? ref) {
  if (value == null) return '';
  try {
    final str = value.toString();
    final matches = RegExp(r'\d+/\d+|\d+\.\d+|\d+').allMatches(str);
    final List<double> parts = [];
    for (final m in matches) {
      final tok = m.group(0)!;
      if (tok.contains('/')) {
        final fraction = tok.split('/');
        final numVal = double.tryParse(fraction[0]);
        final denVal = double.tryParse(fraction[1]);
        if (numVal != null && denVal != null && denVal != 0) {
          parts.add(numVal / denVal);
        }
      } else {
        final parsed = double.tryParse(tok);
        if (parsed != null) parts.add(parsed);
      }
    }

    if (parts.length >= 3) {
      return "${parts[0].round()}° ${parts[1].round()}' ${parts[2].toStringAsFixed(2)}\" ${ref ?? ''}";
    }
  } catch (_) {}
  return '$value ${ref ?? ''}';
}
