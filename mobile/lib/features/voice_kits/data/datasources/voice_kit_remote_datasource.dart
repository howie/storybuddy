import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../models/voice_kit.dart';

abstract class VoiceKitRemoteDataSource {
  Future<List<VoiceCharacter>> getVoices();
  Future<List<VoiceKit>> getVoiceKits();
  Future<VoiceKit> downloadVoiceKit(String kitId);
  Future<Map<String, dynamic>> getPreferences(String userId);
  Future<Map<String, dynamic>> updatePreferences(String userId, String defaultVoiceId);
  Future<List<dynamic>> getStoryVoiceMappings(String userId, String storyId);
  Future<Map<String, dynamic>> updateStoryVoiceMapping(String userId, String storyId, String role, String voiceId);
}

class VoiceKitRemoteDataSourceImpl implements VoiceKitRemoteDataSource {
  final ApiClient _apiClient;

  VoiceKitRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<VoiceCharacter>> getVoices() async {
    final response = await _apiClient.get('/voices'); // Assuming /voices list individual voices if needed, or extract from kits?
    // Wait, original implementation likely called /voices endpoint which lists system voices.
    // In backend /voices returns List[VoiceCharacter].
    return (response.data as List)
        .map((e) => VoiceCharacter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<VoiceKit>> getVoiceKits() async {
    final response = await _apiClient.get('/kits');
    return (response.data as List)
        .map((e) => VoiceKit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VoiceKit> downloadVoiceKit(String kitId) async {
    final response = await _apiClient.post('/kits/$kitId/download');
    return VoiceKit.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getPreferences(String userId) async {
    final response = await _apiClient.get('/voices/preferences', queryParameters: {'user_id': userId});
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updatePreferences(String userId, String defaultVoiceId) async {
    final response = await _apiClient.post('/voices/preferences', data: {
      'user_id': userId,
      'default_voice_id': defaultVoiceId,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getStoryVoiceMappings(String userId, String storyId) async {
    final response = await _apiClient.get('/stories/$storyId/voices', queryParameters: {'user_id': userId});
    return response.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateStoryVoiceMapping(String userId, String storyId, String role, String voiceId) async {
    final response = await _apiClient.post('/stories/$storyId/voices', data: {
      'user_id': userId,
      'role': role,
      'voice_id': voiceId,
    });
    return response.data as Map<String, dynamic>;
  }
}

final voiceKitRemoteDataSourceProvider = Provider<VoiceKitRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VoiceKitRemoteDataSourceImpl(apiClient);
});
