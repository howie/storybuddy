import '../entities/parent.dart';

/// Repository interface for Parent operations.
abstract class ParentRepository {
  /// Gets the current parent (from local or remote).
  Future<Parent?> getCurrentParent();

  /// Gets a parent by ID.
  Future<Parent?> getParent(String id);

  /// Gets a parent by email.
  Future<Parent?> getParentByEmail(String email);

  /// Creates a new parent.
  Future<Parent> createParent({
    required String name,
    String? email,
  });

  /// Updates an existing parent.
  Future<Parent> updateParent({
    required String id,
    String? name,
    String? email,
  });

  /// Deletes a parent.
  Future<void> deleteParent(String id);

  /// Syncs local parent data with the server.
  Future<void> syncParent(String id);

  /// Saves a parent to local storage.
  Future<void> saveParentLocally(Parent parent);

  /// Sets the current parent ID.
  Future<void> setCurrentParentId(String id);

  /// Gets the current parent ID.
  Future<String?> getCurrentParentId();
}
