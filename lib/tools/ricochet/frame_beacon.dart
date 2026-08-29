import 'package:flutter/foundation.dart';

/// Fires listeners on demand, and carries no value.
///
/// A realtime game keeps two: one pinged every simulated frame, which a
/// `CustomPainter` takes as its `repaint:`, and one pinged only when a number
/// the HUD displays actually changed. Splitting them is what keeps a 60 Hz
/// board from rebuilding the widget tree sixty times a second.
class FrameBeacon extends ChangeNotifier {
  void ping() => notifyListeners();
}
