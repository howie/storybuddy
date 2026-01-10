import 'package:json_annotation/json_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/qa_message.dart';

part 'qa_message_model.g.dart';

/// API model for QAMessage.
@JsonSerializable()
class QAMessageModel {
  QAMessageModel({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.sequence, required this.createdAt, this.isInScope,
    this.audioUrl,
  });

  factory QAMessageModel.fromJson(Map<String, dynamic> json) =>
      _$QAMessageModelFromJson(json);

  factory QAMessageModel.fromEntity(QAMessage entity) => QAMessageModel(
        id: entity.id,
        sessionId: entity.sessionId,
        role: entity.role,
        content: entity.content,
        isInScope: entity.isInScope,
        audioUrl: entity.audioUrl,
        sequence: entity.sequence,
        createdAt: entity.createdAt,
      );

  final String id;

  @JsonKey(name: 'session_id')
  final String sessionId;

  @JsonKey(unknownEnumValue: MessageRole.child)
  final MessageRole role;

  final String content;

  @JsonKey(name: 'is_in_scope')
  final bool? isInScope;

  @JsonKey(name: 'audio_url')
  final String? audioUrl;

  final int sequence;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$QAMessageModelToJson(this);

  QAMessage toEntity({
    String? localAudioPath,
    SyncStatus syncStatus = SyncStatus.synced,
  }) =>
      QAMessage(
        id: id,
        sessionId: sessionId,
        role: role,
        content: content,
        isInScope: isInScope,
        audioUrl: audioUrl,
        localAudioPath: localAudioPath,
        sequence: sequence,
        createdAt: createdAt,
        syncStatus: syncStatus,
      );
}

/// Response from sending a question to the AI.
@JsonSerializable()
class QuestionResponseModel {
  QuestionResponseModel({
    required this.childMessage,
    required this.aiMessage,
    required this.transcribedText,
    required this.isInScope,
  });

  factory QuestionResponseModel.fromJson(Map<String, dynamic> json) =>
      _$QuestionResponseModelFromJson(json);

  @JsonKey(name: 'child_message')
  final QAMessageModel childMessage;

  @JsonKey(name: 'ai_message')
  final QAMessageModel aiMessage;

  @JsonKey(name: 'transcribed_text')
  final String transcribedText;

  @JsonKey(name: 'is_in_scope')
  final bool isInScope;

  Map<String, dynamic> toJson() => _$QuestionResponseModelToJson(this);
}

/// Response from transcribing audio.
@JsonSerializable()
class TranscriptionResponse {
  TranscriptionResponse({
    required this.text,
    required this.language,
    this.confidence,
  });

  factory TranscriptionResponse.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionResponseFromJson(json);

  final String text;
  final String language;
  final double? confidence;

  Map<String, dynamic> toJson() => _$TranscriptionResponseToJson(this);
}
