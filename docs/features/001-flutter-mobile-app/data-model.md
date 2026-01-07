# Data Model: Flutter Mobile App

**Branch**: `001-flutter-mobile-app` | **Date**: 2026-01-05

## Overview

This document defines the data model for the StoryBuddy Flutter mobile application. The app-side models mirror the backend API models with additional local state for offline support and UI concerns.

---

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐
│     Parent      │───────│  VoiceProfile   │
│                 │ 1   * │                 │
└─────────────────┘       └─────────────────┘
         │
         │ 1
         │
         │ *
┌────────▼────────┐       ┌─────────────────┐
│     Story       │───────│   QASession     │
│                 │ 1   * │                 │
└─────────────────┘       └────────┬────────┘
         │                         │
         │                         │ 1
         │                         │
         │ *                       │ *
┌────────▼────────┐       ┌────────▼────────┐
│ PendingQuestion │       │    QAMessage    │
│                 │       │                 │
└─────────────────┘       └─────────────────┘

┌─────────────────┐
│   SyncOperation │  (Local only - for offline sync)
│                 │
└─────────────────┘
```

---

## Entities

### 1. Parent

The parent/user account that owns voice profiles and stories.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| name | String | max 100 chars | Display name |
| email | String? | max 255 chars | Optional email |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL | Last update timestamp |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Validation Rules:**
- name: Required, 1-100 characters
- email: Optional, valid email format if provided

---

### 2. VoiceProfile

A voice clone profile created from parent's voice recording.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| parentId | String (UUID) | FK → Parent | Owner parent |
| name | String | max 100 chars | Profile name (e.g., "爸爸", "媽媽") |
| status | VoiceProfileStatus | ENUM | Cloning status |
| sampleDurationSeconds | int? | 30-180 | Sample duration in seconds |
| localAudioPath | String? | - | Local path to voice sample (local only) |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL | Last update timestamp |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Enums:**
```dart
enum VoiceProfileStatus {
  pending,    // Waiting for upload
  processing, // Voice model being created
  ready,      // Ready to use
  failed,     // Creation failed
}
```

**State Transitions:**
```
pending → processing → ready
                    ↘ failed → pending (retry)
```

**Validation Rules:**
- name: Required, 1-100 characters
- sampleDurationSeconds: 30-180 seconds when provided

---

### 3. Story

A story that can be narrated using the cloned voice.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| parentId | String (UUID) | FK → Parent | Owner parent |
| title | String | max 200 chars | Story title |
| content | String | max 5000 chars | Story text content |
| source | StorySource | ENUM | Content source |
| keywords | List<String>? | - | AI generation keywords |
| wordCount | int | max 5000 | Character count |
| estimatedDurationMinutes | int? | - | Reading time estimate |
| audioUrl | String? | - | Remote audio URL |
| localAudioPath | String? | - | Cached audio path (local only) |
| isDownloaded | bool | default false | Offline available (local only) |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL | Last update timestamp |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Enums:**
```dart
enum StorySource {
  imported,     // Parent imported text
  aiGenerated,  // AI generated story
}
```

**Validation Rules:**
- title: Required, 1-200 characters
- content: Required, 1-5000 characters
- wordCount: Auto-calculated from content

---

### 4. QASession

An interactive Q&A session after story playback.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| storyId | String (UUID) | FK → Story | Related story |
| status | QASessionStatus | ENUM | Session status |
| messageCount | int | max 10 | Number of messages |
| startedAt | DateTime | NOT NULL | Session start time |
| endedAt | DateTime? | - | Session end time |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Enums:**
```dart
enum QASessionStatus {
  active,     // In progress
  completed,  // Normally ended
  timeout,    // Timed out
}
```

**State Transitions:**
```
active → completed
      ↘ timeout
