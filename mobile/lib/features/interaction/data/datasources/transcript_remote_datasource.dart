import 'package:dio/dio.dart';

import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';

/// T080 [US4] Implement transcript API methods.
///
/// Remote datasource for transcript operations.
abstract class TranscriptRemoteDatasource {
  /// Get list of transcripts for the current user.
  Future<TranscriptListResponse> getTranscripts({
    String? storyId,
    int page = 1,
    int pageSize = 20,
  });

  /// Get a specific transcript by ID.
  Future<InteractionTranscript> getTranscript(String transcriptId);

  /// Generate a new transcript for a session.
  Future<InteractionTranscript> generateTranscript(String sessionId);

  /// Send transcript via email.
  Future<SendEmailResult> sendTranscriptEmail({
    required String transcriptId,
    required String email,
  });

  /// Delete a transcript.
  Future<bool> deleteTranscript(String transcriptId);

  /// Export transcript in specified format.
  Future<TranscriptExport> exportTranscript({
    required String transcriptId,
    required String format, // "html", "txt", "pdf"
  });
}

/// Response for transcript list.
class TranscriptListResponse {
  const TranscriptListResponse({
    required this.transcripts,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<TranscriptSummary> transcripts;
  final int total;
  final int page;
  final int pageSize;

  factory TranscriptListResponse.fromJson(Map<String, dynamic> json) {
    return TranscriptListResponse(
      transcripts: (json['transcripts'] as List<dynamic>)
          .map((e) => TranscriptSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
    );
  }

  bool get hasMore => page * pageSize < total;
}

/// Result of sending email.
class SendEmailResult {
  const SendEmailResult({
    required this.success,
    this.messageId,
    this.error,
  });

  final bool success;
  final String? messageId;
  final String? error;

  factory SendEmailResult.fromJson(Map<String, dynamic> json) {
    return SendEmailResult(
      success: json['success'] as bool,
      messageId: json['messageId'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Exported transcript content.
class TranscriptExport {
  const TranscriptExport({
    required this.content,
    required this.format,
    required this.filename,
  });

  final String content;
  final String format;
  final String filename;
}

/// Implementation of TranscriptRemoteDatasource.
class TranscriptRemoteDatasourceImpl implements TranscriptRemoteDatasource {
  TranscriptRemoteDatasourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<TranscriptListResponse> getTranscripts({
    String? storyId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (storyId != null) {
      queryParams['storyId'] = storyId;
    }

    final response = await _dio.get(
      '/v1/interaction/transcripts',
      queryParameters: queryParams,
    );

    return TranscriptListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<InteractionTranscript> getTranscript(String transcriptId) async {
    final response = await _dio.get('/v1/interaction/transcripts/$transcriptId');

    return InteractionTranscript.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<InteractionTranscript> generateTranscript(String sessionId) async {
    final response = await _dio.post(
      '/v1/interaction/transcripts/generate',
      data: {'sessionId': sessionId},
    );

    return InteractionTranscript.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<SendEmailResult> sendTranscriptEmail({
    required String transcriptId,
    required String email,
  }) async {
    final response = await _dio.post(
      '/v1/interaction/transcripts/$transcriptId/send',
      data: {'email': email},
    );

    return SendEmailResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<bool> deleteTranscript(String transcriptId) async {
    final response = await _dio.delete(
      '/v1/interaction/transcripts/$transcriptId',
    );

    final data = response.data as Map<String, dynamic>;
    return data['success'] as bool? ?? false;
  }

  @override
  Future<TranscriptExport> exportTranscript({
    required String transcriptId,
    required String format,
  }) async {
    final response = await _dio.get(
      '/v1/interaction/transcripts/$transcriptId/export',
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.plain),
    );

    // Get filename from content-disposition header
    final contentDisposition = response.headers.value('content-disposition');
    String filename = 'transcript.$format';
    if (contentDisposition != null) {
      final match = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
      if (match != null) {
        filename = match.group(1)!;
      }
    }

    return TranscriptExport(
      content: response.data as String,
      format: format,
      filename: filename,
    );
  }
}
