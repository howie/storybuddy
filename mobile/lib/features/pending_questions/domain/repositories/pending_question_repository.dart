import '../../../../core/database/enums.dart';
import '../entities/pending_question.dart';

/// Repository interface for pending questions.
abstract class PendingQuestionRepository {
  /// Gets all pending questions, optionally filtered by story.
  Future<List<PendingQuestion>> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  });

  /// Gets a specific pending question by ID.
  Future<PendingQuestion?> getQuestion(String questionId);

  /// Gets pending question summaries grouped by story.
  Future<List<PendingQuestionSummary>> getPendingQuestionSummaries();

  /// Gets the count of unanswered questions.
  Future<int> getPendingCount({String? storyId});

  /// Marks a question as answered.
  Future<void> markAsAnswered(String questionId);

  /// Saves a new pending question.
  Future<PendingQuestion> saveQuestion(PendingQuestion question);

  /// Deletes a pending question.
  Future<void> deleteQuestion(String questionId);

  /// Syncs pending questions with remote.
  Future<void> sync();

  /// Stream of pending questions for real-time updates.
  Stream<List<PendingQuestion>> watchPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  });

  /// Stream of pending count for badge updates.
  Stream<int> watchPendingCount();
}
