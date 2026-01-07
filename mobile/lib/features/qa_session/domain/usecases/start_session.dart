import '../entities/qa_session.dart';
import '../repositories/qa_session_repository.dart';

/// Use case for starting a Q&A session.
class StartSessionUseCase {
  StartSessionUseCase({required this.repository});

  final QASessionRepository repository;

  /// Starts a new Q&A session for a story.
  /// If an active session exists, returns that instead.
  Future<QASession> call(String storyId) async {
    if (storyId.isEmpty) {
      throw InvalidStoryIdException();
    }

    // Check for existing active session
    final existingSession = await repository.getActiveSessionForStory(storyId);
    if (existingSession != null && existingSession.isActive) {
      return existingSession;
    }

    // Start new session
    return repository.startSession(storyId);
  }

  /// Gets the active session for a story.
  Future<QASession?> getActiveSession(String storyId) {
    return repository.getActiveSessionForStory(storyId);
  }

  /// Ends an active session.
  Future<QASession> endSession(String sessionId) {
    return repository.endSession(sessionId);
  }
}

/// Exception thrown when story ID is invalid.
class InvalidStoryIdException implements Exception {
  @override
  String toString() => '故事 ID 無效';
}

/// Exception thrown when session could not be started.
class SessionStartException implements Exception {
  SessionStartException(this.message);

  final String message;

  @override
  String toString() => '無法開始問答：$message';
}
