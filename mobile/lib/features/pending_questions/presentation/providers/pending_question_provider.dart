import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/datasources/pending_question_local_datasource.dart';
import '../../data/datasources/pending_question_remote_datasource.dart';
import '../../data/repositories/pending_question_repository_impl.dart';
import '../../domain/entities/pending_question.dart';
import '../../domain/repositories/pending_question_repository.dart';
import '../../domain/usecases/get_pending_questions.dart';

part 'pending_question_provider.g.dart';

/// Provider for pending question repository.
@riverpod
PendingQuestionRepository pendingQuestionRepository(
  PendingQuestionRepositoryRef ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  final database = ref.watch(databaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  return PendingQuestionRepositoryImpl(
    remoteDataSource: PendingQuestionRemoteDataSourceImpl(apiClient: apiClient),
    localDataSource: PendingQuestionLocalDataSourceImpl(database: database),
    connectivityService: connectivity,
  );
}

/// Provider for get pending questions use case.
@riverpod
GetPendingQuestionsUseCase getPendingQuestionsUseCase(
  GetPendingQuestionsUseCaseRef ref,
) {
  return GetPendingQuestionsUseCase(
    repository: ref.watch(pendingQuestionRepositoryProvider),
  );
}

/// Provider for mark question answered use case.
@riverpod
MarkQuestionAnsweredUseCase markQuestionAnsweredUseCase(
  MarkQuestionAnsweredUseCaseRef ref,
) {
  return MarkQuestionAnsweredUseCase(
    repository: ref.watch(pendingQuestionRepositoryProvider),
  );
}

/// Provider for pending questions list.
@riverpod
class PendingQuestionsNotifier extends _$PendingQuestionsNotifier {
  @override
  Future<List<PendingQuestion>> build({String? storyId}) async {
    final useCase = ref.watch(getPendingQuestionsUseCaseProvider);
    return useCase(storyId: storyId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(getPendingQuestionsUseCaseProvider);
      return useCase(storyId: storyId);
    });
  }

  Future<void> markAsAnswered(String questionId) async {
    final markUseCase = ref.read(markQuestionAnsweredUseCaseProvider);

    try {
      await markUseCase(questionId);
      await refresh();
    } catch (e) {
      // Re-throw to let UI handle
      rethrow;
    }
  }
}

/// Provider for pending question summaries.
@riverpod
Future<List<PendingQuestionSummary>> pendingQuestionSummaries(
  PendingQuestionSummariesRef ref,
) async {
  final useCase = ref.watch(getPendingQuestionsUseCaseProvider);
  return useCase.getSummaries();
}

/// Provider for pending count.
@riverpod
Future<int> pendingQuestionCount(PendingQuestionCountRef ref) async {
  final useCase = ref.watch(getPendingQuestionsUseCaseProvider);
  return useCase.getCount();
}

/// Provider for watching pending count (for badge).
@riverpod
Stream<int> pendingQuestionCountStream(PendingQuestionCountStreamRef ref) {
  final useCase = ref.watch(getPendingQuestionsUseCaseProvider);
  return useCase.watchCount();
}

/// Provider for a single pending question.
@riverpod
Future<PendingQuestion?> pendingQuestion(
  PendingQuestionRef ref,
  String questionId,
) async {
  final repository = ref.watch(pendingQuestionRepositoryProvider);
  return repository.getQuestion(questionId);
}

/// State for the pending question answer dialog.
class AnswerQuestionState {
  AnswerQuestionState({
    this.isSubmitting = false,
    this.error,
  });

  final bool isSubmitting;
  final String? error;

  AnswerQuestionState copyWith({
    bool? isSubmitting,
    String? error,
  }) {
    return AnswerQuestionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

/// Notifier for answering a question.
@riverpod
class AnswerQuestionNotifier extends _$AnswerQuestionNotifier {
  @override
  AnswerQuestionState build() {
    return AnswerQuestionState();
  }

  Future<bool> submit(String questionId) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true);

    try {
      final markUseCase = ref.read(markQuestionAnsweredUseCaseProvider);
      await markUseCase(questionId);

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = AnswerQuestionState();
  }
}
