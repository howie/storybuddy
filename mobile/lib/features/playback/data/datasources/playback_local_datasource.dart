import 'dart:io';

import '../../../../core/audio/audio_cache_manager.dart';
import '../../../stories/data/datasources/story_local_datasource.dart';

/// Local data source for playback operations (audio caching).
abstract class PlaybackLocalDataSource {
  /// Gets the local audio path for a story.
  Future<String?> getLocalAudioPath(String storyId);

  /// Checks if audio is cached locally.
  Future<bool> isAudioCached(String storyId);

  /// Caches audio from a URL.
  Future<String> cacheAudio(String storyId, String audioUrl);

  /// Removes cached audio.
  Future<void> removeCachedAudio(String storyId);

  /// Gets decrypted audio for playback.
  Future<String> getDecryptedAudioPath(String storyId);
}

/// Implementation of [PlaybackLocalDataSource].
class PlaybackLocalDataSourceImpl implements PlaybackLocalDataSource {
  PlaybackLocalDataSourceImpl({
    required this.audioCacheManager,
    required this.storyLocalDataSource,
  });

  final AudioCacheManager audioCacheManager;
  final StoryLocalDataSource storyLocalDataSource;

  @override
  Future<String?> getLocalAudioPath(String storyId) async {
    final story = await storyLocalDataSource.getStory(storyId);
    return story?.localAudioPath;
  }

  @override
  Future<bool> isAudioCached(String storyId) async {
    final path = await getLocalAudioPath(storyId);
    if (path == null) return false;

    final file = File(path);
    return file.exists();
  }

  @override
  Future<String> cacheAudio(String storyId, String audioUrl) async {
    // Download and cache with encryption
    final localPath = await audioCacheManager.cacheAudioFromUrl(
      audioUrl,
      storyId: storyId,
    );

    // Update story record
    await storyLocalDataSource.updateLocalAudioPath(
      storyId,
      localPath,
      true,
    );

    return localPath;
  }

  @override
  Future<void> removeCachedAudio(String storyId) async {
    final path = await getLocalAudioPath(storyId);
    if (path != null) {
      await audioCacheManager.deleteCachedAudio(path);
    }

    // Update story record
    await storyLocalDataSource.updateLocalAudioPath(
      storyId,
      null,
      false,
    );
  }

  @override
  Future<String> getDecryptedAudioPath(String storyId) async {
    final encryptedPath = await getLocalAudioPath(storyId);
    if (encryptedPath == null) {
      throw Exception('No cached audio found');
    }

    // Decrypt to temporary file for playback
    final decryptedPath = await audioCacheManager.getDecryptedTempFile(encryptedPath);
    if (decryptedPath == null) {
      throw Exception('Failed to decrypt audio file');
    }
    return decryptedPath;
  }
}
