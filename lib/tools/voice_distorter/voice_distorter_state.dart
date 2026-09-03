import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../helpers/temp_file_manager.dart';
import 'engine/voice_effect.dart';
import 'engine/voice_effect_engine.dart';
import 'engine/voice_recorder.dart';
import 'presets_db_helper.dart';

enum VoiceDistorterMode { clip, live }

enum RecordStopResult { ok, tooShort, failed }

class VoiceDistorterState extends ChangeNotifier {
  /// Below this the capture has too few frames to be worth loading.
  static const Duration minClipDuration = Duration(milliseconds: 150);

  final TempFileScope _scope = TempFileManager.createScope();
  late final VoiceRecorder _recorder = VoiceRecorder(_scope);
  final VoiceEffectEngine _engine = VoiceEffectEngine.instance;

  VoiceDistorterMode mode = VoiceDistorterMode.clip;
  bool hasClip = false;
  bool isExporting = false;
  VoiceEffectParams params = VoicePresets.all.first.params;
  String? selectedPresetId = VoicePresets.all.first.id;
  List<VoicePreset> customPresets = const [];

  bool _starting = false;
  bool _stopRequestedWhileStarting = false;

  bool get isRecording => _starting || _recorder.isRecording;
  bool get isPlaying => _engine.isPlaying.value;
  ValueListenable<double> get recordLevel => _recorder.level;

  VoiceDistorterState() {
    _engine.isPlaying.addListener(notifyListeners);
    _recorder.onLimitReached = () {
      unawaited(_finishRecording());
    };
    unawaited(_loadCustomPresets());
  }

  Future<void> _loadCustomPresets() async {
    customPresets = await VoicePresetsDbHelper.instance.list();
    notifyListeners();
  }

  void setMode(VoiceDistorterMode m) {
    if (mode == m || isRecording) return;
    mode = m;
    notifyListeners();
  }

  Future<RecordStartResult> startRecording() async {
    if (isRecording) return RecordStartResult.ok;
    _starting = true;
    notifyListeners();
    final result = await _recorder.start();
    _starting = false;
    // A press-and-hold released before start() resolved must not leave the
    // recorder running until the auto-stop timer fires.
    if (_stopRequestedWhileStarting) {
      _stopRequestedWhileStarting = false;
      await _finishRecording();
      return result;
    }
    notifyListeners();
    return result;
  }

  Future<RecordStopResult> stopRecording() async {
    if (_starting) {
      _stopRequestedWhileStarting = true;
      return RecordStopResult.tooShort;
    }
    return _finishRecording();
  }

  Future<RecordStopResult> _finishRecording() async {
    final VoiceClip? clip = await _recorder.stop();
    if (clip == null) {
      notifyListeners();
      return RecordStopResult.failed;
    }
    // A stabbed live-mode tap yields a WAV with no frames, which the decoder
    // rejects outright.
    final Duration? duration = clip.duration;
    if (duration != null && duration < minClipDuration) {
      notifyListeners();
      return RecordStopResult.tooShort;
    }

    final bool loaded = await _engine.loadClip(
      clip.path,
      isStereo: clip.isStereo,
    );
    hasClip = loaded;
    if (loaded && mode == VoiceDistorterMode.live) {
      await _engine.play(params);
    }
    notifyListeners();
    return loaded ? RecordStopResult.ok : RecordStopResult.failed;
  }

  Future<void> playCurrent() async {
    if (!hasClip) return;
    await _engine.play(params);
  }

  Future<void> stopPlayback() => _engine.stop();

  /// Renders the clip with the active effect to WAV bytes. Audible and real
  /// time, so the UI shows [isExporting] while it runs.
  Future<Uint8List?> renderCurrentClip() async {
    if (!hasClip || isExporting) return null;
    isExporting = true;
    notifyListeners();
    try {
      return await _engine.renderToWav(params);
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  void selectPreset(VoicePreset preset) {
    params = preset.params;
    selectedPresetId = preset.id;
    notifyListeners();
    if (hasClip) unawaited(_engine.play(params));
  }

  void updateParams(VoiceEffectParams next) {
    params = next;
    selectedPresetId = null;
    notifyListeners();
  }

  Future<void> saveCustomPreset(String name) async {
    final VoicePreset saved = await VoicePresetsDbHelper.instance.save(
      name,
      params,
    );
    customPresets = [...customPresets, saved];
    selectedPresetId = saved.id;
    notifyListeners();
  }

  Future<void> deleteCustomPreset(VoicePreset preset) async {
    final int? dbId = preset.dbId;
    if (dbId == null) return;
    await VoicePresetsDbHelper.instance.delete(dbId);
    customPresets = customPresets
        .where((p) => p.dbId != dbId)
        .toList(growable: false);
    if (selectedPresetId == preset.id) selectedPresetId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine.isPlaying.removeListener(notifyListeners);
    unawaited(_recorder.dispose());
    unawaited(_engine.dispose());
    unawaited(_scope.cleanTracked());
    super.dispose();
  }
}
