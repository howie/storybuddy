import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'qa_message.freezed.dart';

/// QAMessage entity representing a message in a Q&A session.
@freezed
class QAMessage with _$QAMessage {
  const factory QAMessage({
    /// Unique identifier.
    required String id,

    /// Session ID this message belongs to.
    required String sessionId,

    /// Message role (child or AI).
    required MessageRole role,

    /// Message text content.
    required String content,

    /// Message sequence number within the session.
    required int sequence, /// Creation timestamp.
    required DateTime createdAt, /// Whether the question was in scope of the story.
    /// Only applicable for child messages.
    bool? isInScope,

    /// Audio URL for the AI response.
    String? audioUrl,

    /// Local audio path for offline playback.
    String? localAudioPath,

    /// Sync status for offline support.
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _QAMessage;

  const QAMessage._();

  /// Creates a child (question) message.
  factory QAMessage.childQuestion({
    required String id,
    required String sessionId,
    required String content,
    required int sequence,
    bool? isInScope,
  }) {
    return QAMessage(
      id: id,
      sessionId: sessionId,
      role: MessageRole.child,
      content: content,
      isInScope: isInScope,
      sequence: sequence,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Creates an AI (response) message.
  factory QAMessage.aiResponse({
    required String id,
    required String sessionId,
    required String content,
    required int sequence,
    String? audioUrl,
  }) {
    return QAMessage(
      id: id,
      sessionId: sessionId,
      role: MessageRole.assistant,
      content: content,
      audioUrl: audioUrl,
      sequence: sequence,
      createdAt: DateTime.now(),
    );
  }

  /// Returns true if this is a child message.
  bool get isChildMessage => role == MessageRole.child;

  /// Returns true if this is an AI message.
  bool get isAiMessage => role == MessageRole.assistant;

  /// Returns true if the question was out of scope.
  bool get isOutOfScope => isInScope == false;

  /// Returns true if the message has audio.
  bool get hasAudio => audioUrl != null || localAudioPath != null;

  /// Returns true if audio is available offline.
  bool get hasOfflineAudio => localAudioPath != null;

  /// Returns true if the message has pending local changes.
  bool get hasPendingChanges => syncStatus == SyncStatus.pendingSync;

  /// Returns a display-friendly role label.
  String get roleLabel => switch (role) {
        MessageRole.child => '小朋友',
        MessageRole.assistant => 'AI',
      };
}

/// Out-of-scope response template.
class OutOfScopeResponse {
  OutOfScopeResponse._();

  /// Default response for out-of-scope questions.
  static const String defaultResponse = '這個問題很有趣！我先記錄下來，等一下問問爸爸媽媽好嗎？';

  /// Audio prompt indicating the question was saved.
  static const String savedPrompt = '好的，我已經把你的問題記下來了！';
}
