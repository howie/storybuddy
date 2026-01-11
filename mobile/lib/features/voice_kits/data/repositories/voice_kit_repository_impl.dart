import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/voice_kit.dart';
import '../../domain/repositories/voice_kit_repository.dart';
import '../datasources/voice_kit_remote_datasource.dart';

class VoiceKitRepositoryImpl implements VoiceKitRepository {
  VoiceKitRepositoryImpl(this._remoteDataSource);
  final VoiceKitRemoteDataSource _remoteDataSource;

  @override
  Future<List<VoiceCharacter>> getVoices() async {
    return _remoteDataSource.getVoices();
  }

  @override
  Future<List<VoiceKit>> getVoiceKits() async {
    return _remoteDataSource.getVoiceKits();
  }

  @override
  Future<VoiceKit> downloadVoiceKit(String kitId) async {
    return _remoteDataSource.downloadVoiceKit(kitId);
  }

  @override
  Future<Map<String, dynamic>> getPreferences(String userId) async {
    return _remoteDataSource.getPreferences(userId);
  }

  @override
  Future<Map<String, dynamic>> updatePreferences(
    String userId,
    String defaultVoiceId,
  ) async {
    return _remoteDataSource.updatePreferences(userId, defaultVoiceId);
  }

  @override
  Future<List<dynamic>> getStoryVoiceMappings(
    String userId,
    String storyId,
  ) async {
    return _remoteDataSource.getStoryVoiceMappings(userId, storyId);
  }

  @override
  Future<Map<String, dynamic>> updateStoryVoiceMapping(
    String userId,
    String storyId,
    String role,
    String voiceId,
  ) async {
    return _remoteDataSource.updateStoryVoiceMapping(
      userId,
      storyId,
      role,
      voiceId,
    );
  }
}

final voiceKitRepositoryProvider = Provider<VoiceKitRepository>((ref) {
  final remoteDataSource = ref.read(voiceKitRemoteDataSourceProvider);
  return VoiceKitRepositoryImpl(remoteDataSource);
});
