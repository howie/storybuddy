import 'package:json_annotation/json_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/qa_session.dart';

part 'qa_session_model.g.dart';

/// API model for QASession.
@JsonSerializable()
class QASessionModel {
  QASessionModel({
    required this.id,
    required this.storyId,
    required this.status,
    required this.messageCount,
    required this.startedAt,
    this.endedAt,
  });

  factory QASessionModel.fromJson(Map<String, dynamic> json) =>
      _$QASessionModelFromJson(json);

  factory QASessionModel.fromEntity(QASession entity) => QASessionModel(
        id: entity.id,
        storyId: entity.storyId,
        status: entity.status,
        messageCount: entity.messageCount,
        startedAt: entity.startedAt,
        endedAt: entity.endedAt,
      );

  final String id;

  @JsonKey(name: 'story_id')
  final String storyId;

  @JsonKey(unknownEnumValue: QASessionStatus.active)
  final QASessionStatus status;

  @JsonKey(name: 'message_count')
  final int messageCount;

  @JsonKey(name: 'started_at')
  final DateTime startedAt;

  @JsonKey(name: 'ended_at')
  final DateTime? endedAt;

  Map<String, dynamic> toJson() => _$QASessionModelToJson(this);

  QASession toEntity({
    SyncStatus syncStatus = SyncStatus.synced,
  }) =>
      QASession(
        id: id,
        storyId: storyId,
        status: status,
        messageCount: messageCount,
        startedAt: startedAt,
        endedAt: endedAt,
        syncStatus: syncStatus,
      );
}

/// Request model for starting a session.
@JsonSerializable(createFactory: false)
class StartSessionRequest {
  StartSessionRequest({
    required this.storyId,
  });

  @JsonKey(name: 'story_id')
  final String storyId;

  Map<String, dynamic> toJson() => _$StartSessionRequestToJson(this);
}
