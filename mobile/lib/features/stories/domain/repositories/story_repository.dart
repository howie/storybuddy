import '../entities/story.dart';

/// Repository interface for Story operations.
abstract class StoryRepository {
  /// Gets all stories for the current parent.
  Future<List<Story>> getStories();

  /// Gets a story by ID.
  Future<Story?> getStory(String id);

  /// Creates a new story from imported text.
  Future<Story> importStory({
    required String title,
    required String content,
  });

  /// Creates a new story from AI generation.
  Future<Story> generateStory({
    required String parentId,
    required List<String> keywords,
  });

  /// Updates an existing story.
  Future<Story> updateStory({
    required String id,
    String? title,
    String? content,
  });

  /// Deletes a story.
  Future<void> deleteStory(String id);

  /// Downloads story audio for offline playback.
  Future<void> downloadStoryAudio(String id);

  /// Removes downloaded audio to free space.
  Future<void> removeDownloadedAudio(String id);

  /// Syncs a story with the server.
  Future<void> syncStory(String id);

  /// Syncs all pending stories.
  Future<void> syncAllPendingStories();

  /// Stream of stories for reactive UI updates.
  Stream<List<Story>> watchStories();

  /// Stream of a single story for reactive UI updates.
  Stream<Story?> watchStory(String id);
}
