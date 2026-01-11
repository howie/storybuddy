import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/story.dart' as entity;

/// Local data source for Story operations using Drift.
abstract class StoryLocalDataSource {
  /// Gets all stories for the current parent.
  Future<List<entity.Story>> getStories();

  /// Gets a single story by ID.
  Future<entity.Story?> getStory(String id);

  /// Saves a story to local database.
  Future<void> saveStory(entity.Story story);

  /// Saves multiple stories to local database.
  Future<void> saveStories(List<entity.Story> stories);

  /// Updates a story in local database.
  Future<void> updateStory(entity.Story story);

  /// Deletes a story from local database.
  Future<void> deleteStory(String id);

  /// Gets stories with pending sync status.
  Future<List<entity.Story>> getPendingStories();

  /// Updates sync status for a story.
  Future<void> updateSyncStatus(String id, SyncStatus status);

  /// Updates local audio path for a story.
  Future<void> updateLocalAudioPath(String id, String? path, bool isDownloaded);

  /// Watches all stories for reactive updates.
  Stream<List<entity.Story>> watchStories();

  /// Watches a single story for reactive updates.
  Stream<entity.Story?> watchStory(String id);
}

/// Implementation of [StoryLocalDataSource] using Drift.
class StoryLocalDataSourceImpl implements StoryLocalDataSource {
  StoryLocalDataSourceImpl({required this.database});

  final AppDatabase database;

  @override
  Future<List<entity.Story>> getStories() async {
    final rows = await database.select(database.stories).get();
    return rows.map<entity.Story>(_storyFromRow).toList();
  }

  @override
  Future<entity.Story?> getStory(String id) async {
    final row = await (database.select(database.stories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _storyFromRow(row) : null;
  }

  @override
  Future<void> saveStory(entity.Story story) async {
    await database.into(database.stories).insertOnConflictUpdate(
          _storyToCompanion(story),
        );
  }

  @override
  Future<void> saveStories(List<entity.Story> stories) async {
    await database.batch((batch) {
      for (final story in stories) {
        batch.insert(
          database.stories,
          _storyToCompanion(story),
          onConflict: DoUpdate((_) => _storyToCompanion(story)),
        );
      }
    });
  }

  @override
  Future<void> updateStory(entity.Story story) async {
    await (database.update(database.stories)
          ..where((t) => t.id.equals(story.id)))
        .write(_storyToCompanion(story));
  }

  @override
  Future<void> deleteStory(String id) async {
    await (database.delete(database.stories)..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<List<entity.Story>> getPendingStories() async {
    final rows = await (database.select(database.stories)
          ..where(
            (t) => t.syncStatus.equalsValue(SyncStatus.pendingSync),
          ))
        .get();
    return rows.map<entity.Story>(_storyFromRow).toList();
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    await (database.update(database.stories)..where((t) => t.id.equals(id)))
        .write(StoriesCompanion(syncStatus: Value(status)));
  }

  @override
  Future<void> updateLocalAudioPath(
    String id,
    String? path,
    bool isDownloaded,
  ) async {
    await (database.update(database.stories)..where((t) => t.id.equals(id)))
        .write(
      StoriesCompanion(
        localAudioPath: Value(path),
        isDownloaded: Value(isDownloaded),
      ),
    );
  }

  @override
  Stream<List<entity.Story>> watchStories() {
    return database.select(database.stories).watch().map(
          (rows) => rows.map<entity.Story>(_storyFromRow).toList(),
        );
  }

  @override
  Stream<entity.Story?> watchStory(String id) {
    return (database.select(database.stories)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _storyFromRow(row) : null);
  }

  /// Converts a database row to a Story entity.
  entity.Story _storyFromRow(Story row) {
    List<String>? keywords;
    if (row.keywords != null) {
      final decoded = jsonDecode(row.keywords!) as List<dynamic>;
      keywords = decoded.cast<String>();
    }

    return entity.Story(
      id: row.id,
      parentId: row.parentId,
      title: row.title,
      content: row.content,
      source: row.source,
      keywords: keywords,
      wordCount: row.wordCount,
      estimatedDurationMinutes: row.estimatedDurationMinutes,
      audioUrl: row.audioUrl,
      localAudioPath: row.localAudioPath,
      isDownloaded: row.isDownloaded,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      syncStatus: row.syncStatus,
    );
  }

  /// Converts a Story entity to a database companion.
  StoriesCompanion _storyToCompanion(entity.Story story) {
    return StoriesCompanion(
      id: Value(story.id),
      parentId: Value(story.parentId),
      title: Value(story.title),
      content: Value(story.content),
      source: Value(story.source),
      keywords: Value(
        story.keywords != null ? jsonEncode(story.keywords) : null,
      ),
      wordCount: Value(story.wordCount),
      estimatedDurationMinutes: Value(story.estimatedDurationMinutes),
      audioUrl: Value(story.audioUrl),
      localAudioPath: Value(story.localAudioPath),
      isDownloaded: Value(story.isDownloaded),
      createdAt: Value(story.createdAt),
      updatedAt: Value(story.updatedAt),
      syncStatus: Value(story.syncStatus),
    );
  }
}
