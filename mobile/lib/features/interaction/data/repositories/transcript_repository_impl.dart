import 'package:storybuddy/features/interaction/data/datasources/transcript_remote_datasource.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';
import 'package:storybuddy/features/interaction/domain/repositories/transcript_repository.dart';

/// T080 [US4] Implementation of TranscriptRepository.
class TranscriptRepositoryImpl implements TranscriptRepository {
  TranscriptRepositoryImpl({
    required TranscriptRemoteDatasource remoteDatasource,
  }) : _remoteDatasource = remoteDatasource;

  final TranscriptRemoteDatasource _remoteDatasource;

  @override
  Future<TranscriptListResponse> getTranscripts({
    String? storyId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _remoteDatasource.getTranscripts(
      storyId: storyId,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<InteractionTranscript> getTranscript(String transcriptId) async {
    return _remoteDatasource.getTranscript(transcriptId);
  }

  @override
  Future<InteractionTranscript> generateTranscript(String sessionId) async {
    return _remoteDatasource.generateTranscript(sessionId);
  }

  @override
  Future<SendEmailResult> sendEmail({
    required String transcriptId,
    required String email,
  }) async {
    return _remoteDatasource.sendTranscriptEmail(
      transcriptId: transcriptId,
      email: email,
    );
  }

  @override
  Future<bool> deleteTranscript(String transcriptId) async {
    return _remoteDatasource.deleteTranscript(transcriptId);
  }

  @override
  Future<TranscriptExport> exportTranscript({
    required String transcriptId,
    required String format,
  }) async {
    return _remoteDatasource.exportTranscript(
      transcriptId: transcriptId,
      format: format,
    );
  }
}
