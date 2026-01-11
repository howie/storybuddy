import 'package:storybuddy/features/interaction/data/datasources/transcript_remote_datasource.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';

/// T080 [US4] Repository interface for transcript operations.
abstract class TranscriptRepository {
  /// Get paginated list of transcripts.
  Future<TranscriptListResponse> getTranscripts({
    String? storyId,
    int page = 1,
    int pageSize = 20,
  });

  /// Get a specific transcript.
  Future<InteractionTranscript> getTranscript(String transcriptId);

  /// Generate transcript for a session.
  Future<InteractionTranscript> generateTranscript(String sessionId);

  /// Send transcript via email.
  Future<SendEmailResult> sendEmail({
    required String transcriptId,
    required String email,
  });

  /// Delete a transcript.
  Future<bool> deleteTranscript(String transcriptId);

  /// Export transcript in the specified format.
  Future<TranscriptExport> exportTranscript({
    required String transcriptId,
    required String format,
  });
}
