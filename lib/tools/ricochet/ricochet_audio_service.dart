import 'package:tool_lab/services/game_audio_service.dart';

/// Ricochet's audio voice pool. See [GameAudioService] for the guarantees.
class RicochetAudioService {
  RicochetAudioService._();

  static final GameAudioService instance = GameAudioService('Ricochet');
}
