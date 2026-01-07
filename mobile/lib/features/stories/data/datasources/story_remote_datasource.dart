import '../../../../core/network/api_client.dart';
import '../models/story_model.dart';

/// Remote data source for Story operations.
abstract class StoryRemoteDataSource {
  /// Fetches all stories for the current parent.
  Future<List<StoryModel>> getStories();

  /// Fetches a single story by ID.
  Future<StoryModel> getStory(String id);

  /// Creates a new story from imported text.
  Future<StoryModel> importStory({
    required String title,
    required String content,
  });

  /// Creates a new story using AI generation.
  Future<StoryModel> generateStory({
    required List<String> keywords,
  });

  /// Updates an existing story.
  Future<StoryModel> updateStory({
    required String id,
    String? title,
    String? content,
  });

  /// Deletes a story.
  Future<void> deleteStory(String id);

  /// Downloads audio file for a story.
  Future<String> getStoryAudioUrl(String id);
}

/// Implementation of [StoryRemoteDataSource].
class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  StoryRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<StoryModel>> getStories() async {
    final response = await apiClient.get<List<dynamic>>('/stories');
    if (response.data == null) return [];
    return response.data!
        .map((json) => StoryModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StoryModel> getStory(String id) async {
    final response = await apiClient.get<Map<String, dynamic>>('/stories/$id');
    if (response.data == null) {
      throw Exception('No response data from get story');
    }
    return StoryModel.fromJson(response.data!);
  }

  @override
  Future<StoryModel> importStory({
    required String title,
    required String content,
  }) async {
    final request = ImportStoryRequest(title: title, content: content);
    final response = await apiClient.post<Map<String, dynamic>>(
      '/stories/import',
      data: request.toJson(),
    );
    if (response.data == null) {
      throw Exception('No response data from import story');
    }
    return StoryModel.fromJson(response.data!);
  }

  @override
  Future<StoryModel> generateStory({
    required List<String> keywords,
  }) async {
    final request = GenerateStoryRequest(keywords: keywords);
    final response = await apiClient.post<Map<String, dynamic>>(
      '/stories/generate',
      data: request.toJson(),
    );
    if (response.data == null) {
      throw Exception('No response data from generate story');
    }
    return StoryModel.fromJson(response.data!);
  }

  @override
  Future<StoryModel> updateStory({
    required String id,
    String? title,
    String? content,
  }) async {
    final request = UpdateStoryRequest(title: title, content: content);
    final response = await apiClient.patch<Map<String, dynamic>>(
      '/stories/$id',
      data: request.toJson(),
    );
    if (response.data == null) {
      throw Exception('No response data from update story');
    }
    return StoryModel.fromJson(response.data!);
  }

  @override
  Future<void> deleteStory(String id) async {
    await apiClient.delete<void>('/stories/$id');
  }

  @override
  Future<String> getStoryAudioUrl(String id) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/stories/$id/audio',
    );
    if (response.data == null) {
      throw Exception('No response data from get audio url');
    }
    return response.data!['audio_url'] as String;
  }
}
