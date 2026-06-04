import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart' as win32;

class AudioService {
  bool _isEnabled = false;
  Timer? _tickerTimer;
  double _currentIntervalMs = 0.0;

  bool get isEnabled => _isEnabled;

  /// Enable or disable beep sounds.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!_isEnabled) {
      _tickerTimer?.cancel();
      _tickerTimer = null;
    }
  }

  /// Plays a standard keyboard/tactile click sound using native system channels.
  /// On Windows, falls back to win32 console beep since SystemSound is often silent.
  Future<void> playTick() async {
    if (!_isEnabled) return;
    try {
      if (!kIsWeb && Platform.isWindows) {
        win32.Beep(1800, 15);
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      debugPrint('[AudioService] Error playing click sound: $e');
    }
  }

  /// Dynamically updates the click ticker interval based on EMF magnitude delta.
  void updateSignalStrength(double deltaMag, double threshold) {
    if (!_isEnabled) {
      return;
    }

    if (deltaMag < 4.0) {
      // Too weak to beep, stop the timer
      if (_tickerTimer != null) {
        _tickerTimer?.cancel();
        _tickerTimer = null;
      }
      return;
    }

    double intervalMs;

    if (deltaMag >= threshold) {
      // High alarm range: pace down to 45ms rapidly
      final overRatio = ((deltaMag - threshold) / 100.0).clamp(0.0, 1.0);
      intervalMs = 300.0 - (overRatio * 255.0); // Min 45ms
    } else {
      // Warning range: pace from 1.5s down to 300ms
      final rangeRatio = ((deltaMag - 4.0) / (threshold - 4.0)).clamp(0.0, 1.0);
      intervalMs = 1500.0 - (rangeRatio * 1200.0);
    }

    // Only restart timer if the target interval changed significantly to prevent ticker spam
    if ((intervalMs - _currentIntervalMs).abs() > 15.0 ||
        _tickerTimer == null) {
      _currentIntervalMs = intervalMs;
      _startTickerLoop();
    }
  }

  void _startTickerLoop() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(
      Duration(milliseconds: _currentIntervalMs.round()),
      (timer) {
        if (!_isEnabled) {
          timer.cancel();
          return;
        }
        playTick();
      },
    );
  }

  void dispose() {
    _tickerTimer?.cancel();
  }
}
