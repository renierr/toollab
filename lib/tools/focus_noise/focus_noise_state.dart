import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'focus_noise_breathing.dart';
import 'focus_noise_sound.dart';

/// Persisted user preferences for the focus noise tool. Playback/session
/// progress stays in the page — this only owns values saved to the database.
class FocusNoiseState extends ChangeNotifier {
  static String get _toolId => FocusNoiseTool.config.id;

  FocusNoiseSound _selectedSound = FocusNoiseCatalog.sounds.first;
  double _volume = 0.65;
  FocusBreathingMode _breathingMode = FocusBreathingMode.relax;
  int _customMinutes = 30;

  FocusNoiseSound get selectedSound => _selectedSound;
  double get volume => _volume;
  FocusBreathingMode get breathingMode => _breathingMode;
  int get customMinutes => _customMinutes;

  /// Adopts the values of a playback session still running in the background
  /// so the UI reflects what is actually audible instead of stale settings.
  void adoptPlayback(FocusNoiseSound sound, double volume) {
    _selectedSound = sound;
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> restore() async {
    final db = DatabaseService.instance;
    final soundId = await db.getSetting(_toolId, 'selected_sound');
    final volumeRaw = await db.getSetting(_toolId, 'volume');
    final modeRaw = await db.getSetting(_toolId, 'breathing_mode');
    final customRaw = await db.getSetting(_toolId, 'timer_custom_minutes');

    if (soundId != null && soundId.isNotEmpty) {
      _selectedSound = FocusNoiseCatalog.byId(soundId);
    }
    _volume = double.tryParse(volumeRaw ?? '')?.clamp(0.0, 1.0) ?? _volume;
    _breathingMode = switch (modeRaw) {
      'box' => FocusBreathingMode.box,
      'calm' => FocusBreathingMode.calm,
      _ => FocusBreathingMode.relax,
    };
    _customMinutes = int.tryParse(customRaw ?? '')?.clamp(1, 1440) ?? 30;
    notifyListeners();
  }

  void setSelectedSound(FocusNoiseSound sound) {
    _selectedSound = sound;
    notifyListeners();
    DatabaseService.instance.setSetting(_toolId, 'selected_sound', sound.id);
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      'volume',
      _volume.toStringAsFixed(3),
    );
  }

  void setBreathingMode(FocusBreathingMode mode) {
    _breathingMode = mode;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      'breathing_mode',
      switch (mode) {
        FocusBreathingMode.box => 'box',
        FocusBreathingMode.relax => 'relax',
        FocusBreathingMode.calm => 'calm',
      },
    );
  }

  void setCustomMinutes(int minutes) {
    _customMinutes = minutes.clamp(1, 1440);
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      'timer_custom_minutes',
      _customMinutes.toString(),
    );
  }
}
