import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'audio/sleep_chunk_analyzer.dart';
import 'sound_finder_colors.dart';

extension SleepSoundCategoryStyle on SleepSoundCategory? {
  String label(AppLocalizations l10n) => switch (this) {
    SleepSoundCategory.snore => l10n.sfSleepCatSnore,
    SleepSoundCategory.speech => l10n.sfSleepCatSpeech,
    SleepSoundCategory.cough => l10n.sfSleepCatCough,
    SleepSoundCategory.impulse => l10n.sfSleepCatImpulse,
    SleepSoundCategory.movement => l10n.sfSleepCatMovement,
    SleepSoundCategory.steady => l10n.sfSleepCatSteady,
    SleepSoundCategory.other => l10n.sfSleepCatOther,
    null => l10n.sfSleepCatUnanalyzed,
  };

  Color get color => switch (this) {
    SleepSoundCategory.snore => SoundFinderColors.sleepSnore,
    SleepSoundCategory.speech => SoundFinderColors.sleepSpeech,
    SleepSoundCategory.cough => SoundFinderColors.sleepCough,
    SleepSoundCategory.impulse => SoundFinderColors.sleepImpulse,
    SleepSoundCategory.movement => SoundFinderColors.sleepMovement,
    SleepSoundCategory.steady => SoundFinderColors.sleepSteady,
    SleepSoundCategory.other => SoundFinderColors.sleepOther,
    null => SoundFinderColors.sleepUnanalyzed,
  };

  IconData get icon => switch (this) {
    SleepSoundCategory.snore => Icons.airline_seat_flat_outlined,
    SleepSoundCategory.speech => Icons.record_voice_over_outlined,
    SleepSoundCategory.cough => Icons.sick_outlined,
    SleepSoundCategory.impulse => Icons.flash_on_outlined,
    SleepSoundCategory.movement => Icons.waves_outlined,
    SleepSoundCategory.steady => Icons.air_outlined,
    SleepSoundCategory.other => Icons.graphic_eq_outlined,
    null => Icons.help_outline,
  };
}

String sleepClock(DateTime t, {bool seconds = true}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(t.hour)}:${two(t.minute)}';
  return seconds ? '$hm:${two(t.second)}' : hm;
}

String sleepTimerLabel(AppLocalizations l10n, int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return l10n.sfSleepTimerHours(h);
  if (h == 0) return l10n.sfSleepTimerMinutes(m);
  return l10n.sfSleepTimerHoursMinutes(h, m);
}

String sleepDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}
