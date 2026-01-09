import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/audio/audio_cache_manager.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/datasources/story_local_datasource.dart';
import '../../data/datasources/story_remote_datasource.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../../domain/usecases/get_stories.dart';

part 'story_provider.g.dart';

/// Provider for [StoryRemoteDataSource].
@riverpod
StoryRemoteDataSource storyRemoteDataSource(StoryRemoteDataSourceRef ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StoryRemoteDataSourceImpl(apiClient: apiClient);
}

/// Provider for [StoryLocalDataSource].
@riverpod
StoryLocalDataSource storyLocalDataSource(StoryLocalDataSourceRef ref) {
  final database = ref.watch(databaseProvider);
  return StoryLocalDataSourceImpl(database: database);
}

/// Provider for [StoryRepository].
@riverpod
StoryRepository storyRepository(StoryRepositoryRef ref) {
  return StoryRepositoryImpl(
    remoteDataSource: ref.watch(storyRemoteDataSourceProvider),
    localDataSource: ref.watch(storyLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
    audioCacheManager: ref.watch(audioCacheManagerProvider),
  );
}

/// Provider for [GetStoriesUseCase].
@riverpod
GetStoriesUseCase getStoriesUseCase(GetStoriesUseCaseRef ref) {
  return GetStoriesUseCase(repository: ref.watch(storyRepositoryProvider));
}

/// Provider for [GetStoryUseCase].
@riverpod
GetStoryUseCase getStoryUseCase(GetStoryUseCaseRef ref) {
  return GetStoryUseCase(repository: ref.watch(storyRepositoryProvider));
}

/// Provider for watching all stories.
@riverpod
Stream<List<Story>> storiesStream(StoriesStreamRef ref) {
  final useCase = ref.watch(getStoriesUseCaseProvider);
  return useCase.watch();
}

/// Provider for watching a single story.
@riverpod
Stream<Story?> storyStream(StoryStreamRef ref, String id) {
  final useCase = ref.watch(getStoryUseCaseProvider);
  return useCase.watch(id);
}

/// Notifier for story list state and actions.
@riverpod
class StoryListNotifier extends _$StoryListNotifier {
  @override
  Future<List<Story>> build() async {
    final repository = ref.watch(storyRepositoryProvider);
    return repository.getStories();
  }

  /// Refreshes the story list from remote.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(storyRepositoryProvider);
      return repository.getStories();
    });
  }

  /// Imports a new story.
  Future<Story> importStory({
    required String title,
    required String content,
  }) async {
    final repository = ref.read(storyRepositoryProvider);
    final story = await repository.importStory(
      title: title,
      content: content,
    );

    // Refresh list
    ref.invalidateSelf();

    return story;
  }

  /// Generates a story using AI.
  Future<Story> generateStory({
    required String parentId,
    required List<String> keywords,
  }) async {
    final repository = ref.read(storyRepositoryProvider);
    final story = await repository.generateStory(
      parentId: parentId,
      keywords: keywords,
    );

    // Refresh list
    ref.invalidateSelf();

    return story;
  }

  /// Deletes a story.
  Future<void> deleteStory(String id) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.deleteStory(id);

    // Refresh list
    ref.invalidateSelf();
  }

  /// Downloads audio for a story.
  Future<void> downloadAudio(String id) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.downloadStoryAudio(id);

    // Refresh list
    ref.invalidateSelf();
  }

  /// Removes downloaded audio for a story.
  Future<void> removeDownloadedAudio(String id) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.removeDownloadedAudio(id);

    // Refresh list
    ref.invalidateSelf();
  }
}

/// Notifier for single story state and actions.
@riverpod
class StoryDetailNotifier extends _$StoryDetailNotifier {
  @override
  Future<Story?> build(String id) async {
    final repository = ref.watch(storyRepositoryProvider);
    return repository.getStory(id);
  }

  /// Updates the story.
  Future<Story> updateStory({
    String? title,
    String? content,
  }) async {
    final repository = ref.read(storyRepositoryProvider);
    final story = await repository.updateStory(
      id: id,
      title: title,
      content: content,
    );

    state = AsyncValue.data(story);
    return story;
  }

  /// Downloads audio for the story.
  Future<void> downloadAudio() async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.downloadStoryAudio(id);

    // Refresh state
    ref.invalidateSelf();
  }

  /// Removes downloaded audio.
  Future<void> removeDownloadedAudio() async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.removeDownloadedAudio(id);

    // Refresh state
    ref.invalidateSelf();
  }
}
