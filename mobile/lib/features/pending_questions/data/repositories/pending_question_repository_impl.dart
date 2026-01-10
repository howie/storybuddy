import '../../../../core/database/enums.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/pending_question.dart';
import '../../domain/repositories/pending_question_repository.dart';
import '../datasources/pending_question_local_datasource.dart';
import '../datasources/pending_question_remote_datasource.dart';

/// Implementation of PendingQuestionRepository with offline-first pattern.
class PendingQuestionRepositoryImpl implements PendingQuestionRepository {
  PendingQuestionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivityService,
  });

  final PendingQuestionRemoteDataSource remoteDataSource;
  final PendingQuestionLocalDataSource localDataSource;
  final ConnectivityService connectivityService;

  @override
  Future<List<PendingQuestion>> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  }) async {
    // Try to sync with remote if online
    if (await connectivityService.isConnected) {
      try {
        await _syncFromRemote(
            storyId: storyId, includeAnswered: includeAnswered,);
      } catch (_) {
        // Continue with local data if sync fails
      }
    }

    return localDataSource.getPendingQuestions(
      storyId: storyId,
      includeAnswered: includeAnswered,
    );
  }

  @override
  Future<PendingQuestion?> getQuestion(String questionId) async {
    // Try remote first if online
    if (await connectivityService.isConnected) {
      try {
        final model = await remoteDataSource.getQuestion(questionId);
        final entity = model.toEntity();
        await localDataSource.saveQuestion(entity);
        return entity;
      } catch (_) {
        // Fall back to local
      }
    }

    return localDataSource.getQuestion(questionId);
  }

  @override
  Future<List<PendingQuestionSummary>> getPendingQuestionSummaries() async {
    // Sync first if online
    if (await connectivityService.isConnected) {
      try {
        await _syncFromRemote();
      } catch (_) {
        // Continue with local
      }
    }

    return localDataSource.getPendingQuestionSummaries();
  }

  @override
  Future<int> getPendingCount({String? storyId}) async {
    return localDataSource.getPendingCount(storyId: storyId);
  }

  @override
  Future<void> markAsAnswered(String questionId) async {
    final question = await localDataSource.getQuestion(questionId);
    if (question == null) {
      throw QuestionNotFoundException(questionId);
    }

    final updatedQuestion = question.copyWith(
      status: PendingQuestionStatus.answered,
      answeredAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );

    await localDataSource.updateQuestion(updatedQuestion);

    // Try to sync immediately if online
    if (await connectivityService.isConnected) {
      try {
        await remoteDataSource.markAsAnswered(questionId);

        // Mark as synced
        await localDataSource.updateQuestion(
          updatedQuestion.copyWith(syncStatus: SyncStatus.synced),
        );
      } catch (_) {
        // Will sync later
      }
    }
  }

  @override
  Future<PendingQuestion> saveQuestion(PendingQuestion question) async {
    final questionWithSync = question.copyWith(
      syncStatus: SyncStatus.pendingSync,
    );

    await localDataSource.saveQuestion(questionWithSync);

    // This is typically called from Q&A session when a question is marked
    // as out-of-scope, so it should already exist on the server
    return questionWithSync;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    // Delete locally
    await localDataSource.deleteQuestion(questionId);

    // Try to delete remotely if online
    if (await connectivityService.isConnected) {
      try {
        await remoteDataSource.deleteQuestion(questionId);
      } catch (_) {
        // Question might not exist on server
      }
    }
  }

  @override
  Future<void> sync() async {
    if (!await connectivityService.isConnected) {
      return;
    }

    // Upload local changes
    final pendingSync = await localDataSource.getQuestionsNeedingSync();
    for (final question in pendingSync) {
      try {
        if (question.status == PendingQuestionStatus.answered) {
          await remoteDataSource.markAsAnswered(question.id);
        }

        await localDataSource.updateQuestion(
          question.copyWith(syncStatus: SyncStatus.synced),
        );
      } catch (_) {
        // Will retry later
      }
    }

    // Download remote changes
    await _syncFromRemote();
  }

  @override
  Stream<List<PendingQuestion>> watchPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  }) {
    return localDataSource.watchPendingQuestions(
      storyId: storyId,
      includeAnswered: includeAnswered,
    );
  }

  @override
  Stream<int> watchPendingCount() {
    return localDataSource.watchPendingCount();
  }

  Future<void> _syncFromRemote({
    String? storyId,
    bool includeAnswered = false,
  }) async {
    final response = await remoteDataSource.getPendingQuestions(
      storyId: storyId,
      includeAnswered: includeAnswered,
    );

    final questions =
        response.questions.map((model) => model.toEntity()).toList();

    await localDataSource.saveQuestions(questions);
  }
}

/// Exception thrown when a question is not found.
class QuestionNotFoundException implements Exception {
  QuestionNotFoundException(this.questionId);

  final String questionId;

  @override
  String toString() => '找不到問題: $questionId';
}
