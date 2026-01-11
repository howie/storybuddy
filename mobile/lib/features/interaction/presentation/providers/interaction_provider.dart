import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:storybuddy/core/audio/audio_streamer.dart';
import 'package:storybuddy/core/audio/vad_service.dart';
import 'package:storybuddy/core/monitoring/battery_monitor.dart';
import 'package:storybuddy/core/network/websocket_client.dart';
import 'package:storybuddy/features/interaction/data/services/noise_calibration_service.dart';

part 'interaction_provider.freezed.dart';

/// Interaction session mode.
enum SessionMode {
  interactive,
  passive,
}

/// Session status values.
enum SessionStatus {
  calibrating,
  active,
  paused,
  completed,
  error,
}

/// State for the interaction feature.
///
/// T041 [US1] Implement interaction provider.
/// T094 [US5] Add calibration state fields.
/// T097 [P] Add connection state fields.
@freezed
class InteractionState with _$InteractionState {
  const factory InteractionState({
    String? sessionId,
    String? storyId,
    @Default(SessionMode.passive) SessionMode mode,
    @Default(SessionStatus.calibrating) SessionStatus status,
    @Default(false) bool isLoading,
    @Default(false) bool isListening,
    @Default(false) bool isChildSpeaking,
    @Default(false) bool isAIResponding,
    @Default(false) bool isWaitingForAIResponse,
    @Default(false) bool isPlaying,
    @Default(false) bool wasPlayingBeforeCalibration,
    @Default(0) int storyPositionMs,
    @Default('') String currentTranscript,
    @Default('') String currentAIResponseText,
    String? errorMessage,
    @Default(false) bool isRecoverableError,
    // T094 [US5] Calibration fields
    @Default(0.0) double calibrationProgress,
    double? noiseFloorDb,
    bool? isQuietEnvironment,
    // T097 [P] Connection state fields
    @Default(false) bool isConnected,
    @Default(false) bool isReconnecting,
    @Default(0) int reconnectAttempts,
    @Default(5) int maxReconnectAttempts,
    // T099 [P] Battery monitoring fields
    int? batteryLevel,
    @Default(false) bool isBatteryLow,
    @Default(false) bool isBatteryCharging,
    String? batteryUsageSummary,
  }) = _InteractionState;

  factory InteractionState.initial() => const InteractionState();
}

/// Notifier for managing interaction state.
///
/// Coordinates between:
/// - WebSocket client for server communication
/// - Audio streamer for microphone capture
/// - VAD for speech detection
/// T094 [US5] Add calibration service integration.
/// T099 [P] Add battery monitoring integration.
class InteractionNotifier extends StateNotifier<InteractionState> {
  InteractionNotifier({
    WebSocketClient? webSocketClient,
    AudioStreamer? audioStreamer,
    AudioPlayer? audioPlayer,
    NoiseCalibrationService? calibrationService,
    BatteryMonitor? batteryMonitor,
  })  : _webSocketClient = webSocketClient,
        _audioStreamer = audioStreamer,
        _audioPlayer = audioPlayer ?? AudioPlayer(),
        _calibrationService = calibrationService ?? NoiseCalibrationService(),
        _batteryMonitor = batteryMonitor ?? BatteryMonitor(),
        super(InteractionState.initial()) {
    // Initialize battery monitor on construction
    _initBatteryMonitor();
  }

  final WebSocketClient? _webSocketClient;
  final AudioStreamer? _audioStreamer;
  final AudioPlayer _audioPlayer;
  final NoiseCalibrationService _calibrationService;
  final BatteryMonitor _batteryMonitor;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _playerSubscription;
  StreamSubscription? _vadEventSubscription;
  StreamSubscription? _calibrationSubscription;

