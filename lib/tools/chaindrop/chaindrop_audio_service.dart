import 'package:tool_lab/services/game_audio_service.dart';

/// Chain Drop's audio voice pool. See [GameAudioService] for the guarantees.
class ChainDropAudioService {
  ChainDropAudioService._();

  static final GameAudioService instance = GameAudioService('chaindrop');
}
