import 'dart:async';
import 'dart:typed_data';

import 'package:storybuddy/core/network/websocket_client.dart';

/// Remote datasource for interaction feature using WebSocket.
///
/// T037 [US1] Implement interaction remote datasource.
/// Wraps WebSocketClient with domain-specific methods.
abstract class InteractionRemoteDatasource {
  /// Connect to the interaction WebSocket endpoint.
  Future<void> connect({
    required String sessionId,
    required String token,
  });

  /// Disconnect from the WebSocket.
  Future<void> disconnect();

  /// Send audio data to the server.
  void sendAudio(Uint8List audioData);

  /// Notify server that speech has started.
  void notifySpeechStarted();

  /// Notify server that speech has ended.
  void notifySpeechEnded({required int durationMs});

  /// Request to interrupt AI response.
  void interruptAI();

  /// Pause the session.
  void pauseSession();

  /// Resume the session.
  void resumeSession();

  /// End the session.
  void endSession();

  /// Sync story playback position with server.
  void syncPosition({required int positionMs});

  /// Stream of transcription updates (partial and final).
  Stream<TranscriptionUpdate> get transcriptionUpdates;

  /// Stream of AI response updates.
  Stream<AIResponseUpdate> get aiResponseUpdates;

  /// Stream of session control messages.
  Stream<SessionControlMessage> get sessionControlMessages;

  /// Stream of connection state changes.
  Stream<bool> get connectionState;

  /// Stream of audio data from AI responses.
  Stream<Uint8List> get aiAudioStream;

  /// Whether currently connected.
  bool get isConnected;
}

/// Implementation of InteractionRemoteDatasource using WebSocketClient.
class InteractionRemoteDatasourceImpl implements InteractionRemoteDatasource {
  InteractionRemoteDatasourceImpl({
    required WebSocketClient webSocketClient,
  }) : _webSocketClient = webSocketClient;

  final WebSocketClient _webSocketClient;

  final _transcriptionController =
      StreamController<TranscriptionUpdate>.broadcast();
  final _aiResponseController = StreamController<AIResponseUpdate>.broadcast();
  final _sessionControlController =
      StreamController<SessionControlMessage>.broadcast();

  StreamSubscription? _messageSubscription;

  @override
  Future<void> connect({
    required String sessionId,
    required String token,
  }) async {
    await _webSocketClient.connect(
      sessionId: sessionId,
      token: token,
    );

    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = _webSocketClient.messages.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'transcription_progress':
        _transcriptionController.add(TranscriptionUpdate(
          text: message['text'] as String? ?? '',
          isFinal: false,
          confidence: message['confidence'] as double?,
        ),);
        break;

      case 'transcription_final':
        _transcriptionController.add(TranscriptionUpdate(
          text: message['text'] as String? ?? '',
          isFinal: true,
          confidence: message['confidence'] as double?,
        ),);
        break;

      case 'ai_response_started':
        _aiResponseController.add(AIResponseUpdate(
          type: AIResponseType.started,
          text: '',
        ),);
        break;

      case 'ai_response_text':
        _aiResponseController.add(AIResponseUpdate(
          type: AIResponseType.textChunk,
          text: message['text'] as String? ?? '',
        ),);
        break;

      case 'ai_response_completed':
        _aiResponseController.add(AIResponseUpdate(
          type: AIResponseType.completed,
          text: message['fullText'] as String? ?? '',
        ),);
        break;

      case 'resume_story':
        final position = message['resumePosition'] as double?;
        _sessionControlController.add(SessionControlMessage(
          type: SessionControlType.resumeStory,
          resumePositionMs: position != null ? (position * 1000).toInt() : null,
        ),);
        break;

      case 'session_status_changed':
        final status = message['status'] as String?;
        _sessionControlController.add(SessionControlMessage(
          type: SessionControlType.statusChanged,
          status: status,
        ),);
        break;

      case 'session_ended':
        _sessionControlController.add(SessionControlMessage(
          type: SessionControlType.ended,
        ),);
        break;

      case 'error':
        final recoverable = message['recoverable'] as bool? ?? true;
        _sessionControlController.add(SessionControlMessage(
          type: SessionControlType.error,
          errorMessage: message['message'] as String?,
          isRecoverable: recoverable,
        ),);
        break;
    }
  }

  @override
  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    await _webSocketClient.disconnect();
  }

  @override
  void sendAudio(Uint8List audioData) {
    _webSocketClient.sendAudio(audioData);
  }

  @override
  void notifySpeechStarted() {
    _webSocketClient.sendSpeechStarted();
  }

  @override
  void notifySpeechEnded({required int durationMs}) {
    _webSocketClient.sendSpeechEnded(durationMs: durationMs);
  }

  @override
  void interruptAI() {
    _webSocketClient.sendInterruptAi();
  }

  @override
  void pauseSession() {
    _webSocketClient.sendPauseSession();
  }

  @override
  void resumeSession() {
    _webSocketClient.sendResumeSession();
  }

  @override
  void endSession() {
    _webSocketClient.sendEndSession();
  }

  @override
  void syncPosition({required int positionMs}) {
    _webSocketClient.sendSyncPosition(positionMs: positionMs);
  }

  @override
  Stream<TranscriptionUpdate> get transcriptionUpdates =>
      _transcriptionController.stream;

  @override
  Stream<AIResponseUpdate> get aiResponseUpdates =>
      _aiResponseController.stream;

  @override
  Stream<SessionControlMessage> get sessionControlMessages =>
      _sessionControlController.stream;

  @override
  Stream<bool> get connectionState => _webSocketClient.connectionState;

  @override
  Stream<Uint8List> get aiAudioStream => _webSocketClient.binaryMessages;

  @override
  bool get isConnected => _webSocketClient.isConnected;

  /// Dispose resources.
  void dispose() {
    _messageSubscription?.cancel();
    _transcriptionController.close();
    _aiResponseController.close();
    _sessionControlController.close();
  }
}

/// Represents a transcription update from the server.
class TranscriptionUpdate {
  TranscriptionUpdate({
    required this.text,
    required this.isFinal,
    this.confidence,
  });

  final String text;
  final bool isFinal;
  final double? confidence;
}

/// Type of AI response update.
enum AIResponseType {
  started,
  textChunk,
  audioChunk,
  completed,
}

/// Represents an AI response update from the server.
class AIResponseUpdate {
  AIResponseUpdate({
    required this.type,
    required this.text,
    this.audioData,
  });

  final AIResponseType type;
  final String text;
  final Uint8List? audioData;
}

/// Type of session control message.
enum SessionControlType {
  resumeStory,
  statusChanged,
  ended,
  error,
}

/// Represents a session control message from the server.
class SessionControlMessage {
  SessionControlMessage({
    required this.type,
    this.resumePositionMs,
    this.status,
    this.errorMessage,
    this.isRecoverable = true,
  });

  final SessionControlType type;
  final int? resumePositionMs;
  final String? status;
  final String? errorMessage;
  final bool isRecoverable;
}