  /// Start an interactive session.
  /// T094 [US5] Integrate calibration flow.
  /// T099 [P] Start battery tracking.
  Future<void> startSession({
    required String storyId,
    required String token,
  }) async {
    state = state.copyWith(
      isLoading: true,
      storyId: storyId,
    );

    try {
      // T099 [P] Start battery tracking for session
      await _startBatteryTracking();

      // Initialize audio streamer
      await _audioStreamer?.initialize();

      // Connect WebSocket
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _webSocketClient?.connect(
        sessionId: sessionId,
        token: token,
      );

      state = state.copyWith(
        sessionId: sessionId,
        isLoading: false,
        status: SessionStatus.calibrating,
        mode: SessionMode.interactive,
        calibrationProgress: 0,
      );

      // Subscribe to WebSocket messages
      _subscribeToMessages();

      // T094 [US5] Start calibration flow
      await _startCalibrationFlow();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: SessionStatus.error,
        errorMessage: e.toString(),
        isRecoverableError: true,
      );
    }
  }

  /// T094 [US5] Start the calibration flow.
  Future<void> _startCalibrationFlow() async {
    // Tell server we're starting calibration
    _webSocketClient?.send({'type': 'start_calibration'});

    // Start audio recording for calibration
    await _audioStreamer?.startRecording();

    // Start calibration service
    _calibrationService.startCalibration();

    // Subscribe to raw audio for calibration
    _calibrationSubscription?.cancel();
    _calibrationSubscription = _audioStreamer?.rawAudioStream.listen((frame) {
      if (state.status != SessionStatus.calibrating) return;

      final needsMore = _calibrationService.addFrame(frame);
      state = state.copyWith(
        calibrationProgress: _calibrationService.progress,
      );

      if (!needsMore) {
        _finishCalibration();
      }
    });

    // Auto-complete after timeout (2.5 seconds)
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (state.status == SessionStatus.calibrating) {
        _finishCalibration();
      }
    });
  }

  /// T094 [US5] Finish calibration and activate session.
  Future<void> _finishCalibration() async {
    await _calibrationSubscription?.cancel();
    _calibrationSubscription = null;

    try {
      final result = _calibrationService.completeCalibration();

      // Calibrate the VAD service with noise floor
      _audioStreamer?.calibrateVAD(result.noiseFloorDb);

      state = state.copyWith(
        noiseFloorDb: result.noiseFloorDb,
        isQuietEnvironment: result.isQuietEnvironment,
        calibrationProgress: 1,
      );

      // Tell server calibration is complete
      _webSocketClient?.send({'type': 'complete_calibration'});

      // Auto-proceed after brief delay to show result
      await Future.delayed(const Duration(milliseconds: 500));
      await completeCalibration();
    } catch (e) {
      // Calibration failed, use defaults and continue
      await completeCalibration();
    }
  }

  /// Complete noise calibration and activate session.
  /// T094 [US5] Subscribe to VAD events after calibration.
  Future<void> completeCalibration() async {
    if (state.status != SessionStatus.calibrating) return;

    state = state.copyWith(
      status: SessionStatus.active,
      isListening: true,
    );

    // Resume playback if it was playing before calibration
    if (state.wasPlayingBeforeCalibration) {
      state = state.copyWith(
        isPlaying: true,
        wasPlayingBeforeCalibration: false,
      );
    }

    // Audio streaming already started during calibration, just subscribe to events
    _subscribeToAudio();
    _subscribeToVADEvents();

    // Notify server we're ready
    _webSocketClient?.sendStartListening();
  }

  /// T094 [US5] Subscribe to VAD events for speech detection.
  void _subscribeToVADEvents() {
    _vadEventSubscription?.cancel();
    _vadEventSubscription = _audioStreamer?.vadEventStream.listen((event) {
      if (!state.isListening) return;

      switch (event.type) {
        case VADEventType.speechStarted:
          onSpeechStarted();
          break;
        case VADEventType.speechEnded:
          onSpeechEnded(event.durationMs ?? 0);
          break;
      }
    });
  }

  /// Switch between interactive and passive modes (FR-013).
  Future<void> switchMode(SessionMode newMode) async {
    if (state.mode == newMode) return;

    final wasPlaying = state.isPlaying;

    if (state.mode == SessionMode.interactive) {
      // Interactive → Passive: cleanup
      await _cleanupInteractiveMode();
    }

    state = state.copyWith(
      mode: newMode,
      isChildSpeaking: false,
      isAIResponding: false,
      currentAIResponseText: '',
      currentTranscript: '',
    );

    if (newMode == SessionMode.interactive) {
      // Passive → Interactive: need calibration
      state = state.copyWith(
        status: SessionStatus.calibrating,
        isPlaying: false,
        wasPlayingBeforeCalibration: wasPlaying,
      );
    }
  }

  Future<void> _cleanupInteractiveMode() async {
    // Stop audio streaming
    await _audioStreamer?.stopRecording();
    await _audioSubscription?.cancel();
    await _vadEventSubscription?.cancel();
    await _calibrationSubscription?.cancel();
    _calibrationService.reset();

    // Send end_session to server
    try {
      _webSocketClient?.sendEndSession();
      final disconnectFuture = _webSocketClient?.disconnect();
      if (disconnectFuture != null) {
        await disconnectFuture;
      }
    } catch (_) {
      // Ignore disconnect errors
    }

    state = state.copyWith(
      isListening: false,
      calibrationProgress: 0,
      noiseFloorDb: null,
    );
  }

  /// Pause the session.
  Future<void> pause() async {
    if (state.status != SessionStatus.active) return;

    _webSocketClient?.sendPauseSession();
    _audioStreamer?.pauseRecording();

    state = state.copyWith(
      status: SessionStatus.paused,
      isPlaying: false,
    );
  }

  /// Resume the session.
  Future<void> resume() async {
    if (state.status != SessionStatus.paused) return;

    _webSocketClient?.sendResumeSession();
    _audioStreamer?.resumeRecording();

    state = state.copyWith(
      status: SessionStatus.active,
      isPlaying: true,
    );
  }

  /// End the session.
  /// T099 [P] End battery tracking.
  Future<void> endSession() async {
    await _cleanupInteractiveMode();

    // T099 [P] End battery tracking and get stats
    await _endBatteryTracking();

    state = state.copyWith(
      status: SessionStatus.completed,
    );
  }

  /// Retry after a recoverable error.
  Future<void> retry() async {
    if (state.storyId == null) return;

    state = InteractionState.initial();

    // Would need to restart with stored credentials
  }

  /// Update story playback position.
  void updatePosition(int positionMs) {
    state = state.copyWith(storyPositionMs: positionMs);
  }

  /// T097 [P] Subscribe to WebSocket messages and connection state.
  void _subscribeToMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = _webSocketClient?.messages.listen(_handleMessage);

    _connectionSubscription?.cancel();
    _connectionSubscription =
        _webSocketClient?.connectionState.listen(_handleConnectionStateChange);

    // Subscribe to error stream
    _webSocketClient?.errors.listen((errorMessage) {
      // Update state with error info but don't change status if reconnecting
      if (!(_webSocketClient?.isReconnecting ?? false)) {
        state = state.copyWith(
          errorMessage: errorMessage,
          isRecoverableError: true,
        );
      }
    });
  }

  /// T097 [P] Handle connection state changes.
  void _handleConnectionStateChange(bool connected) {
    final isReconnecting = _webSocketClient?.isReconnecting ?? false;
    final reconnectAttempts = _webSocketClient?.reconnectAttempts ?? 0;

    state = state.copyWith(
      isConnected: connected,
      isReconnecting: isReconnecting,
      reconnectAttempts: reconnectAttempts,
    );

    if (connected) {
      // Connection restored
      if (state.errorMessage?.contains('連線') ?? false) {
        state = state.copyWith(
          errorMessage: null,
        );
      }
    } else if (!isReconnecting && state.status == SessionStatus.active) {
      // Disconnected and not reconnecting - show error
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: '連線已中斷',
        isRecoverableError: true,
      );
    }
  }

  /// T097 [P] Manually trigger reconnection.
  Future<void> reconnect() async {
    if (_webSocketClient == null) return;

    state = state.copyWith(
      errorMessage: null,
      isReconnecting: true,
    );

    try {
      await _webSocketClient!.reconnect();
      state = state.copyWith(
        status: SessionStatus.active,
        isConnected: true,
        isReconnecting: false,
        reconnectAttempts: 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: '重新連線失敗: $e',
        isRecoverableError: true,
        isReconnecting: false,
      );
    }
  }

  /// T097 [P] Dismiss current error message.
  void dismissError() {
    state = state.copyWith(
      errorMessage: null,
    );
  }

  /// T099 [P] Initialize battery monitor.
  Future<void> _initBatteryMonitor() async {
    await _batteryMonitor.initialize();
    _updateBatteryState();
  }

  /// T099 [P] Update battery state in the UI.
  void _updateBatteryState() {
    state = state.copyWith(
      batteryLevel: _batteryMonitor.currentLevel,
      isBatteryLow: _batteryMonitor.isLow,
      isBatteryCharging: _batteryMonitor.isCharging,
    );
  }

  /// T099 [P] Start battery session tracking.
  Future<void> _startBatteryTracking() async {
    await _batteryMonitor.startSession();
    _updateBatteryState();
  }

  /// T099 [P] End battery session tracking and get stats.
  Future<void> _endBatteryTracking() async {
    final stats = await _batteryMonitor.endSession();
    if (stats != null) {
      state = state.copyWith(
        batteryUsageSummary: stats.summary,
      );
    }
    _updateBatteryState();
  }

  /// T099 [P] Get estimated remaining interactive time.
  Duration? get estimatedRemainingTime =>
      _batteryMonitor.estimateRemainingTime();

  /// T099 [P] Check if battery is critically low.
  bool get isBatteryCritical => _batteryMonitor.isCriticallyLow;

  void _subscribeToAudio() {
    _audioSubscription?.cancel();
    _audioSubscription = _audioStreamer?.audioStream.listen((audioData) {
      if (state.isListening && (_webSocketClient?.isConnected ?? false)) {
        _webSocketClient?.sendAudio(audioData);
      }
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'connection_established':
        // Connection successful
        break;

      case 'transcription_progress':
        state = state.copyWith(
          currentTranscript: message['text'] as String? ?? '',
        );
        break;

      case 'transcription_final':
        state = state.copyWith(
          currentTranscript: message['text'] as String? ?? '',
          isChildSpeaking: false,
          isWaitingForAIResponse: true,
        );
        break;

      case 'ai_processing_started':
        // T055 [US2] AI is processing the child's input
        state = state.copyWith(
          isWaitingForAIResponse: true,
          isChildSpeaking: false,
        );
        break;

      case 'ai_response_started':
        state = state.copyWith(
          isAIResponding: true,
          isWaitingForAIResponse: false,
          currentAIResponseText: '',
        );
        break;

      case 'ai_response':
        // T055 [US2] Full AI response received
        state = state.copyWith(
          currentAIResponseText: message['text'] as String? ?? '',
          isAIResponding: true,
          isWaitingForAIResponse: false,
        );
        break;

      case 'ai_response_text':
        // Legacy/streaming AI response text
        state = state.copyWith(
          currentAIResponseText: message['text'] as String? ?? '',
        );
        break;

      case 'ai_response_completed':
        state = state.copyWith(
          isAIResponding: false,
        );
        break;

      case 'ai_response_audio':
        // T056 [US2] AI audio received - handle audio playback
        final audioUrl = message['audioUrl'] as String?;
        final audioData = message['audioData'] as String?; // Base64 encoded
        if (audioUrl != null) {
          _playAudioFromUrl(audioUrl);
        } else if (audioData != null) {
          _playAudioFromBase64(audioData);
        }
        break;

      case 'resume_story':
        final position = message['resumePosition'] as double?;
        if (position != null) {
          state = state.copyWith(
            storyPositionMs: (position * 1000).toInt(),
            isPlaying: true,
          );
        }
        break;

      case 'session_status_changed':
        final status = message['status'] as String?;
        if (status == 'paused') {
          state = state.copyWith(status: SessionStatus.paused);
        } else if (status == 'active') {
          state = state.copyWith(status: SessionStatus.active);
        }
        break;

      case 'session_ended':
        state = state.copyWith(
          status: SessionStatus.completed,
        );
        break;

      case 'error':
        final recoverable = message['recoverable'] as bool? ?? true;
        state = state.copyWith(
          status: SessionStatus.error,
          errorMessage: message['message'] as String? ?? '發生錯誤',
          isRecoverableError: recoverable,
        );
        break;
    }
  }

  /// Handle speech started event from local VAD.
  void onSpeechStarted() {
    if (!state.isListening) return;

    state = state.copyWith(
      isChildSpeaking: true,
      isPlaying: false, // Pause story while child speaks
    );

    _webSocketClient?.sendSpeechStarted();
  }

  /// Handle speech ended event from local VAD.
  void onSpeechEnded(int durationMs) {
    if (!state.isChildSpeaking) return;

    _webSocketClient?.sendSpeechEnded(durationMs: durationMs);
  }

  /// Handle AI interruption (child started speaking during AI response).
  void interruptAI() {
    if (!state.isAIResponding) return;

    _webSocketClient?.sendInterruptAi();
    _stopAudioPlayback();
    state = state.copyWith(
      isAIResponding: false,
    );
  }

  /// Play AI response audio from URL (T056 [US2]).
  Future<void> _playAudioFromUrl(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      _subscribeToPlayerState();
    } catch (e) {
      // Log error but don't crash - audio playback is not critical
      state = state.copyWith(
        errorMessage: '音訊播放失敗: $e',
        isRecoverableError: true,
      );
    }
  }

  /// Play AI response audio from Base64 encoded data (T056 [US2]).
  Future<void> _playAudioFromBase64(String base64Data) async {
    try {
      // Decode Base64 to bytes
      final bytes = base64Decode(base64Data);

      // Use a custom audio source for bytes
      await _audioPlayer.setAudioSource(
        _BytesAudioSource(bytes),
      );
      await _audioPlayer.play();
      _subscribeToPlayerState();
    } catch (e) {
      // Log error but don't crash - audio playback is not critical
      state = state.copyWith(
        errorMessage: '音訊播放失敗: $e',
        isRecoverableError: true,
      );
    }
  }

  /// Subscribe to audio player state changes.
  void _subscribeToPlayerState() {
    _playerSubscription?.cancel();
    _playerSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // AI audio playback completed
        state = state.copyWith(
          isAIResponding: false,
        );
      }
    });
  }

  /// Stop AI audio playback.
  Future<void> _stopAudioPlayback() async {
    try {
      await _audioPlayer.stop();
      await _playerSubscription?.cancel();
    } catch (_) {
      // Ignore stop errors
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _audioSubscription?.cancel();
    _connectionSubscription?.cancel();
    _playerSubscription?.cancel();
    _vadEventSubscription?.cancel();
    _calibrationSubscription?.cancel();
    _audioStreamer?.dispose();
    _webSocketClient?.dispose();
    _audioPlayer.dispose();
    _calibrationService.dispose();
    _batteryMonitor.dispose(); // T099 [P]
    super.dispose();
  }
}

/// Provider for interaction state.
final interactionProvider =
    StateNotifierProvider<InteractionNotifier, InteractionState>((ref) {
  return InteractionNotifier(
    webSocketClient: WebSocketClient(
      baseUrl: 'wss://api.storybuddy.app', // Configure from environment
    ),
    audioStreamer: AudioStreamer(),
  );
});

/// Custom audio source for playing audio from bytes (T056 [US2]).
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);

  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;

    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
