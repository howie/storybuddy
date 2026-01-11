import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'enums.dart';

part 'database.g.dart';

/// Parents table - stores parent/user accounts.
class Parents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get email => text().nullable().withLength(max: 255)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Voice profiles table - stores voice clone profiles.
class VoiceProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Parents, #id)();
  TextColumn get name => text().withLength(max: 100)();
  IntColumn get status => intEnum<VoiceProfileStatus>()();
  IntColumn get sampleDurationSeconds => integer().nullable()();
  TextColumn get localAudioPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stories table - stores story content.
class Stories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Parents, #id)();
  TextColumn get title => text().withLength(max: 200)();
  TextColumn get content => text().withLength(max: 5000)();
  IntColumn get source => intEnum<StorySource>()();
  TextColumn get keywords => text().nullable()(); // JSON array
  IntColumn get wordCount => integer()();
  IntColumn get estimatedDurationMinutes => integer().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get localAudioPath => text().nullable()();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Q&A sessions table - stores interactive Q&A sessions.
class QASessions extends Table {
  TextColumn get id => text()();
  TextColumn get storyId => text().references(Stories, #id)();
  IntColumn get status => intEnum<QASessionStatus>()();
  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Q&A messages table - stores individual messages in sessions.
class QAMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(QASessions, #id)();
  IntColumn get role => intEnum<MessageRole>()();
  TextColumn get content => text().withLength(max: 500)();
  BoolColumn get isInScope => boolean().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get localAudioPath => text().nullable()();
  IntColumn get sequence => integer()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending questions table - stores deferred questions for parents.
class PendingQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get storyId => text().references(Stories, #id)();
  TextColumn get question => text().withLength(max: 500)();
  IntColumn get status => intEnum<PendingQuestionStatus>()();
  DateTimeColumn get askedAt => dateTime()();
  DateTimeColumn get answeredAt => dateTime().nullable()();
  IntColumn get syncStatus => intEnum<SyncStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync operations table - tracks pending sync operations for offline support.
class SyncOperations extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get operation => intEnum<SyncOperationType>()();
  TextColumn get payload => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get status => intEnum<SyncOperationStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The main database for the StoryBuddy app.
@DriftDatabase(
  tables: [
    Parents,
    VoiceProfiles,
    Stories,
    QASessions,
    QAMessages,
    PendingQuestions,
    SyncOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Database schema version.
  @override
  int get schemaVersion => 1;

  /// Migration strategy for database upgrades.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Future migrations go here
      },
    );
  }
}

/// Opens a connection to the SQLite database.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'storybuddy.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
