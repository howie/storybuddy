import 'package:drift/drift.dart';

/// Drift table for InteractionSession.
///
/// Represents a single interactive storytelling session.
class InteractionSessions extends Table {
  TextColumn get id => text()();
  TextColumn get storyId => text()();
  TextColumn get parentId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get mode => text()(); // 'interactive' | 'passive'
  TextColumn get status =>
      text()(); // 'calibrating' | 'active' | 'paused' | 'completed' | 'error'
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for VoiceSegment.
///
/// Represents a segment of child speech during interaction.
class VoiceSegments extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(InteractionSessions, #id)();
  IntColumn get sequence => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get transcript => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  BoolColumn get isRecorded => boolean().withDefault(const Constant(false))();
  TextColumn get audioFormat => text().withDefault(const Constant('opus'))();
  IntColumn get durationMs => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for AIResponse.
///
/// Represents an AI response during interaction.
class AIResponses extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(InteractionSessions, #id)();
  TextColumn get voiceSegmentId =>
      text().nullable().references(VoiceSegments, #id)();
  TextColumn get responseText => text()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get triggerType =>
      text()(); // 'child_speech' | 'story_prompt' | 'timeout'
  BoolColumn get wasInterrupted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get interruptedAtMs => integer().nullable()();
  IntColumn get responseLatencyMs => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'ai_responses';
}

/// Drift table for InteractionTranscript.
///
/// Complete interaction transcript for a session.
class InteractionTranscripts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().unique().references(InteractionSessions, #id)();
  TextColumn get plainText => text()();
  TextColumn get htmlContent => text()();
  IntColumn get turnCount => integer()();
  IntColumn get totalDurationMs => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get emailSentAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for InteractionSettings.
///
/// Parent's interaction mode preferences.
class InteractionSettingsTable extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().unique()();
  BoolColumn get recordingEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get emailNotifications =>
      boolean().withDefault(const Constant(true))();
  TextColumn get notificationEmail => text().nullable()();
  TextColumn get notificationFrequency => text()
      .withDefault(const Constant('daily'))(); // 'instant' | 'daily' | 'weekly'
  IntColumn get interruptionThresholdMs =>
      integer().withDefault(const Constant(500))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'interaction_settings';
}

/// Drift table for NoiseCalibration.
///
/// Environment noise calibration data for a session.
class NoiseCalibrations extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().unique().references(InteractionSessions, #id)();
  RealColumn get noiseFloorDb => real()();
  DateTimeColumn get calibratedAt => dateTime()();
  IntColumn get sampleCount => integer()();
  RealColumn get percentile90 => real()();
  IntColumn get calibrationDurationMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
