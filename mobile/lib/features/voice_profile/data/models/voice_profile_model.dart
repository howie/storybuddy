import 'package:json_annotation/json_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/voice_profile.dart';

part 'voice_profile_model.g.dart';

/// API model for VoiceProfile.
@JsonSerializable()
class VoiceProfileModel {
  VoiceProfileModel({
    required this.id,
    required this.parentId,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sampleDurationSeconds,
    this.remoteVoiceModelUrl,
    this.errorMessage,
  });

  factory VoiceProfileModel.fromJson(Map<String, dynamic> json) =>
      _$VoiceProfileModelFromJson(json);

  factory VoiceProfileModel.fromEntity(VoiceProfile entity) =>
      VoiceProfileModel(
        id: entity.id,
        parentId: entity.parentId,
        name: entity.name,
        status: entity.status,
        sampleDurationSeconds: entity.sampleDurationSeconds,
        remoteVoiceModelUrl: entity.remoteVoiceModelUrl,
        errorMessage: entity.errorMessage,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );

  final String id;

  @JsonKey(name: 'parent_id')
  final String parentId;

  final String name;

  @JsonKey(unknownEnumValue: VoiceProfileStatus.pending)
  final VoiceProfileStatus status;

  @JsonKey(name: 'sample_duration_seconds')
  final int? sampleDurationSeconds;

  @JsonKey(name: 'voice_model_url')
  final String? remoteVoiceModelUrl;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$VoiceProfileModelToJson(this);

  VoiceProfile toEntity({
    String? localAudioPath,
    SyncStatus syncStatus = SyncStatus.synced,
  }) =>
      VoiceProfile(
        id: id,
        parentId: parentId,
        name: name,
        status: status,
        sampleDurationSeconds: sampleDurationSeconds,
        localAudioPath: localAudioPath,
        remoteVoiceModelUrl: remoteVoiceModelUrl,
        errorMessage: errorMessage,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

/// Request model for creating a voice profile.
@JsonSerializable(createFactory: false)
class CreateVoiceProfileRequest {
  CreateVoiceProfileRequest({
    required this.name,
    required this.sampleDurationSeconds,
  });

  final String name;

  @JsonKey(name: 'sample_duration_seconds')
  final int sampleDurationSeconds;

  Map<String, dynamic> toJson() => _$CreateVoiceProfileRequestToJson(this);
}
