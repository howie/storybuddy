import '../entities/pending_question.dart';
import '../repositories/pending_question_repository.dart';

/// Use case for getting pending questions.
class GetPendingQuestionsUseCase {
  GetPendingQuestionsUseCase({required this.repository});

  final PendingQuestionRepository repository;

  /// Gets pending questions, optionally filtered by story.
  Future<List<PendingQuestion>> call({
    String? storyId,
    bool includeAnswered = false,
  }) {
    return repository.getPendingQuestions(
      storyId: storyId,
      includeAnswered: includeAnswered,
    );
  }

  /// Gets pending question summaries grouped by story.
  Future<List<PendingQuestionSummary>> getSummaries() {
    return repository.getPendingQuestionSummaries();
  }

  /// Gets total count of pending questions.
  Future<int> getCount({String? storyId}) {
    return repository.getPendingCount(storyId: storyId);
  }

  /// Watches pending questions for real-time updates.
  Stream<List<PendingQuestion>> watch({
    String? storyId,
    bool includeAnswered = false,
  }) {
    return repository.watchPendingQuestions(
      storyId: storyId,
      includeAnswered: includeAnswered,
    );
  }

  /// Watches pending count for badge updates.
  Stream<int> watchCount() {
    return repository.watchPendingCount();
  }
}

/// Use case for marking a question as answered.
class MarkQuestionAnsweredUseCase {
  MarkQuestionAnsweredUseCase({required this.repository});

  final PendingQuestionRepository repository;

  /// Marks a question as answered.
  Future<void> call(String questionId) async {
    await repository.markAsAnswered(questionId);
  }
}
