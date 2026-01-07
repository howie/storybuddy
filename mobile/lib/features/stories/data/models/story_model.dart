import 'package:json_annotation/json_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/story.dart';

part 'story_model.g.dart';

/// API model for Story.
@JsonSerializable()
class StoryModel {
  StoryModel({
    required this.id,
    required this.parentId,
    required this.title,
    required this.content,
    required this.source,
    this.keywords,
    required this.wordCount,
    this.estimatedDurationMinutes,
    this.audioUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) =>
      _$StoryModelFromJson(json);

  factory StoryModel.fromEntity(Story entity) => StoryModel(
        id: entity.id,
        parentId: entity.parentId,
        title: entity.title,
        content: entity.content,
        source: entity.source,
        keywords: entity.keywords,
        wordCount: entity.wordCount,
        estimatedDurationMinutes: entity.estimatedDurationMinutes,
        audioUrl: entity.audioUrl,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );

  final String id;

  @JsonKey(name: 'parent_id')
  final String parentId;

  final String title;
  final String content;

  @JsonKey(unknownEnumValue: StorySource.imported)
  final StorySource source;

  final List<String>? keywords;

  @JsonKey(name: 'word_count')
  final int wordCount;

  @JsonKey(name: 'estimated_duration_minutes')
  final int? estimatedDurationMinutes;

  @JsonKey(name: 'audio_url')
  final String? audioUrl;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$StoryModelToJson(this);

  Story toEntity({
    String? localAudioPath,
    bool isDownloaded = false,
    SyncStatus syncStatus = SyncStatus.synced,
  }) =>
      Story(
        id: id,
        parentId: parentId,
        title: title,
        content: content,
        source: source,
        keywords: keywords,
        wordCount: wordCount,
        estimatedDurationMinutes: estimatedDurationMinutes,
        audioUrl: audioUrl,
        localAudioPath: localAudioPath,
        isDownloaded: isDownloaded,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

/// Request model for importing a story.
@JsonSerializable(createFactory: false)
class ImportStoryRequest {
  ImportStoryRequest({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  Map<String, dynamic> toJson() => _$ImportStoryRequestToJson(this);
}

/// Request model for generating a story.
@JsonSerializable(createFactory: false)
class GenerateStoryRequest {
  GenerateStoryRequest({
    required this.keywords,
  });

  final List<String> keywords;

  Map<String, dynamic> toJson() => _$GenerateStoryRequestToJson(this);
}

/// Request model for updating a story.
@JsonSerializable(createFactory: false)
class UpdateStoryRequest {
  UpdateStoryRequest({
    this.title,
    this.content,
  });

  final String? title;
  final String? content;

  Map<String, dynamic> toJson() => _$UpdateStoryRequestToJson(this);
}
