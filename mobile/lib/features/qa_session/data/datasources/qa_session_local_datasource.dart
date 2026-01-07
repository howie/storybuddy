import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/qa_message.dart' as entity;
import '../../domain/entities/qa_session.dart' as entity;

/// Local data source for Q&A session operations using Drift.
abstract class QASessionLocalDataSource {
  /// Gets a session by ID.
  Future<entity.QASession?> getSession(String sessionId);

  /// Gets the active session for a story.
  Future<entity.QASession?> getActiveSessionForStory(String storyId);

  /// Saves a session to local database.
  Future<void> saveSession(entity.QASession session);

  /// Updates a session in local database.
  Future<void> updateSession(entity.QASession session);

  /// Gets all messages for a session.
  Future<List<entity.QAMessage>> getMessages(String sessionId);

  /// Saves a message to local database.
  Future<void> saveMessage(entity.QAMessage message);

  /// Saves multiple messages to local database.
  Future<void> saveMessages(List<entity.QAMessage> messages);

  /// Gets pending sessions for sync.
  Future<List<entity.QASession>> getPendingSessions();

  /// Gets pending messages for sync.
  Future<List<entity.QAMessage>> getPendingMessages();

  /// Updates sync status for a session.
  Future<void> updateSessionSyncStatus(String sessionId, SyncStatus status);

  /// Updates sync status for a message.
  Future<void> updateMessageSyncStatus(String messageId, SyncStatus status);

  /// Watches all messages for a session.
  Stream<List<entity.QAMessage>> watchMessages(String sessionId);

  /// Watches a session for reactive updates.
  Stream<entity.QASession?> watchSession(String sessionId);
}

/// Implementation of [QASessionLocalDataSource] using Drift.
class QASessionLocalDataSourceImpl implements QASessionLocalDataSource {
  QASessionLocalDataSourceImpl({required this.database});

  final AppDatabase database;

  @override
  Future<entity.QASession?> getSession(String sessionId) async {
    final row = await (database.select(database.qASessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    return row != null ? _sessionFromRow(row) : null;
  }

  @override
  Future<entity.QASession?> getActiveSessionForStory(String storyId) async {
    final row = await (database.select(database.qASessions)
          ..where((t) => t.storyId.equals(storyId))
          ..where((t) => t.status.equalsValue(QASessionStatus.active))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _sessionFromRow(row) : null;
  }

  @override
  Future<void> saveSession(entity.QASession session) async {
    await database.into(database.qASessions).insertOnConflictUpdate(
          _sessionToCompanion(session),
        );
  }

  @override
  Future<void> updateSession(entity.QASession session) async {
    await (database.update(database.qASessions)
          ..where((t) => t.id.equals(session.id)))
        .write(_sessionToCompanion(session));
  }

  @override
  Future<List<entity.QAMessage>> getMessages(String sessionId) async {
    final rows = await (database.select(database.qAMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .get();
    return rows.map(_messageFromRow).toList();
  }

  @override
  Future<void> saveMessage(entity.QAMessage message) async {
    await database.into(database.qAMessages).insertOnConflictUpdate(
          _messageToCompanion(message),
        );
  }

  @override
  Future<void> saveMessages(List<entity.QAMessage> messages) async {
    await database.batch((batch) {
      for (final message in messages) {
        batch.insert(
          database.qAMessages,
          _messageToCompanion(message),
          onConflict: DoUpdate((_) => _messageToCompanion(message)),
        );
      }
    });
  }

  @override
  Future<List<entity.QASession>> getPendingSessions() async {
    final rows = await (database.select(database.qASessions)
          ..where(
            (t) => t.syncStatus.equalsValue(SyncStatus.pendingSync),
          ))
        .get();
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<List<entity.QAMessage>> getPendingMessages() async {
    final rows = await (database.select(database.qAMessages)
          ..where(
            (t) => t.syncStatus.equalsValue(SyncStatus.pendingSync),
          ))
        .get();
    return rows.map(_messageFromRow).toList();
  }

  @override
  Future<void> updateSessionSyncStatus(
    String sessionId,
    SyncStatus status,
  ) async {
    await (database.update(database.qASessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(QASessionsCompanion(syncStatus: Value(status)));
  }

  @override
  Future<void> updateMessageSyncStatus(
    String messageId,
    SyncStatus status,
  ) async {
    await (database.update(database.qAMessages)
          ..where((t) => t.id.equals(messageId)))
        .write(QAMessagesCompanion(syncStatus: Value(status)));
  }

  @override
  Stream<List<entity.QAMessage>> watchMessages(String sessionId) {
    return (database.select(database.qAMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .watch()
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  @override
  Stream<entity.QASession?> watchSession(String sessionId) {
    return (database.select(database.qASessions)
          ..where((t) => t.id.equals(sessionId)))
        .watchSingleOrNull()
        .map((row) => row != null ? _sessionFromRow(row) : null);
  }

  /// Converts a database row to a QASession entity.
  entity.QASession _sessionFromRow(QASession row) {
    return entity.QASession(
      id: row.id,
      storyId: row.storyId,
      status: row.status,
      messageCount: row.messageCount,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      syncStatus: row.syncStatus,
    );
  }

  /// Converts a QASession entity to a database companion.
  QASessionsCompanion _sessionToCompanion(entity.QASession session) {
    return QASessionsCompanion(
      id: Value(session.id),
      storyId: Value(session.storyId),
      status: Value(session.status),
      messageCount: Value(session.messageCount),
      startedAt: Value(session.startedAt),
      endedAt: Value(session.endedAt),
      syncStatus: Value(session.syncStatus),
    );
  }

  /// Converts a database row to a QAMessage entity.
  entity.QAMessage _messageFromRow(QAMessage row) {
    return entity.QAMessage(
      id: row.id,
      sessionId: row.sessionId,
      role: row.role,
      content: row.content,
      isInScope: row.isInScope,
      audioUrl: row.audioUrl,
      localAudioPath: row.localAudioPath,
      sequence: row.sequence,
      createdAt: row.createdAt,
      syncStatus: row.syncStatus,
    );
  }

  /// Converts a QAMessage entity to a database companion.
  QAMessagesCompanion _messageToCompanion(entity.QAMessage message) {
    return QAMessagesCompanion(
      id: Value(message.id),
      sessionId: Value(message.sessionId),
      role: Value(message.role),
      content: Value(message.content),
      isInScope: Value(message.isInScope),
      audioUrl: Value(message.audioUrl),
      localAudioPath: Value(message.localAudioPath),
      sequence: Value(message.sequence),
      createdAt: Value(message.createdAt),
      syncStatus: Value(message.syncStatus),
    );
  }
}
