import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// What the badge shows; [flash] it after a gesture or a key.
class VideoBadgeController extends ChangeNotifier {
  Timer? _timer;
  bool _visible = false;
  IconData _icon = Icons.fast_forward;
  String _label = '';
  Alignment _alignment = Alignment.center;
  double? _level;

  bool get visible => _visible;
  IconData get icon => _icon;
  String get label => _label;
  Alignment get alignment => _alignment;
  double? get level => _level;

  /// [level] draws a 0–1 bar; [hold] keeps the badge up until [hide].
  void flash({
    required IconData icon,
    required String label,
    Alignment alignment = Alignment.center,
    double? level,
    bool hold = false,
  }) {
    _timer?.cancel();
    _icon = icon;
    _label = label;
    _alignment = alignment;
    _level = level;
    _visible = true;
    notifyListeners();
    if (!hold) _timer = Timer(const Duration(milliseconds: 700), hide);
  }

  void hide() {
    _timer?.cancel();
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Brief feedback for a gesture on the video: a skip or a volume change.
class VideoGestureBadge extends StatelessWidget {
  final VideoBadgeController controller;

  const VideoGestureBadge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final level = controller.level;
          return AnimatedOpacity(
            opacity: controller.visible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Align(
              alignment: controller.alignment,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(controller.icon, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            controller.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      if (level != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            value: level.clamp(0.0, 1.0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
