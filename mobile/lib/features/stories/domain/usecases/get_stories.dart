import '../entities/story.dart';
import '../repositories/story_repository.dart';

/// Use case for getting all stories.
class GetStoriesUseCase {
  GetStoriesUseCase({required this.repository});

  final StoryRepository repository;

  /// Executes the use case.
  Future<List<Story>> call() async {
    return repository.getStories();
  }

  /// Returns a stream of stories for reactive updates.
  Stream<List<Story>> watch() {
    return repository.watchStories();
  }
}

/// Use case for getting a single story.
class GetStoryUseCase {
  GetStoryUseCase({required this.repository});

  final StoryRepository repository;

  /// Executes the use case.
  Future<Story?> call(String id) async {
    return repository.getStory(id);
  }

  /// Returns a stream of the story for reactive updates.
  Stream<Story?> watch(String id) {
    return repository.watchStory(id);
  }
}
