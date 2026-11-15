import 'package:flutter/services.dart';

enum VideoKeyCommand {
  togglePlay,
  play,
  pause,
  next,
  previous,
  skipForward,
  skipBack,
  copyFrame,
  slower,
  faster,
  toggleMute,
  close,
  arrowBack,
  arrowForward,
  select,
  systemBack,
  other,
}

/// Space / K / Play toggle, J / L skip, N / P or Page Down / Up step through
/// the folder, M mutes, S copies the frame, < / > change the speed and
/// Esc / Backspace close. Null for a key release.
VideoKeyCommand? videoKeyCommand(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  final key = event.logicalKey;
  final command =
      _keys[key] ?? (event is KeyDownEvent ? _pressOnlyKeys[key] : null);
  if (command != null) return command;
  return switch (event.character) {
    '<' => VideoKeyCommand.slower,
    '>' => VideoKeyCommand.faster,
    _ => VideoKeyCommand.other,
  };
}

final Map<LogicalKeyboardKey, VideoKeyCommand> _keys = {
  LogicalKeyboardKey.mediaPlayPause: VideoKeyCommand.togglePlay,
  LogicalKeyboardKey.space: VideoKeyCommand.togglePlay,
  LogicalKeyboardKey.keyK: VideoKeyCommand.togglePlay,
  LogicalKeyboardKey.mediaTrackNext: VideoKeyCommand.next,
  LogicalKeyboardKey.pageDown: VideoKeyCommand.next,
  LogicalKeyboardKey.mediaTrackPrevious: VideoKeyCommand.previous,
  LogicalKeyboardKey.pageUp: VideoKeyCommand.previous,
  LogicalKeyboardKey.mediaPlay: VideoKeyCommand.play,
  LogicalKeyboardKey.mediaPause: VideoKeyCommand.pause,
  LogicalKeyboardKey.mediaFastForward: VideoKeyCommand.skipForward,
  LogicalKeyboardKey.keyL: VideoKeyCommand.skipForward,
  LogicalKeyboardKey.mediaRewind: VideoKeyCommand.skipBack,
  LogicalKeyboardKey.keyJ: VideoKeyCommand.skipBack,
  LogicalKeyboardKey.escape: VideoKeyCommand.close,
  LogicalKeyboardKey.backspace: VideoKeyCommand.close,
  LogicalKeyboardKey.browserBack: VideoKeyCommand.close,
  LogicalKeyboardKey.arrowLeft: VideoKeyCommand.arrowBack,
  LogicalKeyboardKey.arrowRight: VideoKeyCommand.arrowForward,
  LogicalKeyboardKey.select: VideoKeyCommand.select,
  LogicalKeyboardKey.enter: VideoKeyCommand.select,
  LogicalKeyboardKey.gameButtonA: VideoKeyCommand.select,
  LogicalKeyboardKey.goBack: VideoKeyCommand.systemBack,
};

/// Ignored while held, so a held key does not repeat them.
final Map<LogicalKeyboardKey, VideoKeyCommand> _pressOnlyKeys = {
  LogicalKeyboardKey.keyN: VideoKeyCommand.next,
  LogicalKeyboardKey.keyP: VideoKeyCommand.previous,
  LogicalKeyboardKey.keyS: VideoKeyCommand.copyFrame,
  LogicalKeyboardKey.keyM: VideoKeyCommand.toggleMute,
};
