import '../../l10n/app_localizations.dart';
import 'engine/voice_effect.dart';

/// Resolves a built-in preset's localized display name by id. Custom presets
/// carry their user-given name directly and never hit this switch.
String localizedPresetName(AppLocalizations l10n, VoicePreset preset) {
  if (preset.isCustom) return preset.name;
  return switch (preset.id) {
    'chipmunk' => l10n.voiceDistorterPresetChipmunk,
    'helium' => l10n.voiceDistorterPresetHelium,
    'deep_voice' => l10n.voiceDistorterPresetDeepVoice,
    'giant' => l10n.voiceDistorterPresetGiant,
    'robot' => l10n.voiceDistorterPresetRobot,
    'cyborg' => l10n.voiceDistorterPresetCyborg,
    'alien' => l10n.voiceDistorterPresetAlien,
    'telephone' => l10n.voiceDistorterPresetTelephone,
    'radio' => l10n.voiceDistorterPresetRadio,
    'ghost' => l10n.voiceDistorterPresetGhost,
    'monster' => l10n.voiceDistorterPresetMonster,
    'dark_lord' => l10n.voiceDistorterPresetDarkLord,
    _ => preset.name,
  };
}
