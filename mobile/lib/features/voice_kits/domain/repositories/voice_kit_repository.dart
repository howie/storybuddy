import '../../../../models/voice_kit.dart';

abstract class VoiceKitRepository {
  Future<List<VoiceCharacter>> getVoices();
  Future<List<VoiceKit>> getVoiceKits();
  Future<VoiceKit> downloadVoiceKit(String kitId);
  Future<Map<String, dynamic>> getPreferences(String userId);
  Future<Map<String, dynamic>> updatePreferences(
      String userId, String defaultVoiceId,);
  Future<List<dynamic>> getStoryVoiceMappings(String userId, String storyId);
  Future<Map<String, dynamic>> updateStoryVoiceMapping(
      String userId, String storyId, String role, String voiceId,);
}
