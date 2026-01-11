import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../models/voice_kit.dart';
import '../../data/repositories/voice_kit_repository_impl.dart';

// -- Voice List Provider --
final voiceListProvider = FutureProvider<List<VoiceCharacter>>((ref) async {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return repository.getVoices();
});

// -- Selected Voice State --
final selectedVoiceIdProvider = StateProvider<String?>((ref) => null);

// -- Voice Preview Notifier --
class VoicePreviewNotifier extends StateNotifier<String?> {
  VoicePreviewNotifier() : super(null);
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playPreview(String? url, String voiceId) async {
    if (url == null) return;

    try {
      state = voiceId; // Set current playing voice ID to update UI
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      // Reset state when finished
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          state = null;
        }
      });
    } catch (e) {
      state = null;
      print('Error playing preview: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    state = null;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

final voicePreviewProvider =
    StateNotifierProvider<VoicePreviewNotifier, String?>((ref) {
  return VoicePreviewNotifier();
});

// -- Voice Kits Provider --
final voiceKitsProvider = FutureProvider<List<VoiceKit>>((ref) async {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return repository.getVoiceKits();
});

// -- Download Kit Controller --
class DownloadKitController extends StateNotifier<AsyncValue<void>> {
  DownloadKitController(this._repository) : super(const AsyncValue.data(null));
  final VoiceKitRepository _repository;

  Future<void> downloadKit(String kitId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.downloadVoiceKit(kitId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final downloadKitControllerProvider =
    StateNotifierProvider<DownloadKitController, AsyncValue<void>>((ref) {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return DownloadKitController(repository);
});

// -- Voice Preferences --
final voicePreferencesProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return repository.getPreferences(userId);
});

class VoicePreferencesController extends StateNotifier<AsyncValue<void>> {
  VoicePreferencesController(this._repository)
      : super(const AsyncValue.data(null));
  final VoiceKitRepository _repository;

  Future<void> updateDefaultVoice(String userId, String voiceId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updatePreferences(userId, voiceId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final voicePreferencesControllerProvider =
    StateNotifierProvider<VoicePreferencesController, AsyncValue<void>>((ref) {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return VoicePreferencesController(repository);
});

// -- Story Voice Mappings --

// Tuple for family arguments? Or a custom class.
class StoryVoiceMappingParams {
  StoryVoiceMappingParams(this.userId, this.storyId);
  final String userId;
  final String storyId;

  @override
  bool operator ==(Object other) =>
      other is StoryVoiceMappingParams &&
      other.userId == userId &&
      other.storyId == storyId;

  @override
  int get hashCode => Object.hash(userId, storyId);
}

final storyVoiceMappingsProvider =
    FutureProvider.family<List<dynamic>, StoryVoiceMappingParams>(
        (ref, params) async {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return repository.getStoryVoiceMappings(params.userId, params.storyId);
});

class StoryVoiceMapController extends StateNotifier<AsyncValue<void>> {
  StoryVoiceMapController(this._repository)
      : super(const AsyncValue.data(null));
  final VoiceKitRepository _repository;

  Future<void> updateMapping(
    String userId,
    String storyId,
    String role,
    String voiceId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateStoryVoiceMapping(userId, storyId, role, voiceId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final storyVoiceMapControllerProvider =
    StateNotifierProvider<StoryVoiceMapController, AsyncValue<void>>((ref) {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return StoryVoiceMapController(repository);
});
