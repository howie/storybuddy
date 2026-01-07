import 'dart:async';

import '../../../../core/network/connectivity_service.dart';
import '../../../stories/data/datasources/story_local_datasource.dart';
import '../../domain/entities/story_playback.dart';
import '../../domain/repositories/playback_repository.dart';
import '../datasources/playback_local_datasource.dart';
import '../datasources/playback_remote_datasource.dart';

/// Implementation of [PlaybackRepository].
class PlaybackRepositoryImpl implements PlaybackRepository {
  PlaybackRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.storyLocalDataSource,
    required this.connectivityService,
  });

  final PlaybackRemoteDataSource remoteDataSource;
  final PlaybackLocalDataSource localDataSource;
  final StoryLocalDataSource storyLocalDataSource;
  final ConnectivityService connectivityService;

  String? _currentStoryId;
  String? _currentStoryTitle;

  final _playbackStateController = StreamController<StoryPlayback>.broadcast();
  final _downloadProgressControllers =
      <String, StreamController<AudioDownloadProgress>>{};

  @override
  Future<String> generateAudio({
    required String storyId,
    required String voiceProfileId,
  }) async {
    if (!await connectivityService.isConnected) {
      throw Exception('需要網路連線才能生成語音');
    }

    final audioUrl = await remoteDataSource.generateAudio(
      storyId: storyId,
      voiceProfileId: voiceProfileId,
    );

    // Update story with audio URL
    final story = await storyLocalDataSource.getStory(storyId);
    if (story != null) {
      await storyLocalDataSource.saveStory(
        story.copyWith(audioUrl: audioUrl),
      );
    }

    return audioUrl;
  }

  @override
  Future<void> playStory(String storyId) async {
    // Get story info
    final story = await storyLocalDataSource.getStory(storyId);
    if (story == null) {
      throw Exception('找不到故事');
    }

    _currentStoryId = storyId;
    _currentStoryTitle = story.title;

    bool isOffline = false;

    // Try local cache first
    final localPath = await localDataSource.getLocalAudioPath(storyId);
    if (localPath != null) {
      // Audio available offline
      isOffline = true;
    } else if (story.audioUrl != null) {
      // Stream from remote
      if (!await connectivityService.isConnected) {
        throw Exception('沒有網路且無離線音訊');
      }
      // Audio available from URL
    } else {
      throw Exception('此故事沒有可播放的語音');
    }

    // Emit initial state
    _playbackStateController.add(
      StoryPlayback(
        storyId: storyId,
        storyTitle: story.title,
        state: PlaybackState.loading,
        position: Duration.zero,
        duration: Duration(minutes: story.estimatedDurationMinutes ?? 5),
        bufferedPosition: Duration.zero,
        speed: 1.0,
        isOffline: isOffline,
      ),
    );

    // Start playback - actual audio implementation would go here
    _playbackStateController.add(
      StoryPlayback(
        storyId: storyId,
        storyTitle: story.title,
        state: PlaybackState.playing,
        position: Duration.zero,
        duration: Duration(minutes: story.estimatedDurationMinutes ?? 5),
        bufferedPosition: Duration.zero,
        speed: 1.0,
        isOffline: isOffline,
      ),
    );
  }

  @override
  Future<void> pause() async {
    if (_currentStoryId == null) return;

    _playbackStateController.add(
      StoryPlayback(
        storyId: _currentStoryId!,
        storyTitle: _currentStoryTitle ?? '',
        state: PlaybackState.paused,
        position: Duration.zero,
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> resume() async {
    if (_currentStoryId == null) return;

    _playbackStateController.add(
      StoryPlayback(
        storyId: _currentStoryId!,
        storyTitle: _currentStoryTitle ?? '',
        state: PlaybackState.playing,
        position: Duration.zero,
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> seekTo(Duration position) async {
    // Seek implementation would go here
  }

  @override
  Future<void> stop() async {
    if (_currentStoryId != null) {
      _playbackStateController.add(
        StoryPlayback(
          storyId: _currentStoryId!,
          storyTitle: _currentStoryTitle ?? '',
          state: PlaybackState.idle,
          position: Duration.zero,
          duration: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
        ),
      );
    }
    _currentStoryId = null;
    _currentStoryTitle = null;
  }

  @override
  Future<void> setSpeed(double speed) async {
    // Speed implementation would go here
  }

  @override
  Future<void> downloadAudio(String storyId) async {
    final story = await storyLocalDataSource.getStory(storyId);
    if (story?.audioUrl == null) {
      throw Exception('此故事沒有可下載的語音');
    }

    if (!await connectivityService.isConnected) {
      throw Exception('需要網路連線才能下載');
    }

    // Create progress controller
    final controller = StreamController<AudioDownloadProgress>.broadcast();
    _downloadProgressControllers[storyId] = controller;

    try {
      controller.add(AudioDownloadProgress(storyId: storyId, progress: 0.0));

      await localDataSource.cacheAudio(storyId, story!.audioUrl!);

      controller.add(AudioDownloadProgress(
        storyId: storyId,
        progress: 1.0,
        isComplete: true,
      ));
    } catch (e) {
      controller.add(AudioDownloadProgress(
        storyId: storyId,
        errorMessage: e.toString(),
      ));
      rethrow;
    } finally {
      await controller.close();
      _downloadProgressControllers.remove(storyId);
    }
  }

  @override
  Future<void> cancelDownload(String storyId) async {
    final controller = _downloadProgressControllers[storyId];
    if (controller != null) {
      await controller.close();
      _downloadProgressControllers.remove(storyId);
    }
  }

  @override
  Stream<StoryPlayback> get playbackState => _playbackStateController.stream;

  @override
  Stream<AudioDownloadProgress> watchDownloadProgress(String storyId) {
    return _downloadProgressControllers[storyId]?.stream ??
        Stream.value(AudioDownloadProgress(storyId: storyId));
  }

  @override
  String? get currentStoryId => _currentStoryId;

  @override
  Future<void> dispose() async {
    await _playbackStateController.close();
    for (final controller in _downloadProgressControllers.values) {
      await controller.close();
    }
  }
}
