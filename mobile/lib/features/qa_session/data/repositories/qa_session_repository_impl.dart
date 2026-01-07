import 'package:uuid/uuid.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/qa_message.dart';
import '../../domain/entities/qa_session.dart';
import '../../domain/repositories/qa_session_repository.dart';
import '../datasources/qa_session_local_datasource.dart';
import '../datasources/qa_session_remote_datasource.dart';
import '../services/voice_input_service.dart';

/// Implementation of [QASessionRepository] with offline-first pattern.
class QASessionRepositoryImpl implements QASessionRepository {
  QASessionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.voiceInputService,
    required this.connectivityService,
  });

  final QASessionRemoteDataSource remoteDataSource;
  final QASessionLocalDataSource localDataSource;
  final VoiceInputService voiceInputService;
  final ConnectivityService connectivityService;

  final _uuid = const Uuid();

  @override
  Future<QASession> startSession(String storyId) async {
    // Create local session
    final session = QASession.create(
      id: _uuid.v4(),
      storyId: storyId,
    );

    // Save locally first
    await localDataSource.saveSession(session);

    // Sync to remote if online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.startSession(storyId);
        final syncedSession = remoteModel.toEntity();
        await localDataSource.saveSession(syncedSession);
        return syncedSession;
      } catch (_) {
        // Keep local version
        return session;
      }
    }

    return session;
  }

  @override
  Future<QASession?> getSession(String sessionId) async {
    return localDataSource.getSession(sessionId);
  }

  @override
  Future<QASession?> getActiveSessionForStory(String storyId) async {
    return localDataSource.getActiveSessionForStory(storyId);
  }

  @override
  Future<(QAMessage, QAMessage)> sendVoiceQuestion({
    required String sessionId,
    required String audioFilePath,
  }) async {
    final session = await localDataSource.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    if (!await connectivityService.isConnected) {
      throw Exception('需要網路連線才能發送問題');
    }

    // Send to backend for transcription and AI response
    final response = await remoteDataSource.sendVoiceQuestion(
      sessionId: sessionId,
      audioFilePath: audioFilePath,
    );

    // Convert to entities
    final childMessage = response.childMessage.toEntity();
    final aiMessage = response.aiMessage.toEntity();

    // Save messages locally
    await localDataSource.saveMessage(childMessage);
    await localDataSource.saveMessage(aiMessage);

    // Update session message count
    final updatedSession = session.copyWith(
      messageCount: session.messageCount + 2,
      syncStatus: SyncStatus.synced,
    );
    await localDataSource.updateSession(updatedSession);

    // Create pending question if out of scope
    if (!response.isInScope) {
      await _createPendingQuestion(
        storyId: session.storyId,
        question: response.transcribedText,
      );
    }

    return (childMessage, aiMessage);
  }

  @override
  Future<(QAMessage, QAMessage)> sendTextQuestion({
    required String sessionId,
    required String question,
  }) async {
    final session = await localDataSource.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    if (!await connectivityService.isConnected) {
      throw Exception('需要網路連線才能發送問題');
    }

    // Send to backend
    final response = await remoteDataSource.sendTextQuestion(
      sessionId: sessionId,
      question: question,
    );

    // Convert to entities
    final childMessage = response.childMessage.toEntity();
    final aiMessage = response.aiMessage.toEntity();

    // Save messages locally
    await localDataSource.saveMessage(childMessage);
    await localDataSource.saveMessage(aiMessage);

    // Update session message count
    final updatedSession = session.copyWith(
      messageCount: session.messageCount + 2,
      syncStatus: SyncStatus.synced,
    );
    await localDataSource.updateSession(updatedSession);

    // Create pending question if out of scope
    if (!response.isInScope) {
      await _createPendingQuestion(
        storyId: session.storyId,
        question: question,
      );
    }

    return (childMessage, aiMessage);
  }

  @override
  Future<List<QAMessage>> getMessages(String sessionId) async {
    return localDataSource.getMessages(sessionId);
  }

  @override
  Future<QASession> endSession(String sessionId) async {
    final session = await localDataSource.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    // Update local session
    final endedSession = session.copyWith(
      status: QASessionStatus.completed,
      endedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
    await localDataSource.updateSession(endedSession);

    // Sync to remote if online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.endSession(sessionId);
        final syncedSession = remoteModel.toEntity();
        await localDataSource.saveSession(syncedSession);
        return syncedSession;
      } catch (_) {
        // Keep local version
        return endedSession;
      }
    }

    return endedSession;
  }

  @override
  Future<void> syncAllPending() async {
    if (!await connectivityService.isConnected) {
      return;
    }

    // Sync pending sessions
    final pendingSessions = await localDataSource.getPendingSessions();
    for (final session in pendingSessions) {
      try {
        if (session.isEnded) {
          await remoteDataSource.endSession(session.id);
        }
        await localDataSource.updateSessionSyncStatus(
          session.id,
          SyncStatus.synced,
        );
      } catch (_) {
        // Continue with other sessions
      }
    }
  }

  @override
  Stream<List<QAMessage>> watchMessages(String sessionId) {
    return localDataSource.watchMessages(sessionId);
  }

  @override
  Stream<QASession?> watchSession(String sessionId) {
    return localDataSource.watchSession(sessionId);
  }

  /// Creates a pending question for out-of-scope questions.
  Future<void> _createPendingQuestion({
    required String storyId,
    required String question,
  }) async {
    // This will be implemented in the pending questions feature
    // For now, we just log it
  }
}
