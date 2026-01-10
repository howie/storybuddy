import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'parent.freezed.dart';

/// Parent entity representing a user account.
@freezed
class Parent with _$Parent {
  const factory Parent({
    /// Unique identifier.
    required String id,

    /// Display name.
    required String name,

    /// Creation timestamp.
    required DateTime createdAt, /// Last update timestamp.
    required DateTime updatedAt, /// Optional email address.
    String? email,

    /// Sync status for offline support.
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _Parent;

  const Parent._();

  /// Creates a new parent with generated ID and timestamps.
  factory Parent.create({
    required String id,
    required String name,
    String? email,
  }) {
    final now = DateTime.now();
    return Parent(
      id: id,
      name: name,
      email: email,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Returns true if the parent has been synced with the server.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Returns true if there are pending local changes.
  bool get hasPendingChanges => syncStatus == SyncStatus.pendingSync;
}
