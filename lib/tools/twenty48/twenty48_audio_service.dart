import 'package:tool_lab/services/game_audio_service.dart';

/// 2048's audio voice pool. See [GameAudioService] for the guarantees.
class Twenty48AudioService {
  Twenty48AudioService._();

  static final GameAudioService instance = GameAudioService('2048');
}
