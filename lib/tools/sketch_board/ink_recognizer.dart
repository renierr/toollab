import 'dart:io';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'models/sketch_element.dart';

/// Handwriting and shape recognition for freehand strokes (ML Kit, Android).
/// Models (~20 MB each) download on first use.
class SketchInkRecognizer {
  SketchInkRecognizer._();

  static bool get isSupported => Platform.isAndroid;

  static const _shapesModel = 'zxx-Zsym-x-shapes';

  static String handwritingModel(String languageCode) =>
      languageCode == 'de' ? 'de' : 'en-US';

  static Future<bool> isModelReady(String model) =>
      DigitalInkRecognizerModelManager().isModelDownloaded(model);

  static Future<void> _ensureModel(String model) async {
    final manager = DigitalInkRecognizerModelManager();
    if (await manager.isModelDownloaded(model)) return;
    final ok = await manager.downloadModel(model, isWifiRequired: false);
    if (!ok) throw StateError('Model $model could not be downloaded');
  }

  static Ink _ink(List<FreehandElement> strokes) {
    final ink = Ink();
    var t = 0;
    for (final element in strokes) {
      final stroke = Stroke();
      for (final p in element.points) {
        stroke.points.add(StrokePoint(x: p.x, y: p.y, t: t));
        t += 10;
      }
      ink.strokes.add(stroke);
    }
    return ink;
  }

  static Future<List<RecognitionCandidate>> _recognize(
    String model,
    List<FreehandElement> strokes,
  ) async {
    await _ensureModel(model);
    final recognizer = DigitalInkRecognizer(languageCode: model);
    try {
      return await recognizer.recognize(_ink(strokes));
    } finally {
      await recognizer.close();
    }
  }

  static Future<String?> recognizeText(
    List<FreehandElement> strokes,
    String languageCode,
  ) async {
    final candidates = await _recognize(
      handwritingModel(languageCode),
      strokes,
    );
    return candidates.isEmpty ? null : candidates.first.text;
  }

  /// Returns a sketch shape type, or null when the stroke is no known shape.
  static Future<String?> recognizeShape(List<FreehandElement> strokes) async {
    final candidates = await _recognize(_shapesModel, strokes);
    debugLog(
      '[SketchInkRecognizer] shapes: '
      '${candidates.map((c) => '${c.text}:${c.score}').join(', ')}',
    );
    // Lower scores are better; wrong shapes score around 10 and up.
    final best = candidates.firstOrNull;
    if (best == null || best.score > 5) return null;
    return _shapeType(best.text.toLowerCase());
  }

  static String? _shapeType(String label) {
    if (label.contains('arrow')) return 'arrow';
    if (label.contains('rect') || label.contains('square')) return 'rect';
    if (label.contains('ellipse') ||
        label.contains('circle') ||
        label.contains('oval')) {
      return 'ellipse';
    }
    if (label.contains('triangle')) return 'triangle';
    if (label.contains('diamond') || label.contains('rhomb')) return 'diamond';
    if (label.contains('hexagon')) return 'hexagon';
    if (label.contains('line')) return 'line';
    return null;
  }
}
