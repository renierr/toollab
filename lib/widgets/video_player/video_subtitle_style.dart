import 'package:material_ui/material_ui.dart';

import 'video_player_settings.dart';

/// Without a background box an outline keeps the text readable on bright frames.
TextStyle videoSubtitleStyle(VideoPlayerSettings settings, double fontSize) =>
    TextStyle(
      height: 1.4,
      fontSize: fontSize * settings.subtitleScale,
      color: Colors.white,
      backgroundColor: settings.subtitleBackground
          ? const Color(0xB8000000)
          : null,
      shadows: settings.subtitleBackground
          ? null
          : const [
              Shadow(blurRadius: 3),
              Shadow(offset: Offset(1, 1), blurRadius: 2),
              Shadow(offset: Offset(-1, -1), blurRadius: 2),
            ],
    );
