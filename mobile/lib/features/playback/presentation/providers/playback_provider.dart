import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/audio/audio_cache_manager.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import '../../data/datasources/playback_local_datasource.dart';
import '../../data/datasources/playback_remote_datasource.dart';
import '../../data/repositories/playback_repository_impl.dart';
import '../../domain/entities/story_playback.dart';
import '../../domain/repositories/playback_repository.dart';
import '../../domain/usecases/generate_audio.dart';
import '../../domain/usecases/play_story.dart';

part 'playback_provider.g.dart';

/// Provider for [PlaybackRemoteDataSource].
@riverpod
PlaybackRemoteDataSource playbackRemoteDataSource(
  PlaybackRemoteDataSourceRef ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return PlaybackRemoteDataSourceImpl(apiClient: apiClient);
}

/// Provider for [PlaybackLocalDataSource].
@riverpod
PlaybackLocalDataSource playbackLocalDataSource(
  PlaybackLocalDataSourceRef ref,
) {
  final audioCacheManager = ref.watch(audioCacheManagerProvider);
  final storyLocalDataSource = ref.watch(storyLocalDataSourceProvider);
  return PlaybackLocalDataSourceImpl(
    audioCacheManager: audioCacheManager,
    storyLocalDataSource: storyLocalDataSource,
  );
}

/// Provider for [PlaybackRepository].
@riverpod
PlaybackRepository playbackRepository(PlaybackRepositoryRef ref) {
  final repository = PlaybackRepositoryImpl(
    remoteDataSource: ref.watch(playbackRemoteDataSourceProvider),
    localDataSource: ref.watch(playbackLocalDataSourceProvider),
    storyLocalDataSource: ref.watch(storyLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );

  ref.onDispose(repository.dispose);

  return repository;
}

/// Provider for [GenerateAudioUseCase].
@riverpod
GenerateAudioUseCase generateAudioUseCase(GenerateAudioUseCaseRef ref) {
  return GenerateAudioUseCase(
    repository: ref.watch(playbackRepositoryProvider),
  );
}

/// Provider for [PlayStoryUseCase].
@riverpod
PlayStoryUseCase playStoryUseCase(PlayStoryUseCaseRef ref) {
  return PlayStoryUseCase(
    repository: ref.watch(playbackRepositoryProvider),
  );
}

/// Provider for the current playback state stream.
@riverpod
Stream<StoryPlayback> playbackStream(PlaybackStreamRef ref) {
  final repository = ref.watch(playbackRepositoryProvider);
  return repository.playbackState;
}

/// Notifier for playback control.
@riverpod
class PlaybackNotifier extends _$PlaybackNotifier {
  @override
  StoryPlayback build() {
    // Listen to playback state changes
    final repository = ref.watch(playbackRepositoryProvider);

    repository.playbackState.listen((state) {
      this.state = state;
    });

    return const StoryPlayback(
      storyId: '',
      storyTitle: '',
    );
  }

  /// Plays a story.
  Future<void> play(String storyId) async {
    try {
      final repository = ref.read(playbackRepositoryProvider);
      await repository.playStory(storyId);
    } catch (e) {
      state = state.copyWith(
        state: PlaybackState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.pause();
  }

  /// Resumes playback.
  Future<void> resume() async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.resume();
  }

  /// Toggles play/pause.
  Future<void> toggle() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Seeks to a position.
  Future<void> seekTo(Duration position) async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.seekTo(position);
  }

  /// Stops playback.
  Future<void> stop() async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.stop();
    state = const StoryPlayback(
      storyId: '',
      storyTitle: '',
    );
  }

  /// Sets playback speed.
  Future<void> setSpeed(double speed) async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.setSpeed(speed);
  }

  /// Downloads audio for offline playback.
  Future<void> downloadAudio(String storyId) async {
    final repository = ref.read(playbackRepositoryProvider);
    await repository.downloadAudio(storyId);
  }

  /// Generates audio for a story.
  Future<void> generateAudio({
    required String storyId,
    required String voiceProfileId,
  }) async {
    try {
      state = state.copyWith(state: PlaybackState.loading);

      final useCase = ref.read(generateAudioUseCaseProvider);
      await useCase.call(
        storyId: storyId,
        voiceProfileId: voiceProfileId,
      );

      state = state.copyWith(state: PlaybackState.idle);
    } catch (e) {
      state = state.copyWith(
        state: PlaybackState.error,
        errorMessage: e.toString(),
      );
    }
  }
}
