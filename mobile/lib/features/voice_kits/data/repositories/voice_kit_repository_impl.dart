import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/voice_kit.dart';
import '../../domain/repositories/voice_kit_repository.dart';
import '../datasources/voice_kit_remote_datasource.dart';

class VoiceKitRepositoryImpl implements VoiceKitRepository {
  final VoiceKitRemoteDataSource _remoteDataSource;

  VoiceKitRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<VoiceCharacter>> getVoices() async {
    return _remoteDataSource.getVoices();
  }
}

final voiceKitRepositoryProvider = Provider<VoiceKitRepository>((ref) {
  final remoteDataSource = ref.read(voiceKitRemoteDataSourceProvider);
  return VoiceKitRepositoryImpl(remoteDataSource);
});
