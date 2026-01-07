import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/parent_model.dart';

/// Remote data source for Parent operations.
abstract class ParentRemoteDataSource {
  /// Gets a parent by ID from the API.
  Future<ParentModel> getParent(String id);

  /// Gets a parent by email from the API, returns null if not found.
  Future<ParentModel?> getParentByEmail(String email);

  /// Creates a new parent via the API.
  Future<ParentModel> createParent(CreateParentRequest request);

  /// Updates a parent via the API.
  Future<ParentModel> updateParent(String id, UpdateParentRequest request);

  /// Deletes a parent via the API.
  Future<void> deleteParent(String id);
}

/// Implementation of [ParentRemoteDataSource].
class ParentRemoteDataSourceImpl implements ParentRemoteDataSource {
  ParentRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<ParentModel> getParent(String id) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/parents/$id',
      );

      if (response.data == null) {
        throw const NotFoundException(
          message: 'Parent not found',
          resourceType: 'Parent',
        );
      }

      return ParentModel.fromJson(response.data!);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to get parent: $e',
      );
    }
  }

  @override
  Future<ParentModel?> getParentByEmail(String email) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/parents/by-email/$email',
      );

      if (response.data == null) {
        return null;
      }

      return ParentModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw ServerException(
        message: 'Failed to get parent by email: ${e.message}',
      );
    } on NotFoundException {
      return null;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to get parent by email: $e',
      );
    }
  }

  @override
  Future<ParentModel> createParent(CreateParentRequest request) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/parents',
        data: request.toJson(),
      );

      if (response.data == null) {
        throw const ServerException(
          message: 'Failed to create parent: Empty response',
        );
      }

      return ParentModel.fromJson(response.data!);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to create parent: $e',
      );
    }
  }

  @override
  Future<ParentModel> updateParent(
    String id,
    UpdateParentRequest request,
  ) async {
    try {
      final response = await apiClient.patch<Map<String, dynamic>>(
        '/parents/$id',
        data: request.toJson(),
      );

      if (response.data == null) {
        throw const ServerException(
          message: 'Failed to update parent: Empty response',
        );
      }

      return ParentModel.fromJson(response.data!);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to update parent: $e',
      );
    }
  }

  @override
  Future<void> deleteParent(String id) async {
    try {
      await apiClient.delete<void>('/parents/$id');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to delete parent: $e',
      );
    }
  }
}
