import '../../../../models/voice_kit.dart';

abstract class VoiceKitRepository {
  Future<List<VoiceCharacter>> getVoices();
  Future<List<VoiceKit>> getVoiceKits();
  Future<VoiceKit> downloadVoiceKit(String kitId);
}
