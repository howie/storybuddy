import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import 'package:storybuddy/core/errors/failures.dart';
import 'package:storybuddy/features/interaction/data/datasources/interaction_remote_datasource.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';
import 'package:storybuddy/features/interaction/domain/repositories/interaction_repository.dart';

/// Implementation of InteractionRepository.
///
/// T038 [US1] Implement interaction repository.
class InteractionRepositoryImpl implements InteractionRepository {
  InteractionRepositoryImpl({
    required InteractionRemoteDatasource remoteDatasource,
  }) : _remoteDatasource = remoteDatasource;

  final InteractionRemoteDatasource _remoteDatasource;

  InteractionSession? _currentSession;
  SessionMode _currentMode = SessionMode.passive;

  @override
  Future<Either<Failure, InteractionSession>> startSession({
    required String storyId,
    required String token,
  }) async {
    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      await _remoteDatasource.connect(
        sessionId: sessionId,
        token: token,
      );

      final session = InteractionSession(
        id: sessionId,
        storyId: storyId,
        parentId: '', // TODO: Get from auth
        startedAt: DateTime.now(),
        mode: SessionMode.interactive,
        status: SessionStatus.calibrating,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _currentSession = session;
      _currentMode = SessionMode.interactive;

      return Right(session);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> endSession() async {
    try {
      _remoteDatasource.endSession();
      await _remoteDatasource.disconnect();
      _currentSession = null;
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> switchMode(SessionMode mode) async {
    try {
      if (_currentMode == mode) {
        return const Right(null);
      }

      if (mode == SessionMode.passive) {
        // Switching to passive: end interaction session
        _remoteDatasource.endSession();
        await _remoteDatasource.disconnect();
      }
      // Note: Switching to interactive mode requires starting a new session
      // which is handled by the provider

      _currentMode = mode;
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> pauseSession() async {
    try {
      _remoteDatasource.pauseSession();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resumeSession() async {
    try {
      _remoteDatasource.resumeSession();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  void sendAudio(Uint8List audioData) {
    _remoteDatasource.sendAudio(audioData);
  }

  @override
  void notifySpeechStarted() {
    _remoteDatasource.notifySpeechStarted();
  }

  @override
  void notifySpeechEnded({required int durationMs}) {
    _remoteDatasource.notifySpeechEnded(durationMs: durationMs);
  }

  @override
  void interruptAI() {
    _remoteDatasource.interruptAI();
  }

  @override
  void syncPosition({required int positionMs}) {
    _remoteDatasource.syncPosition(positionMs: positionMs);
  }

  @override
  Stream<TranscriptionUpdate> get transcriptionUpdates =>
      _remoteDatasource.transcriptionUpdates;

  @override
  Stream<AIResponseUpdate> get aiResponseUpdates =>
      _remoteDatasource.aiResponseUpdates;

  @override
  Stream<SessionControlMessage> get sessionControlMessages =>
      _remoteDatasource.sessionControlMessages;

  @override
  Stream<bool> get connectionState => _remoteDatasource.connectionState;

  @override
  Stream<Uint8List> get aiAudioStream => _remoteDatasource.aiAudioStream;

  @override
  bool get isConnected => _remoteDatasource.isConnected;
}
