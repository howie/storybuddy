import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_settings_model.freezed.dart';
part 'interaction_settings_model.g.dart';

/// T064 [P] [US3] Create InteractionSettings model.
/// Model for interaction settings including recording preferences.

@freezed
class InteractionSettingsModel with _$InteractionSettingsModel {
  const factory InteractionSettingsModel({
    /// Whether audio recording is enabled (FR-018).
    @Default(false) @JsonKey(name: 'recordingEnabled') bool recordingEnabled,

    /// Whether to automatically transcribe recordings.
    @Default(true) @JsonKey(name: 'autoTranscribe') bool autoTranscribe,

    /// Number of days to retain recordings (FR-019).
    @Default(30) @JsonKey(name: 'retentionDays') int retentionDays,
  }) = _InteractionSettingsModel;

  factory InteractionSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$InteractionSettingsModelFromJson(json);
}

/// Response model for settings update.
@freezed
class UpdateSettingsResponse with _$UpdateSettingsResponse {
  const factory UpdateSettingsResponse({
    required bool success,
    InteractionSettingsModel? settings,
  }) = _UpdateSettingsResponse;

  factory UpdateSettingsResponse.fromJson(Map<String, dynamic> json) =>
      _$UpdateSettingsResponseFromJson(json);
}

/// Storage usage statistics.
@freezed
class StorageUsage with _$StorageUsage {
  const factory StorageUsage({
    @JsonKey(name: 'totalRecordings') required int totalRecordings,
    @JsonKey(name: 'totalSizeBytes') required int totalSizeBytes,
    @JsonKey(name: 'totalSizeMB') required double totalSizeMB,
    @JsonKey(name: 'totalDurationMs') required int totalDurationMs,
    @JsonKey(name: 'totalDurationSeconds') required double totalDurationSeconds,
  }) = _StorageUsage;

  factory StorageUsage.fromJson(Map<String, dynamic> json) =>
      _$StorageUsageFromJson(json);
}
