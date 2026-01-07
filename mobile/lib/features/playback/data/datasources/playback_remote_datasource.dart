import '../../../../core/network/api_client.dart';

/// Remote data source for playback operations.
abstract class PlaybackRemoteDataSource {
  /// Generates audio for a story using voice cloning.
  /// Returns the URL of the generated audio.
  Future<String> generateAudio({
    required String storyId,
    required String voiceProfileId,
  });

  /// Gets the audio URL for a story.
  Future<String?> getAudioUrl(String storyId);

  /// Checks if audio generation is complete.
  Future<AudioGenerationStatus> getGenerationStatus(String storyId);
}

/// Status of audio generation.
class AudioGenerationStatus {
  AudioGenerationStatus({
    required this.storyId,
    required this.status,
    this.audioUrl,
    this.errorMessage,
    this.progress,
  });

  factory AudioGenerationStatus.fromJson(Map<String, dynamic> json) {
    return AudioGenerationStatus(
      storyId: json['story_id'] as String,
      status: _parseStatus(json['status'] as String),
      audioUrl: json['audio_url'] as String?,
      errorMessage: json['error_message'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }

  final String storyId;
  final GenerationStatus status;
  final String? audioUrl;
  final String? errorMessage;
  final double? progress;

  static GenerationStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return GenerationStatus.pending;
      case 'processing':
        return GenerationStatus.processing;
      case 'completed':
        return GenerationStatus.completed;
      case 'failed':
        return GenerationStatus.failed;
      default:
        return GenerationStatus.pending;
    }
  }
}

/// Status of audio generation on the server.
enum GenerationStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Implementation of [PlaybackRemoteDataSource].
class PlaybackRemoteDataSourceImpl implements PlaybackRemoteDataSource {
  PlaybackRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<String> generateAudio({
    required String storyId,
    required String voiceProfileId,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/stories/$storyId/generate-audio',
      data: {
        'voice_profile_id': voiceProfileId,
      },
    );

    final data = response.data;
    if (data == null) {
      throw Exception('No response data from audio generation');
    }

    // If audio URL is immediately available
    if (data['audio_url'] != null) {
      return data['audio_url'] as String;
    }

    // If generation is async, poll for completion
    final jobId = data['job_id'] as String?;
    if (jobId != null) {
      return _pollForCompletion(storyId);
    }

    throw Exception('Unexpected response from audio generation');
  }

  Future<String> _pollForCompletion(String storyId) async {
    const maxAttempts = 60; // 5 minutes with 5 second intervals
    const pollInterval = Duration(seconds: 5);

    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      final status = await getGenerationStatus(storyId);

      switch (status.status) {
        case GenerationStatus.completed:
          if (status.audioUrl != null) {
            return status.audioUrl!;
          }
          throw Exception('Audio URL not available');

        case GenerationStatus.failed:
          throw Exception(status.errorMessage ?? 'Audio generation failed');

        case GenerationStatus.pending:
        case GenerationStatus.processing:
          // Continue polling
          continue;
      }
    }

    throw Exception('Audio generation timed out');
  }

  @override
  Future<String?> getAudioUrl(String storyId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/stories/$storyId/audio',
    );
    return response.data?['audio_url'] as String?;
  }

  @override
  Future<AudioGenerationStatus> getGenerationStatus(String storyId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/stories/$storyId/audio/status',
    );
    if (response.data == null) {
      throw Exception('No response data from audio status');
    }
    return AudioGenerationStatus.fromJson(response.data!);
  }
}
