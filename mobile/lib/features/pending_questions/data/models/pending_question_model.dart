import 'package:json_annotation/json_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/pending_question.dart';

part 'pending_question_model.g.dart';

/// API model for pending questions.
@JsonSerializable()
class PendingQuestionModel {
  PendingQuestionModel({
    required this.id,
    required this.storyId,
    required this.question,
    required this.askedAt,
    this.status = 'pending',
    this.answeredAt,
  });

  factory PendingQuestionModel.fromJson(Map<String, dynamic> json) =>
      _$PendingQuestionModelFromJson(json);

  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'story_id')
  final String storyId;

  @JsonKey(name: 'question')
  final String question;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'asked_at')
  final DateTime askedAt;

  @JsonKey(name: 'answered_at')
  final DateTime? answeredAt;

  Map<String, dynamic> toJson() => _$PendingQuestionModelToJson(this);

  /// Converts API model to domain entity.
  PendingQuestion toEntity({SyncStatus syncStatus = SyncStatus.synced}) {
    return PendingQuestion(
      id: id,
      storyId: storyId,
      question: question,
      status: _parseStatus(status),
      askedAt: askedAt,
      answeredAt: answeredAt,
      syncStatus: syncStatus,
    );
  }

  /// Parses status string to enum.
  PendingQuestionStatus _parseStatus(String status) {
    switch (status) {
      case 'answered':
        return PendingQuestionStatus.answered;
      case 'pending':
      default:
        return PendingQuestionStatus.pending;
    }
  }

  /// Creates API model from domain entity.
  factory PendingQuestionModel.fromEntity(PendingQuestion entity) {
    return PendingQuestionModel(
      id: entity.id,
      storyId: entity.storyId,
      question: entity.question,
      status: entity.status == PendingQuestionStatus.answered ? 'answered' : 'pending',
      askedAt: entity.askedAt,
      answeredAt: entity.answeredAt,
    );
  }
}

/// Response for pending questions list.
@JsonSerializable()
class PendingQuestionsResponse {
  PendingQuestionsResponse({
    required this.questions,
    required this.total,
  });

  factory PendingQuestionsResponse.fromJson(Map<String, dynamic> json) =>
      _$PendingQuestionsResponseFromJson(json);

  final List<PendingQuestionModel> questions;
  final int total;

  Map<String, dynamic> toJson() => _$PendingQuestionsResponseToJson(this);
}

/// Request for marking question as answered.
@JsonSerializable()
class MarkAnsweredRequest {
  MarkAnsweredRequest();

  factory MarkAnsweredRequest.fromJson(Map<String, dynamic> json) =>
      _$MarkAnsweredRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MarkAnsweredRequestToJson(this);
}

/// Summary model for pending questions per story.
@JsonSerializable()
class PendingQuestionSummaryModel {
  PendingQuestionSummaryModel({
    required this.storyId,
    required this.storyTitle,
    required this.pendingCount,
    this.latestQuestionAt,
  });

  factory PendingQuestionSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$PendingQuestionSummaryModelFromJson(json);

  @JsonKey(name: 'story_id')
  final String storyId;

  @JsonKey(name: 'story_title')
  final String storyTitle;

  @JsonKey(name: 'pending_count')
  final int pendingCount;

  @JsonKey(name: 'latest_question_at')
  final DateTime? latestQuestionAt;

  Map<String, dynamic> toJson() => _$PendingQuestionSummaryModelToJson(this);

  /// Converts to domain entity.
  PendingQuestionSummary toEntity() {
    return PendingQuestionSummary(
      storyId: storyId,
      storyTitle: storyTitle,
      pendingCount: pendingCount,
      latestQuestionAt: latestQuestionAt,
    );
  }
}
