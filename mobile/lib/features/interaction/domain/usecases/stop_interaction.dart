import 'package:dartz/dartz.dart';

import 'package:storybuddy/core/errors/failures.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';
import 'package:storybuddy/features/interaction/domain/repositories/interaction_repository.dart';

/// Use case for stopping an interactive story session.
///
/// T040 [US1] Implement stop_interaction usecase.
/// Gracefully ends the session and cleans up resources.
class StopInteraction {
  StopInteraction({
    required InteractionRepository repository,
  }) : _repository = repository;

  final InteractionRepository _repository;

  /// Execute the use case.
  ///
  /// Returns [Right] with void on success or [Left] with [Failure].
  Future<Either<Failure, void>> call() async {
    return _repository.endSession();
  }
}

/// Use case for switching between interactive and passive modes.
///
/// T040 [US1] Part of mode switching implementation (FR-013).
class SwitchInteractionMode {
  SwitchInteractionMode({
    required InteractionRepository repository,
  }) : _repository = repository;

  final InteractionRepository _repository;

  /// Switch to the specified mode.
  ///
  /// [mode] - The target session mode.
  /// [storyId] - Story ID (required when switching to interactive mode).
  /// [token] - Auth token (required when switching to interactive mode).
  ///
  /// Note: Switching to interactive mode may require additional setup
  /// like noise calibration.
  Future<Either<Failure, void>> call({
    required SessionMode mode,
    String? storyId,
    String? token,
  }) async {
    return _repository.switchMode(mode);
  }
}
