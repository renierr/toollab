import 'package:tool_lab/services/game_audio_service.dart';

/// Luma Well's audio voice pool. See [GameAudioService] for the guarantees.
class LumaWellAudioService {
  LumaWellAudioService._();

  static final GameAudioService instance = GameAudioService('LumaWell');
}
