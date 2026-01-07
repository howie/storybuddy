import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/qa_message_model.dart';
import '../models/qa_session_model.dart';

/// Remote data source for Q&A session operations.
abstract class QASessionRemoteDataSource {
  /// Starts a new Q&A session for a story.
  Future<QASessionModel> startSession(String storyId);

  /// Gets a session by ID.
  Future<QASessionModel> getSession(String sessionId);

  /// Sends a voice question and gets AI response.
  Future<QuestionResponseModel> sendVoiceQuestion({
    required String sessionId,
    required String audioFilePath,
  });

  /// Sends a text question and gets AI response.
  Future<QuestionResponseModel> sendTextQuestion({
    required String sessionId,
    required String question,
  });

  /// Transcribes audio to text.
  Future<TranscriptionResponse> transcribeAudio(String audioFilePath);

  /// Gets all messages for a session.
  Future<List<QAMessageModel>> getMessages(String sessionId);

  /// Ends a Q&A session.
  Future<QASessionModel> endSession(String sessionId);
}

/// Implementation of [QASessionRemoteDataSource].
class QASessionRemoteDataSourceImpl implements QASessionRemoteDataSource {
  QASessionRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<QASessionModel> startSession(String storyId) async {
    final request = StartSessionRequest(storyId: storyId);
    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/sessions',
      data: request.toJson(),
    );
    if (response.data == null) {
      throw Exception('No response data from start session');
    }
    return QASessionModel.fromJson(response.data!);
  }

  @override
  Future<QASessionModel> getSession(String sessionId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/qa/sessions/$sessionId',
    );
    if (response.data == null) {
      throw Exception('No response data from get session');
    }
    return QASessionModel.fromJson(response.data!);
  }

  @override
  Future<QuestionResponseModel> sendVoiceQuestion({
    required String sessionId,
    required String audioFilePath,
  }) async {
    final file = File(audioFilePath);
    final fileName = audioFilePath.split('/').last;

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/sessions/$sessionId/voice-question',
      data: formData,
    );
    if (response.data == null) {
      throw Exception('No response data from voice question');
    }
    return QuestionResponseModel.fromJson(response.data!);
  }

  @override
  Future<QuestionResponseModel> sendTextQuestion({
    required String sessionId,
    required String question,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/sessions/$sessionId/text-question',
      data: {'question': question},
    );
    if (response.data == null) {
      throw Exception('No response data from text question');
    }
    return QuestionResponseModel.fromJson(response.data!);
  }

  @override
  Future<TranscriptionResponse> transcribeAudio(String audioFilePath) async {
    final file = File(audioFilePath);
    final fileName = audioFilePath.split('/').last;

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/transcribe',
      data: formData,
    );
    if (response.data == null) {
      throw Exception('No response data from transcription');
    }
    return TranscriptionResponse.fromJson(response.data!);
  }

  @override
  Future<List<QAMessageModel>> getMessages(String sessionId) async {
    final response = await apiClient.get<List<dynamic>>(
      '/qa/sessions/$sessionId/messages',
    );
    if (response.data == null) {
      return [];
    }
    return response.data!
        .map((json) => QAMessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<QASessionModel> endSession(String sessionId) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/qa/sessions/$sessionId/end',
    );
    if (response.data == null) {
      throw Exception('No response data from end session');
    }
    return QASessionModel.fromJson(response.data!);
  }
}
