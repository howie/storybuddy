import '../entities/qa_message.dart';
import '../entities/qa_session.dart';
import '../repositories/qa_session_repository.dart';

/// Use case for sending a question in a Q&A session.
class SendQuestionUseCase {
  SendQuestionUseCase({required this.repository});

  final QASessionRepository repository;

  /// Sends a voice question and returns the AI response.
  Future<QuestionResponse> sendVoiceQuestion({
    required String sessionId,
    required String audioFilePath,
  }) async {
    // Validate session
    final session = await repository.getSession(sessionId);
    if (session == null) {
      throw SessionNotFoundException();
    }

    if (!session.isActive) {
      throw SessionEndedException();
    }

    if (session.hasReachedLimit) {
      throw MessageLimitReachedException();
    }

    // Send question
    final (childMessage, aiMessage) = await repository.sendVoiceQuestion(
      sessionId: sessionId,
      audioFilePath: audioFilePath,
    );

    // Get updated session
    final updatedSession = await repository.getSession(sessionId);

    return QuestionResponse(
      childMessage: childMessage,
      aiMessage: aiMessage,
      session: updatedSession!,
    );
  }

  /// Sends a text question and returns the AI response.
  Future<QuestionResponse> sendTextQuestion({
    required String sessionId,
    required String question,
  }) async {
    if (question.trim().isEmpty) {
      throw EmptyQuestionException();
    }

    // Validate session
    final session = await repository.getSession(sessionId);
    if (session == null) {
      throw SessionNotFoundException();
    }

    if (!session.isActive) {
      throw SessionEndedException();
    }

    if (session.hasReachedLimit) {
      throw MessageLimitReachedException();
    }

    // Send question
    final (childMessage, aiMessage) = await repository.sendTextQuestion(
      sessionId: sessionId,
      question: question.trim(),
    );

    // Get updated session
    final updatedSession = await repository.getSession(sessionId);

    return QuestionResponse(
      childMessage: childMessage,
      aiMessage: aiMessage,
      session: updatedSession!,
    );
  }

  /// Gets all messages for a session.
  Future<List<QAMessage>> getMessages(String sessionId) {
    return repository.getMessages(sessionId);
  }

  /// Returns a stream of messages for reactive updates.
  Stream<List<QAMessage>> watchMessages(String sessionId) {
    return repository.watchMessages(sessionId);
  }
}

/// Response from sending a question.
class QuestionResponse {
  QuestionResponse({
    required this.childMessage,
    required this.aiMessage,
    required this.session,
  });

  final QAMessage childMessage;
  final QAMessage aiMessage;
  final QASession session;

  /// Returns true if the question was out of scope.
  bool get wasOutOfScope => childMessage.isOutOfScope;

  /// Returns true if the session has reached the message limit.
  bool get hasReachedLimit => session.hasReachedLimit;

  /// Returns true if the session is near the message limit.
  bool get isNearLimit => session.isNearLimit;
}

/// Exception thrown when session is not found.
class SessionNotFoundException implements Exception {
  @override
  String toString() => '找不到問答對話';
}

/// Exception thrown when session has ended.
class SessionEndedException implements Exception {
  @override
  String toString() => '問答對話已結束';
}

/// Exception thrown when message limit is reached.
class MessageLimitReachedException implements Exception {
  @override
  String toString() => '已達到問答次數上限';
}

/// Exception thrown when question is empty.
class EmptyQuestionException implements Exception {
  @override
  String toString() => '問題不能是空的';
}
