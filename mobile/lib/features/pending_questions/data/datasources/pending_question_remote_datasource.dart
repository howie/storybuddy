import '../../../../core/network/api_client.dart';
import '../models/pending_question_model.dart';

/// Remote data source for pending questions API.
abstract class PendingQuestionRemoteDataSource {
  /// Gets pending questions from API.
  Future<PendingQuestionsResponse> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  });

  /// Gets a specific pending question.
  Future<PendingQuestionModel> getQuestion(String questionId);

  /// Gets pending question summaries.
  Future<List<PendingQuestionSummaryModel>> getPendingQuestionSummaries();

  /// Gets pending count.
  Future<int> getPendingCount({String? storyId});

  /// Marks a question as answered.
  Future<PendingQuestionModel> markAsAnswered(String questionId);

  /// Deletes a pending question.
  Future<void> deleteQuestion(String questionId);
}

/// Implementation of pending question remote data source.
class PendingQuestionRemoteDataSourceImpl
    implements PendingQuestionRemoteDataSource {
  PendingQuestionRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<PendingQuestionsResponse> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  }) async {
    final queryParams = <String, dynamic>{
      'include_answered': includeAnswered,
    };

    if (storyId != null) {
      queryParams['story_id'] = storyId;
    }

    final response = await apiClient.get<Map<String, dynamic>>(
      '/qa/pending',
      queryParameters: queryParams,
    );

    return PendingQuestionsResponse.fromJson(response.data!);
  }

  @override
  Future<PendingQuestionModel> getQuestion(String questionId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/qa/pending/$questionId',
    );
    return PendingQuestionModel.fromJson(response.data!);
  }

  @override
  Future<List<PendingQuestionSummaryModel>>
      getPendingQuestionSummaries() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/qa/pending/summaries',
    );
    final summaries =
        response.data!['summaries'] as List<dynamic>;
    return summaries
        .map((s) =>
            PendingQuestionSummaryModel.fromJson(s as Map<String, dynamic>),)
        .toList();
  }

  @override
  Future<int> getPendingCount({String? storyId}) async {
    final queryParams = <String, dynamic>{};

    if (storyId != null) {
      queryParams['story_id'] = storyId;
    }

    final response = await apiClient.get<Map<String, dynamic>>(
      '/qa/pending/count',
      queryParameters: queryParams,
    );

    return response.data!['count'] as int;
  }

  @override
  Future<PendingQuestionModel> markAsAnswered(String questionId) async {
    final request = MarkAnsweredRequest();

    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/pending/$questionId/answer',
      data: request.toJson(),
    );

    return PendingQuestionModel.fromJson(response.data!);
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await apiClient.delete('/qa/pending/$questionId');
  }
}
