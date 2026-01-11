import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket message types for interaction protocol.
///
/// T055 [US2] Extended for AI response messages.
class WebSocketMessageType {
  // Client → Server
  static const String startListening = 'start_listening';
  static const String stopListening = 'stop_listening';
  static const String speechStarted = 'speech_started';
  static const String speechEnded = 'speech_ended';
  static const String interruptAi = 'interrupt_ai';
  static const String pauseSession = 'pause_session';
  static const String resumeSession = 'resume_session';
  static const String endSession = 'end_session';
  static const String ping = 'ping';
  static const String syncPosition = 'sync_position';
  static const String updateContext = 'update_context'; // T055 [US2]

  // Server → Client
  static const String connectionEstablished = 'connection_established';
  static const String transcriptionProgress = 'transcription_progress';
  static const String transcriptionFinal = 'transcription_final';
  static const String aiProcessingStarted = 'ai_processing_started'; // T055 [US2]
  static const String aiResponse = 'ai_response'; // T055 [US2]
  static const String aiResponseStarted = 'ai_response_started';
  static const String aiResponseText = 'ai_response_text';
  static const String aiResponseAudio = 'ai_response_audio';
  static const String aiResponseCompleted = 'ai_response_completed';
  static const String contextUpdated = 'context_updated'; // T055 [US2]
  static const String resumeStory = 'resume_story';
  static const String sessionStatusChanged = 'session_status_changed';
  static const String sessionEnded = 'session_ended';
  static const String error = 'error';
  static const String pong = 'pong';
}