```

**Validation Rules:**
- messageCount: Maximum 10 messages (5 exchanges)

---

### 5. QAMessage

A single message in a Q&A session.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| sessionId | String (UUID) | FK → QASession | Parent session |
| role | MessageRole | ENUM | Sender role |
| content | String | max 500 chars | Message text |
| isInScope | bool? | - | Question in story scope |
| audioUrl | String? | - | Audio response URL |
| localAudioPath | String? | - | Cached audio path (local only) |
| sequence | int | NOT NULL | Message order |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Enums:**
```dart
enum MessageRole {
  child,      // Child's question
  assistant,  // AI response
}
```

---

### 6. PendingQuestion

Questions outside story scope, deferred to parents.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| storyId | String (UUID) | FK → Story | Related story |
| question | String | max 500 chars | Question text |
| status | PendingQuestionStatus | ENUM | Answer status |
| askedAt | DateTime | NOT NULL | When question was asked |
| answeredAt | DateTime? | - | When parent answered |
| syncStatus | SyncStatus | NOT NULL | Sync state (local only) |

**Enums:**
```dart
enum PendingQuestionStatus {
  pending,   // Awaiting parent answer
  answered,  // Parent has answered
}
```

---

### 7. SyncOperation (Local Only)

Tracks pending sync operations for offline-first architecture.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | String (UUID) | PK | Unique identifier |
| entityType | String | NOT NULL | Entity type (story, voice_profile, etc.) |
| entityId | String (UUID) | NOT NULL | Entity ID |
| operation | SyncOperationType | ENUM | Operation type |
| payload | String | - | JSON serialized data |
| retryCount | int | default 0 | Number of retry attempts |
| status | SyncOperationStatus | ENUM | Operation status |
| createdAt | DateTime | NOT NULL | When queued |
| lastAttemptAt | DateTime? | - | Last sync attempt |

**Enums:**
```dart
enum SyncOperationType {
  create,
  update,
  delete,
}

enum SyncOperationStatus {
  pending,
  inProgress,
  completed,
  failed,
}

enum SyncStatus {
  synced,      // Synced with server
  pendingSync, // Local changes pending
  syncFailed,  // Sync failed
}
```

---

## Local-Only Fields

The following fields exist only in the local database and are not synced with the backend:

| Entity | Field | Purpose |
|--------|-------|---------|
| VoiceProfile | localAudioPath | Local voice recording file path |
| Story | localAudioPath | Cached story audio file path |
| Story | isDownloaded | Tracks offline availability |
| QAMessage | localAudioPath | Cached response audio |
| All entities | syncStatus | Offline sync tracking |

---

## Drift Schema (Dart)

```dart
// Enums
enum VoiceProfileStatus { pending, processing, ready, failed }
enum StorySource { imported, aiGenerated }
enum QASessionStatus { active, completed, timeout }
enum MessageRole { child, assistant }
enum PendingQuestionStatus { pending, answered }
enum SyncStatus { synced, pendingSync, syncFailed }
enum SyncOperationType { create, update, delete }
enum SyncOperationStatus { pending, inProgress, completed, failed }

// Tables
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
```

---

## Freezed Models (Domain Layer)

```dart
@freezed
class Parent with _$Parent {
  const factory Parent({
    required String id,
    required String name,
    String? email,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _Parent;
}

@freezed
class VoiceProfile with _$VoiceProfile {
  const factory VoiceProfile({
    required String id,
    required String parentId,
    required String name,
    required VoiceProfileStatus status,
    int? sampleDurationSeconds,
    String? localAudioPath,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _VoiceProfile;
}

@freezed
class Story with _$Story {
  const factory Story({
    required String id,
    required String parentId,
    required String title,
    required String content,
    required StorySource source,
    List<String>? keywords,
    required int wordCount,
    int? estimatedDurationMinutes,
    String? audioUrl,
    String? localAudioPath,
    @Default(false) bool isDownloaded,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _Story;
}

// ... similar for other entities
```

---

## Data Flow

### Create Story (Offline-First)

```
1. User creates story in app
2. Save to local Drift DB with syncStatus = pendingSync
3. Create SyncOperation record
4. Return immediately (optimistic)
5. Background: Process sync queue when online
6. On success: Update syncStatus = synced
7. On failure: Increment retry count, keep pendingSync
```

### Load Stories (Local-First)

```
1. Query local Drift DB immediately
2. Return cached data to UI
3. If online: Fetch from API in background
4. Merge remote changes into local DB
5. Stream updates to UI automatically
```
