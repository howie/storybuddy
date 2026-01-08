import '../../../../models/voice_kit.dart';

abstract class VoiceKitRepository {
  Future<List<VoiceCharacter>> getVoices();
}