/// WebSocket client for real-time interaction with the backend.
///
/// T035 [P] [US1] Implement WebSocket client.
/// T095 [P] Implement graceful reconnection logic.
/// T096 [P] Add connection timeout handling (60s idle disconnect).
/// Handles connection management, message sending/receiving, and reconnection
/// with exponential backoff.
class WebSocketClient {
  WebSocketClient({
    required this.baseUrl,
    this.reconnectOnClose = true,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 60),
    this.connectionTimeout = const Duration(seconds: 10),
  });

  final String baseUrl;
  final bool reconnectOnClose;
  final Duration heartbeatInterval;
  final Duration idleTimeout;
  final Duration connectionTimeout;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _idleTimer;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  DateTime? _lastActivityTime;

  // Store connection info for reconnection
  String? _sessionId;
  String? _token;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _binaryController = StreamController<Uint8List>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of incoming JSON messages from the WebSocket.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of incoming binary data from the WebSocket.
  Stream<Uint8List> get binaryMessages => _binaryController.stream;

  /// Stream of connection state changes.
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Stream of error messages.
  Stream<String> get errors => _errorController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _isConnected;

  /// Whether the WebSocket is attempting to reconnect.
  bool get isReconnecting => _isReconnecting;

  /// Current reconnection attempt number.
  int get reconnectAttempts => _reconnectAttempts;

  /// Connect to the WebSocket endpoint for a specific session.
  /// T096 [P] Added connection timeout handling.
  Future<void> connect({
    required String sessionId,
    required String token,
  }) async {
    if (_isConnected) {
      await disconnect();
    }

    _sessionId = sessionId;
    _token = token;
    _isReconnecting = false;

    final uri = Uri.parse('$baseUrl/v1/ws/interaction/$sessionId?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);

      // T096: Apply connection timeout
      await _channel!.ready.timeout(
        connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Connection timed out', connectionTimeout);
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _lastActivityTime = DateTime.now();
      _connectionStateController.add(true);

      _startHeartbeat();
      _startIdleTimeout();
      _listenToMessages();
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      _errorController.add('Connection failed: $e');
      rethrow;
    }
  }

  /// Send a JSON control message.
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      throw StateError('WebSocket is not connected');
    }

    // Add timestamp if not present
    final messageWithTimestamp = {
      ...message,
      if (!message.containsKey('timestamp'))
        'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    final jsonString = jsonEncode(messageWithTimestamp);
    _channel!.sink.add(jsonString);
    _recordActivity();
  }

  /// Send a generic JSON message (alias for sendMessage).
  void send(Map<String, dynamic> message) => sendMessage(message);

  /// Send binary audio data.
  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _channel == null) {
      throw StateError('WebSocket is not connected');
    }
    _channel!.sink.add(audioData);
    _recordActivity();
  }

  /// Record activity timestamp for idle timeout tracking.
  void _recordActivity() {
    _lastActivityTime = DateTime.now();
    _resetIdleTimeout();
  }

  /// Send start_listening message.
  void sendStartListening() {
    sendMessage({'type': WebSocketMessageType.startListening});
  }

  /// Send stop_listening message.
  void sendStopListening() {
    sendMessage({'type': WebSocketMessageType.stopListening});
  }

  /// Send speech_started message.
  void sendSpeechStarted() {
    sendMessage({'type': WebSocketMessageType.speechStarted});
  }

  /// Send speech_ended message with duration.
  void sendSpeechEnded({required int durationMs}) {
    sendMessage({
      'type': WebSocketMessageType.speechEnded,
      'durationMs': durationMs,
    });
  }

  /// Send interrupt_ai message.
  void sendInterruptAi() {
    sendMessage({'type': WebSocketMessageType.interruptAi});
  }

  /// Send pause_session message.
  void sendPauseSession() {
    sendMessage({'type': WebSocketMessageType.pauseSession});
  }

  /// Send resume_session message.
  void sendResumeSession() {
    sendMessage({'type': WebSocketMessageType.resumeSession});
  }

  /// Send end_session message.
  void sendEndSession() {
    sendMessage({'type': WebSocketMessageType.endSession});
  }

  /// Send sync_position message with story position.
  void sendSyncPosition({required int positionMs}) {
    sendMessage({
      'type': WebSocketMessageType.syncPosition,
      'positionMs': positionMs,
    });
  }

  /// Send update_context message with story context for AI responses.
  /// T055 [US2] Update story context for better AI responses.
  void sendUpdateContext({
    required String storyId,
    required String storyTitle,
    String? storySynopsis,
    List<String>? characters,
    String? currentScene,
  }) {
    sendMessage({
      'type': WebSocketMessageType.updateContext,
      'storyId': storyId,
      'storyTitle': storyTitle,
      if (storySynopsis != null) 'storySynopsis': storySynopsis,
      if (characters != null) 'characters': characters,
      if (currentScene != null) 'currentScene': currentScene,
    });
  }

  /// Disconnect from the WebSocket.
  Future<void> disconnect() async {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _connectionStateController.add(false);
  }

  void _listenToMessages() {
    _subscription?.cancel();
    _subscription = _channel?.stream.listen(
      (message) {
        if (message is String) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _messageController.add(data);
          } catch (e) {
            _errorController.add('Failed to parse message: $e');
          }
        } else if (message is List<int>) {
          _binaryController.add(Uint8List.fromList(message));
        }
      },
      onError: (error) {
        _errorController.add('WebSocket error: $error');
        _handleDisconnection();
      },
      onDone: () {
        _handleDisconnection();
      },
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_isConnected) {
        try {
          sendMessage({'type': WebSocketMessageType.ping});
        } catch (e) {
          // Heartbeat failed, connection may be dead
          _handleDisconnection();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// T096 [P] Start idle timeout monitoring.
  void _startIdleTimeout() {
    _resetIdleTimeout();
  }

  /// T096 [P] Reset idle timeout timer.
  void _resetIdleTimeout() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _handleIdleTimeout);
  }

  /// T096 [P] Stop idle timeout monitoring.
  void _stopIdleTimeout() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// T096 [P] Handle idle timeout - disconnect due to inactivity.
  void _handleIdleTimeout() {
    if (!_isConnected) return;

    _errorController.add('Connection closed due to inactivity (${idleTimeout.inSeconds}s idle timeout)');

    // Send a message to inform the server before disconnecting
    try {
      sendMessage({
        'type': 'idle_timeout',
        'message': 'Client disconnecting due to inactivity',
      });
    } catch (_) {
      // Ignore send errors during timeout
    }

    // Disconnect without attempting reconnection (user needs to explicitly reconnect)
    _isConnected = false;
    _connectionStateController.add(false);
    _stopHeartbeat();
    _stopIdleTimeout();
    _channel?.sink.close();
    _channel = null;
  }

  void _handleDisconnection() {
    if (!_isConnected) return; // Already handling disconnection

    _isConnected = false;
    _connectionStateController.add(false);
    _stopHeartbeat();
    _stopIdleTimeout();

    if (reconnectOnClose && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  /// T095 [P] Schedule reconnection with exponential backoff.
  void _scheduleReconnect() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
    final delay = Duration(
      milliseconds: (1000 * (1 << _reconnectAttempts)).clamp(1000, 30000),
    );
    _reconnectAttempts++;
    _isReconnecting = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_sessionId != null && _token != null) {
        try {
          await connect(sessionId: _sessionId!, token: _token!);
          _isReconnecting = false;
        } catch (e) {
          _errorController.add('Reconnection failed (attempt $_reconnectAttempts/$_maxReconnectAttempts): $e');
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            _isReconnecting = false;
            _errorController.add('Max reconnection attempts reached. Please reconnect manually.');
          }
          // If connect fails, it will trigger _handleDisconnection again
        }
      }
    });
  }

  /// T095 [P] Manually trigger reconnection.
  Future<void> reconnect() async {
    if (_sessionId == null || _token == null) {
      throw StateError('No previous session to reconnect to');
    }
    _reconnectAttempts = 0;
    await connect(sessionId: _sessionId!, token: _token!);
  }

  /// Dispose of resources.
  void dispose() {
    _stopHeartbeat();
    _stopIdleTimeout();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _messageController.close();
    _binaryController.close();
    _connectionStateController.close();
    _errorController.close();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isReconnecting = false;
  }
}
