import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/pending_question.dart' as entity;

/// Local data source for pending questions using Drift.
abstract class PendingQuestionLocalDataSource {
  /// Gets all pending questions.
  Future<List<entity.PendingQuestion>> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  });

  /// Gets a specific question by ID.
  Future<entity.PendingQuestion?> getQuestion(String questionId);

  /// Gets pending question summaries.
  Future<List<entity.PendingQuestionSummary>> getPendingQuestionSummaries();

  /// Gets pending count.
  Future<int> getPendingCount({String? storyId});

  /// Saves a pending question.
  Future<void> saveQuestion(entity.PendingQuestion question);

  /// Saves multiple pending questions.
  Future<void> saveQuestions(List<entity.PendingQuestion> questions);

  /// Updates a question.
  Future<void> updateQuestion(entity.PendingQuestion question);

  /// Deletes a question.
  Future<void> deleteQuestion(String questionId);

  /// Gets questions pending sync.
  Future<List<entity.PendingQuestion>> getQuestionsNeedingSync();

  /// Watches pending questions for real-time updates.
  Stream<List<entity.PendingQuestion>> watchPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  });

  /// Watches pending count.
  Stream<int> watchPendingCount();

  /// Clears all pending questions.
  Future<void> clearAll();
}

/// Implementation of pending question local data source.
class PendingQuestionLocalDataSourceImpl
    implements PendingQuestionLocalDataSource {
  PendingQuestionLocalDataSourceImpl({required this.database});

  final AppDatabase database;

  @override
  Future<List<entity.PendingQuestion>> getPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  }) async {
    var query = database.select(database.pendingQuestions);

    if (storyId != null) {
      query = query..where((q) => q.storyId.equals(storyId));
    }

    if (!includeAnswered) {
      query = query
        ..where(
            (q) => q.status.equalsValue(PendingQuestionStatus.pending));
    }

    query = query
      ..orderBy([
        (q) => OrderingTerm.desc(q.askedAt),
      ]);

    final entries = await query.get();
    return entries.map(_entryToEntity).toList();
  }

  @override
  Future<entity.PendingQuestion?> getQuestion(String questionId) async {
    final query = database.select(database.pendingQuestions)
      ..where((q) => q.id.equals(questionId));

    final entry = await query.getSingleOrNull();
    return entry != null ? _entryToEntity(entry) : null;
  }

  @override
  Future<List<entity.PendingQuestionSummary>> getPendingQuestionSummaries() async {
    // Get all pending questions grouped by story
    final query = database.select(database.pendingQuestions)
      ..where((q) => q.status.equalsValue(PendingQuestionStatus.pending));

    final entries = await query.get();

    // Group by storyId
    final grouped = <String, List<entity.PendingQuestion>>{};
    for (final entry in entries) {
      final question = _entryToEntity(entry);
      grouped.putIfAbsent(question.storyId, () => []).add(question);
    }

    // Create summaries
    return grouped.entries.map((e) {
      final questions = e.value;
      final latest = questions.reduce(
        (a, b) => a.askedAt.isAfter(b.askedAt) ? a : b,
      );
      return entity.PendingQuestionSummary(
        storyId: e.key,
        storyTitle: '故事', // TODO: Join with stories table
        pendingCount: questions.length,
        latestQuestionAt: latest.askedAt,
      );
    }).toList();
  }

  @override
  Future<int> getPendingCount({String? storyId}) async {
    var query = database.select(database.pendingQuestions)
      ..where((q) => q.status.equalsValue(PendingQuestionStatus.pending));

    if (storyId != null) {
      query = query..where((q) => q.storyId.equals(storyId));
    }

    final entries = await query.get();
    return entries.length;
  }

  @override
  Future<void> saveQuestion(entity.PendingQuestion question) async {
    await database
        .into(database.pendingQuestions)
        .insertOnConflictUpdate(_entityToCompanion(question));
  }

  @override
  Future<void> saveQuestions(List<entity.PendingQuestion> questions) async {
    await database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        database.pendingQuestions,
        questions.map(_entityToCompanion).toList(),
      );
    });
  }

  @override
  Future<void> updateQuestion(entity.PendingQuestion question) async {
    await (database.update(database.pendingQuestions)
          ..where((q) => q.id.equals(question.id)))
        .write(_entityToCompanion(question));
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await (database.delete(database.pendingQuestions)
          ..where((q) => q.id.equals(questionId)))
        .go();
  }

  @override
  Future<List<entity.PendingQuestion>> getQuestionsNeedingSync() async {
    final query = database.select(database.pendingQuestions)
      ..where((q) => q.syncStatus.equalsValue(SyncStatus.pendingSync));

    final entries = await query.get();
    return entries.map(_entryToEntity).toList();
  }

  @override
  Stream<List<entity.PendingQuestion>> watchPendingQuestions({
    String? storyId,
    bool includeAnswered = false,
  }) {
    var query = database.select(database.pendingQuestions);

    if (storyId != null) {
      query = query..where((q) => q.storyId.equals(storyId));
    }

    if (!includeAnswered) {
      query = query
        ..where(
            (q) => q.status.equalsValue(PendingQuestionStatus.pending));
    }

    query = query
      ..orderBy([
        (q) => OrderingTerm.desc(q.askedAt),
      ]);

    return query.watch().map((entries) => entries.map(_entryToEntity).toList());
  }

  @override
  Stream<int> watchPendingCount() {
    final query = database.select(database.pendingQuestions)
      ..where((q) => q.status.equalsValue(PendingQuestionStatus.pending));

    return query.watch().map((entries) => entries.length);
  }

  @override
  Future<void> clearAll() async {
    await database.delete(database.pendingQuestions).go();
  }

  /// Converts a database row to a domain entity.
  entity.PendingQuestion _entryToEntity(PendingQuestion row) {
    return entity.PendingQuestion(
      id: row.id,
      storyId: row.storyId,
      question: row.question,
      status: row.status,
      askedAt: row.askedAt,
      answeredAt: row.answeredAt,
      syncStatus: row.syncStatus,
    );
  }

  /// Converts a domain entity to a database companion for insert/update.
  PendingQuestionsCompanion _entityToCompanion(entity.PendingQuestion question) {
    return PendingQuestionsCompanion(
      id: Value(question.id),
      storyId: Value(question.storyId),
      question: Value(question.question),
      status: Value(question.status),
      askedAt: Value(question.askedAt),
      answeredAt: Value(question.answeredAt),
      syncStatus: Value(question.syncStatus),
    );
  }
}
