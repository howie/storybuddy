import '../entities/qa_message.dart';
import '../entities/qa_session.dart';

/// Repository interface for Q&A session operations.
abstract class QASessionRepository {
  /// Starts a new Q&A session for a story.
  Future<QASession> startSession(String storyId);

  /// Gets a session by ID.
  Future<QASession?> getSession(String sessionId);

  /// Gets the active session for a story, if any.
  Future<QASession?> getActiveSessionForStory(String storyId);

  /// Sends a voice question and gets AI response.
  /// Returns the child message and AI response message.
  Future<(QAMessage childMessage, QAMessage aiMessage)> sendVoiceQuestion({
    required String sessionId,
    required String audioFilePath,
  });

  /// Sends a text question and gets AI response.
  /// Returns the child message and AI response message.
  Future<(QAMessage childMessage, QAMessage aiMessage)> sendTextQuestion({
    required String sessionId,
    required String question,
  });

  /// Gets all messages for a session.
  Future<List<QAMessage>> getMessages(String sessionId);

  /// Ends a Q&A session.
  Future<QASession> endSession(String sessionId);

  /// Syncs pending messages with the server.
  Future<void> syncAllPending();

  /// Stream of messages for reactive UI updates.
  Stream<List<QAMessage>> watchMessages(String sessionId);

  /// Stream of session state for reactive UI updates.
  Stream<QASession?> watchSession(String sessionId);
}
