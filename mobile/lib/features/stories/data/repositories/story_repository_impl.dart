import 'package:uuid/uuid.dart';

import '../../../../core/audio/audio_cache_manager.dart';
import '../../../../core/database/enums.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_local_datasource.dart';
import '../datasources/story_remote_datasource.dart';

/// Implementation of [StoryRepository] with offline-first pattern.
class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivityService,
    required this.audioCacheManager,
  });

  final StoryRemoteDataSource remoteDataSource;
  final StoryLocalDataSource localDataSource;
  final ConnectivityService connectivityService;
  final AudioCacheManager audioCacheManager;

  final _uuid = const Uuid();

  @override
  Future<List<Story>> getStories() async {
    // Return local data immediately
    final localStories = await localDataSource.getStories();

    // Refresh from remote in background if online
    if (await connectivityService.isConnected) {
      _refreshStoriesFromRemote();
    }

    return localStories;
  }

  @override
  Future<Story?> getStory(String id) async {
    // Try local first
    final localStory = await localDataSource.getStory(id);

    if (localStory != null) {
      return localStory;
    }

    // Fetch from remote if not found locally and online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.getStory(id);
        final story = remoteModel.toEntity();
        await localDataSource.saveStory(story);
        return story;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  @override
  Future<Story> importStory({
    required String title,
    required String content,
  }) async {
    // Generate local ID
    final id = _uuid.v4();

    // Create story entity with pending sync status
    final story = Story.imported(
      id: id,
      parentId: '', // Will be set by auth context
      title: title,
      content: content,
    );

    // Save locally first (optimistic update)
    await localDataSource.saveStory(story);

    // Sync to remote if online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.importStory(
          title: title,
          content: content,
        );
        final syncedStory = remoteModel.toEntity();
        await localDataSource.saveStory(syncedStory);
        return syncedStory;
      } catch (_) {
        // Keep local version with pending status
        return story;
      }
    }

    return story;
  }

  @override
  Future<Story> generateStory({
    required List<String> keywords,
  }) async {
    // AI generation requires online connection
    if (!await connectivityService.isConnected) {
      throw Exception('網路連線需要才能使用 AI 生成故事');
    }

    final remoteModel = await remoteDataSource.generateStory(keywords: keywords);
    final story = remoteModel.toEntity();

    // Cache locally
    await localDataSource.saveStory(story);

    return story;
  }

  @override
  Future<Story> updateStory({
    required String id,
    String? title,
    String? content,
  }) async {
    // Get existing story
    final existing = await localDataSource.getStory(id);
    if (existing == null) {
      throw Exception('Story not found');
    }

    // Update locally first
    final updated = existing.copyWith(
      title: title ?? existing.title,
      content: content ?? existing.content,
      wordCount: content?.length ?? existing.wordCount,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
    await localDataSource.updateStory(updated);

    // Sync to remote if online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.updateStory(
          id: id,
          title: title,
          content: content,
        );
        final syncedStory = remoteModel.toEntity(
          localAudioPath: updated.localAudioPath,
          isDownloaded: updated.isDownloaded,
        );
        await localDataSource.saveStory(syncedStory);
        return syncedStory;
      } catch (_) {
        // Keep local version with pending status
        return updated;
      }
    }

    return updated;
  }

  @override
  Future<void> deleteStory(String id) async {
    // Remove downloaded audio if exists
    final story = await localDataSource.getStory(id);
    if (story?.localAudioPath != null) {
      await audioCacheManager.deleteCachedAudio(story!.localAudioPath!);
    }

    // Delete locally
    await localDataSource.deleteStory(id);

    // Delete from remote if online
    if (await connectivityService.isConnected) {
      try {
        await remoteDataSource.deleteStory(id);
      } catch (_) {
        // Ignore remote delete errors
      }
    }
  }

  @override
  Future<void> downloadStoryAudio(String id) async {
    final story = await localDataSource.getStory(id);
    if (story == null || story.audioUrl == null) {
      throw Exception('Story or audio URL not found');
    }

    // Download and cache audio with encryption
    final localPath = await audioCacheManager.cacheAudioFromUrl(
      story.audioUrl!,
      storyId: id,
    );

    // Update local database
    await localDataSource.updateLocalAudioPath(id, localPath, true);
  }

  @override
  Future<void> removeDownloadedAudio(String id) async {
    final story = await localDataSource.getStory(id);
    if (story?.localAudioPath != null) {
      await audioCacheManager.deleteCachedAudio(story!.localAudioPath!);
    }

    await localDataSource.updateLocalAudioPath(id, null, false);
  }

  @override
  Future<void> syncStory(String id) async {
    if (!await connectivityService.isConnected) {
      return;
    }

    final story = await localDataSource.getStory(id);
    if (story == null || story.syncStatus != SyncStatus.pendingSync) {
      return;
    }

    try {
      final remoteModel = await remoteDataSource.updateStory(
        id: id,
        title: story.title,
        content: story.content,
      );
      final syncedStory = remoteModel.toEntity(
        localAudioPath: story.localAudioPath,
        isDownloaded: story.isDownloaded,
      );
      await localDataSource.saveStory(syncedStory);
    } catch (_) {
      // Keep pending status on failure
    }
  }

  @override
  Future<void> syncAllPendingStories() async {
    if (!await connectivityService.isConnected) {
      return;
    }

    final pendingStories = await localDataSource.getPendingStories();
    for (final story in pendingStories) {
      await syncStory(story.id);
    }
  }

  @override
  Stream<List<Story>> watchStories() {
    return localDataSource.watchStories();
  }

  @override
  Stream<Story?> watchStory(String id) {
    return localDataSource.watchStory(id);
  }

  /// Refreshes stories from remote in background.
  Future<void> _refreshStoriesFromRemote() async {
    try {
      final remoteModels = await remoteDataSource.getStories();
      final stories = remoteModels.map((m) => m.toEntity()).toList();

      // Preserve local audio paths when updating
      for (final story in stories) {
        final existing = await localDataSource.getStory(story.id);
        if (existing != null) {
          final merged = story.copyWith(
            localAudioPath: existing.localAudioPath,
            isDownloaded: existing.isDownloaded,
          );
          await localDataSource.saveStory(merged);
        } else {
          await localDataSource.saveStory(story);
        }
      }
    } catch (_) {
      // Ignore refresh errors
    }
  }
}
