import 'package:tool_lab/services/game_audio_service.dart';

/// Drift Bloom's audio voice pool. See [GameAudioService] for the guarantees.
class DriftBloomAudioService {
  DriftBloomAudioService._();

  static final GameAudioService instance = GameAudioService('DriftBloom');
}
