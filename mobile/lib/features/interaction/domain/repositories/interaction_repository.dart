import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import 'package:storybuddy/core/errors/failures.dart';
import 'package:storybuddy/features/interaction/data/datasources/interaction_remote_datasource.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';

/// Repository interface for interaction feature.
///
/// T038 [US1] Define interaction repository interface.
/// Abstracts data operations for interactive story sessions.
abstract class InteractionRepository {
  /// Start a new interaction session.
  ///
  /// Connects to WebSocket and initializes audio streaming.
  Future<Either<Failure, InteractionSession>> startSession({
    required String storyId,
    required String token,
  });

  /// End the current interaction session.
  Future<Either<Failure, void>> endSession();

  /// Switch between interactive and passive modes.
  Future<Either<Failure, void>> switchMode(SessionMode mode);

  /// Pause the session.
  Future<Either<Failure, void>> pauseSession();

  /// Resume the session.
  Future<Either<Failure, void>> resumeSession();

  /// Send audio data for transcription.
  void sendAudio(Uint8List audioData);

  /// Notify that speech has started.
  void notifySpeechStarted();

  /// Notify that speech has ended.
  void notifySpeechEnded({required int durationMs});

  /// Interrupt ongoing AI response.
  void interruptAI();

  /// Sync story playback position.
  void syncPosition({required int positionMs});

  /// Stream of transcription updates.
  Stream<TranscriptionUpdate> get transcriptionUpdates;

  /// Stream of AI response updates.
  Stream<AIResponseUpdate> get aiResponseUpdates;

  /// Stream of session control messages.
  Stream<SessionControlMessage> get sessionControlMessages;

  /// Stream of connection state changes.
  Stream<bool> get connectionState;

  /// Stream of AI audio data.
  Stream<Uint8List> get aiAudioStream;

  /// Whether currently connected.
  bool get isConnected;
}
