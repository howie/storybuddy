import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Audio handler for background playback support.
class StoryAudioHandler extends BaseAudioHandler with SeekHandler {
  StoryAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen(_handlePlayerState);
  }

  final _player = AudioPlayer();

  /// The underlying audio player.
  AudioPlayer get player => _player;

  /// Current playback state.
  PlaybackState get currentState => playbackState.value;

  /// Sets the audio source from a URL.
  Future<void> setUrl(String url) async {
    final duration = await _player.setUrl(url);
    mediaItem.add(
      MediaItem(
        id: url,
        title: 'Story',
        duration: duration,
      ),
    );
  }

  /// Sets the audio source from a local file.
  Future<void> setFilePath(String filePath) async {
    final duration = await _player.setFilePath(filePath);
    mediaItem.add(
      MediaItem(
        id: filePath,
        title: 'Story',
        duration: duration,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    // Not applicable for single story playback
  }

  @override
  Future<void> skipToPrevious() async {
    // Not applicable for single story playback
  }

  /// Stream of the current playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of the buffered position.
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Stream of player state changes.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Current position.
  Duration get position => _player.position;

  /// Total duration.
  Duration? get duration => _player.duration;

  /// Whether the player is currently playing.
  bool get isPlaying => _player.playing;

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _getProcessingState(),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  void _handlePlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      // Story finished playing
      stop();
    }
  }

  AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Disposes the audio player resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Provider for the audio handler.
///
/// This is initialized once and shared across the app.
final audioHandlerProvider = Provider<StoryAudioHandler>((ref) {
  final handler = StoryAudioHandler();

  ref.onDispose(() {
    handler.dispose();
  });

  return handler;
});

/// Flag to track if audio service has been initialized.
bool _audioServiceInitialized = false;

/// Initializes the audio service for background playback.
/// Safe to call multiple times - will only initialize once.
Future<StoryAudioHandler?> initAudioService() async {
  if (_audioServiceInitialized) {
    return null;
  }
  _audioServiceInitialized = true;

  try {
    return await AudioService.init(
      builder: StoryAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.storybuddy.storybuddy.audio',
        androidNotificationChannelName: 'StoryBuddy Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    // AudioService already initialized (can happen in tests)
    return null;
  }
}
