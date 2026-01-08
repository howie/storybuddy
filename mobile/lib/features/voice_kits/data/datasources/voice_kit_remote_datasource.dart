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
}

abstract class VoiceKitRemoteDataSource {
  Future<List<VoiceCharacter>> getVoices();
  Future<List<VoiceKit>> getVoiceKits();
  Future<VoiceKit> downloadVoiceKit(String kitId);
}

final voiceKitRemoteDataSourceProvider = Provider<VoiceKitRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VoiceKitRemoteDataSourceImpl(apiClient);
});
