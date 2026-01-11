import 'package:dartz/dartz.dart';

import 'package:storybuddy/core/errors/failures.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';
import 'package:storybuddy/features/interaction/domain/repositories/interaction_repository.dart';

/// Use case for starting an interactive story session.
///
/// T039 [US1] Implement start_interaction usecase.
/// Validates story availability, requests permissions, and initializes session.
class StartInteraction {
  StartInteraction({
    required InteractionRepository repository,
  }) : _repository = repository;

  final InteractionRepository _repository;

  /// Execute the use case.
  ///
  /// [storyId] - ID of the story to play interactively.
  /// [token] - Authentication token for WebSocket connection.
  ///
  /// Returns the created [InteractionSession] or a [Failure].
  Future<Either<Failure, InteractionSession>> call({
    required String storyId,
    required String token,
  }) async {
    // Validate parameters
    if (storyId.isEmpty) {
      return const Left(ValidationFailure(message: 'Story ID cannot be empty'));
    }

    if (token.isEmpty) {
      return const Left(
          ValidationFailure(message: 'Authentication token is required'));
    }

    // Start the session
    return _repository.startSession(
      storyId: storyId,
      token: token,
    );
  }
}

/// Parameters for StartInteraction use case.
class StartInteractionParams {
  const StartInteractionParams({
    required this.storyId,
    required this.token,
  });

  final String storyId;
  final String token;
}
