import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../models/voice_kit.dart';

abstract class VoiceKitRemoteDataSource {
  Future<List<VoiceCharacter>> getVoices();
  Future<List<VoiceCharacter>> getVoiceKits(); // For US2 later
}

class VoiceKitRemoteDataSourceImpl implements VoiceKitRemoteDataSource {
  final ApiClient _apiClient;

  VoiceKitRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<VoiceCharacter>> getVoices() async {
    final response = await _apiClient.get('/voices');
    return (response.data as List)
        .map((e) => VoiceCharacter.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  
  @override
  Future<List<VoiceCharacter>> getVoiceKits() async {
     // TODO: Implement for US2
     return [];
  }
}

final voiceKitRemoteDataSourceProvider = Provider<VoiceKitRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VoiceKitRemoteDataSourceImpl(apiClient);
});
