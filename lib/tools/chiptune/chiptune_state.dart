import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'engine/mixer.dart';
import 'widgets/visualizations/chiptune_viz_registry.dart';

/// Persisted player settings for the chiptune tool. The page mirrors changes
/// onto its [ChiptunePlayer] via a listener; this class only owns storage.
class ChiptuneState extends ChangeNotifier {
  static String get _toolId => ChiptuneTool.config.id;

  static const String _kVolume = 'volume';
  static const String _kStereoWidth = 'stereo_width';
  static const String _kInterpolation = 'interpolation';
  static const String _kPreAmp = 'preamp';
  static const String _kAmigaFilter = 'amiga_filter';
  static const String _kRampStep = 'ramp_step';
  static const String _kModSeparation = 'mod_separation';
  static const String _kLooping = 'looping';
  static const String _kVisualizer = 'visualizer';
  static const String _kVizId = 'vis_id';
  static const String _kOutputDeviceId = 'output_device_id';

  double _volume = 0.7;
  double _stereoWidth = 1.0;
  ChiptuneInterpolation _interpolation = ChiptuneInterpolation.sinc;
  double _preAmp = defaultPreAmp;
  ChiptuneAmigaFilter _amigaFilter = ChiptuneAmigaFilter.auto;
  double _rampStep = defaultRampStep;
  double _modSeparation = defaultModSeparation;
  bool _looping = false;
  bool _visualizerEnabled = true;
  String _currentVizId = ChiptuneVizRegistry.defaultId;
  int? _outputDeviceId;

  double get volume => _volume;
  double get stereoWidth => _stereoWidth;
  ChiptuneInterpolation get interpolation => _interpolation;
  double get preAmp => _preAmp;
  ChiptuneAmigaFilter get amigaFilter => _amigaFilter;
  double get rampStep => _rampStep;
  double get modSeparation => _modSeparation;
  bool get looping => _looping;
  bool get visualizerEnabled => _visualizerEnabled;
  String get currentVizId => _currentVizId;
  int? get outputDeviceId => _outputDeviceId;

  /// Reads all persisted settings from the database. Call once on startup
  /// before applying values to the player.
  Future<void> restore() async {
    final db = DatabaseService.instance;
    final vol = await db.getSetting(_toolId, _kVolume);
    final widthStr = await db.getSetting(_toolId, _kStereoWidth);
    final interpStr = await db.getSetting(_toolId, _kInterpolation);
    final preAmpStr = await db.getSetting(_toolId, _kPreAmp);
    final amigaStr = await db.getSetting(_toolId, _kAmigaFilter);
    final rampStr = await db.getSetting(_toolId, _kRampStep);
    final sepStr = await db.getSetting(_toolId, _kModSeparation);
    final loop = await db.getSetting(_toolId, _kLooping);
    final visOn = await db.getSetting(_toolId, _kVisualizer);
    final vis = await db.getSetting(_toolId, _kVizId);
    final deviceIdStr = await db.getSetting(_toolId, _kOutputDeviceId);

    _volume = double.tryParse(vol ?? '') ?? _volume;
    _stereoWidth = double.tryParse(widthStr ?? '') ?? _stereoWidth;
    final interpIdx = int.tryParse(interpStr ?? '');
    _interpolation =
        (interpIdx != null &&
            interpIdx >= 0 &&
            interpIdx < ChiptuneInterpolation.values.length)
        ? ChiptuneInterpolation.values[interpIdx]
        : _interpolation;
    _preAmp = double.tryParse(preAmpStr ?? '') ?? _preAmp;
    final amigaIdx = int.tryParse(amigaStr ?? '');
    _amigaFilter =
        (amigaIdx != null &&
            amigaIdx >= 0 &&
            amigaIdx < ChiptuneAmigaFilter.values.length)
        ? ChiptuneAmigaFilter.values[amigaIdx]
        : _amigaFilter;
    _rampStep = double.tryParse(rampStr ?? '') ?? _rampStep;
    _modSeparation = double.tryParse(sepStr ?? '') ?? _modSeparation;
    _looping = loop == '1';
    _visualizerEnabled = visOn != '0';
    _currentVizId = vis ?? _currentVizId;
    _outputDeviceId = int.tryParse(deviceIdStr ?? '');
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kVolume,
      v.toStringAsFixed(3),
    );
  }

  void setStereoWidth(double v) {
    _stereoWidth = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kStereoWidth,
      v.toStringAsFixed(3),
    );
  }

  void setInterpolation(ChiptuneInterpolation mode) {
    _interpolation = mode;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kInterpolation,
      mode.index.toString(),
    );
  }

  void setPreAmp(double v) {
    _preAmp = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kPreAmp,
      v.toStringAsFixed(3),
    );
  }

  void setAmigaFilter(ChiptuneAmigaFilter mode) {
    _amigaFilter = mode;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kAmigaFilter,
      mode.index.toString(),
    );
  }

  void setRampStep(double v) {
    _rampStep = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kRampStep,
      v.toStringAsFixed(4),
    );
  }

  void setModSeparation(double v) {
    _modSeparation = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kModSeparation,
      v.toStringAsFixed(3),
    );
  }

  void setLooping(bool v) {
    _looping = v;
    notifyListeners();
    DatabaseService.instance.setSetting(_toolId, _kLooping, v ? '1' : '0');
  }

  void setVisualizerEnabled(bool v) {
    _visualizerEnabled = v;
    notifyListeners();
    DatabaseService.instance.setSetting(_toolId, _kVisualizer, v ? '1' : '0');
  }

  void setCurrentVizId(String id) {
    _currentVizId = id;
    notifyListeners();
    DatabaseService.instance.setSetting(_toolId, _kVizId, id);
  }

  void setOutputDeviceId(int? id) {
    _outputDeviceId = id;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      _kOutputDeviceId,
      id?.toString() ?? '',
    );
  }
}
