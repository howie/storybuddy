import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';
import '../../domain/entities/parent.dart';

part 'parent_model.freezed.dart';
part 'parent_model.g.dart';

/// API model for Parent entity.
@freezed
class ParentModel with _$ParentModel {
  const factory ParentModel({
    required String id,
    required String name,
    String? email,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _ParentModel;

  const ParentModel._();

  factory ParentModel.fromJson(Map<String, dynamic> json) =>
      _$ParentModelFromJson(json);

  /// Converts to domain entity.
  Parent toEntity() {
    return Parent(
      id: id,
      name: name,
      email: email,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: SyncStatus.synced,
    );
  }

  /// Creates from domain entity.
  factory ParentModel.fromEntity(Parent entity) {
    return ParentModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}

/// Request model for creating a parent.
@freezed
class CreateParentRequest with _$CreateParentRequest {
  const factory CreateParentRequest({
    required String name,
    String? email,
  }) = _CreateParentRequest;

  factory CreateParentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateParentRequestFromJson(json);
}

/// Request model for updating a parent.
@freezed
class UpdateParentRequest with _$UpdateParentRequest {
  const factory UpdateParentRequest({
    String? name,
    String? email,
  }) = _UpdateParentRequest;

  factory UpdateParentRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateParentRequestFromJson(json);
}
