# Data Model: Interactive Story Mode

**Date**: 2026-01-10
**Feature**: 006-interactive-story-mode

## Entity Relationship Diagram

```
┌─────────────────────┐      ┌─────────────────────┐
│      Story          │      │      Parent         │
│─────────────────────│      │─────────────────────│
│ id: UUID (PK)       │      │ id: UUID (PK)       │
│ title: String       │      │ email: String       │
│ content: Text       │      │ ...                 │
└─────────┬───────────┘      └─────────┬───────────┘
          │                            │
          │ 1                          │ 1
          │                            │
          ▼ *                          ▼ 1
┌─────────────────────┐      ┌─────────────────────────────┐
│ InteractionSession  │◄─────│   InteractionSettings       │
│─────────────────────│      │─────────────────────────────│
│ id: UUID (PK)       │      │ id: UUID (PK)               │
│ story_id: UUID (FK) │      │ parent_id: UUID (FK)        │
│ parent_id: UUID(FK) │      │ recording_enabled: Boolean  │
│ started_at: DateTime│      │ email_notifications: Boolean│
│ ended_at: DateTime? │      │ notification_frequency: Enum│
│ mode: Enum          │      │ interruption_threshold_ms:  │
│ noise_calibration   │      │   Integer                   │
│ status: Enum        │      └─────────────────────────────┘
└─────────┬───────────┘
          │
          │ 1
          │
          ▼ *
┌─────────────────────┐      ┌─────────────────────┐
│    VoiceSegment     │      │     AIResponse      │
│─────────────────────│      │─────────────────────│
│ id: UUID (PK)       │      │ id: UUID (PK)       │
│ session_id: UUID(FK)│◄────►│ session_id: UUID(FK)│
│ sequence: Integer   │      │ voice_segment_id:   │
│ started_at: DateTime│      │   UUID (FK)?        │
│ ended_at: DateTime  │      │ text: Text          │
│ transcript: Text?   │      │ audio_url: String?  │
│ audio_url: String?  │      │ trigger_type: Enum  │
│ is_recorded: Boolean│      │ was_interrupted:    │
│ audio_format: String│      │   Boolean           │
└─────────────────────┘      │ created_at: DateTime│
                             └─────────────────────┘

┌─────────────────────────────┐
│   InteractionTranscript     │
│─────────────────────────────│
│ id: UUID (PK)               │
│ session_id: UUID (FK)       │
│ plain_text: Text            │
│ html_content: Text          │
│ created_at: DateTime        │
│ email_sent_at: DateTime?    │
└─────────────────────────────┘

┌─────────────────────────────┐
│     NoiseCalibration        │
│─────────────────────────────│
│ id: UUID (PK)               │
│ session_id: UUID (FK)       │
│ noise_floor_db: Float       │
│ calibrated_at: DateTime     │
│ sample_count: Integer       │
│ percentile_90: Float        │
└─────────────────────────────┘
```

## Entities

### InteractionSession

代表一次互動式講故事的會話。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| story_id | UUID | FK → Story | 關聯的故事 |
| parent_id | UUID | FK → Parent | 關聯的家長 |
| started_at | DateTime | NOT NULL | 開始時間 |
| ended_at | DateTime | NULL | 結束時間（進行中為 NULL） |
| mode | Enum | NOT NULL | 'interactive' \| 'passive' |
| status | Enum | NOT NULL | 'calibrating' \| 'active' \| 'paused' \| 'completed' \| 'error' |
| created_at | DateTime | NOT NULL | 建立時間 |
| updated_at | DateTime | NOT NULL | 更新時間 |

**Validation Rules**:
- `ended_at` 必須大於 `started_at`（當不為 NULL 時）
- `status` 只能依序轉換：calibrating → active → (paused ↔ active) → completed

**State Transitions**:
```
calibrating → active → completed
                ↑↓
              paused
```

---

### VoiceSegment

代表孩子說的一段語音。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| session_id | UUID | FK → InteractionSession | 關聯的會話 |
| sequence | Integer | NOT NULL | 在會話中的順序（從 1 開始） |
| started_at | DateTime | NOT NULL | 語音開始時間 |
| ended_at | DateTime | NOT NULL | 語音結束時間 |
| transcript | Text | NULL | 語音辨識結果（辨識完成後填入） |
| audio_url | String | NULL | 錄音檔案 URL（僅當 is_recorded=true） |
| is_recorded | Boolean | NOT NULL, DEFAULT false | 是否有錄音檔 |
| audio_format | String | NOT NULL, DEFAULT 'opus' | 音訊格式 |
| duration_ms | Integer | NOT NULL | 語音持續時間（毫秒） |
| created_at | DateTime | NOT NULL | 建立時間 |

**Validation Rules**:
- `ended_at` > `started_at`
- `duration_ms` = `ended_at` - `started_at`（毫秒）
- `sequence` 在同一 session 內唯一且連續

---

### AIResponse

代表 AI 的一次回應。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| session_id | UUID | FK → InteractionSession | 關聯的會話 |
| voice_segment_id | UUID | FK → VoiceSegment, NULL | 觸發此回應的語音片段 |
| text | Text | NOT NULL | AI 回應的文字內容 |
| audio_url | String | NULL | TTS 生成的語音 URL |
| trigger_type | Enum | NOT NULL | 'child_speech' \| 'story_prompt' \| 'timeout' |
| was_interrupted | Boolean | NOT NULL, DEFAULT false | 回應是否被中斷 |
| interrupted_at_ms | Integer | NULL | 被中斷時已播放的毫秒數 |
| response_latency_ms | Integer | NOT NULL | 從觸發到開始回應的延遲（毫秒） |
| created_at | DateTime | NOT NULL | 建立時間 |

**Validation Rules**:
- 當 `trigger_type` = 'child_speech' 時，`voice_segment_id` 不能為 NULL
- 當 `was_interrupted` = true 時，`interrupted_at_ms` 不能為 NULL

---

### InteractionTranscript

代表完整的互動紀錄。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| session_id | UUID | FK → InteractionSession, UNIQUE | 關聯的會話（一對一） |
| plain_text | Text | NOT NULL | 純文字格式的對話紀錄 |
| html_content | Text | NOT NULL | HTML 格式的對話紀錄 |
| turn_count | Integer | NOT NULL | 對話輪次數量 |
| total_duration_ms | Integer | NOT NULL | 總互動時間（毫秒） |
| created_at | DateTime | NOT NULL | 建立時間 |
| email_sent_at | DateTime | NULL | 郵件發送時間 |

**Validation Rules**:
- `plain_text` 和 `html_content` 不能為空字串

---

### InteractionSettings

家長的互動模式偏好設定。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| parent_id | UUID | FK → Parent, UNIQUE | 關聯的家長（一對一） |
| recording_enabled | Boolean | NOT NULL, DEFAULT false | 是否錄製對話 |
| email_notifications | Boolean | NOT NULL, DEFAULT true | 是否接收郵件通知 |
| notification_email | String | NULL | 接收通知的郵件地址（NULL 使用帳戶郵件） |
| notification_frequency | Enum | NOT NULL, DEFAULT 'daily' | 'instant' \| 'daily' \| 'weekly' |
| interruption_threshold_ms | Integer | NOT NULL, DEFAULT 500 | 中斷判定閾值（毫秒） |
| created_at | DateTime | NOT NULL | 建立時間 |
| updated_at | DateTime | NOT NULL | 更新時間 |

**Validation Rules**:
- `interruption_threshold_ms` 必須在 200-2000 範圍內
- 當 `email_notifications` = true 且 `notification_email` = NULL 時，使用 Parent.email

---

### NoiseCalibration

環境噪音校準資料。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | 唯一識別碼 |
| session_id | UUID | FK → InteractionSession, UNIQUE | 關聯的會話（一對一） |
| noise_floor_db | Float | NOT NULL | 噪音底線（dB） |
| calibrated_at | DateTime | NOT NULL | 校準完成時間 |
| sample_count | Integer | NOT NULL | 採樣數量 |
| percentile_90 | Float | NOT NULL | 90th 百分位數值 |
| calibration_duration_ms | Integer | NOT NULL | 校準耗時（毫秒） |

**Validation Rules**:
- `noise_floor_db` 通常在 -60 到 -20 dB 範圍
- `sample_count` > 0

---

## Enums

### SessionMode
```python
class SessionMode(str, Enum):
    INTERACTIVE = "interactive"
    PASSIVE = "passive"
```

### SessionStatus
```python
class SessionStatus(str, Enum):
    CALIBRATING = "calibrating"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    ERROR = "error"
```

### TriggerType
```python
class TriggerType(str, Enum):
    CHILD_SPEECH = "child_speech"
    STORY_PROMPT = "story_prompt"  # Future: template-based prompts
    TIMEOUT = "timeout"
```

### NotificationFrequency
```python
class NotificationFrequency(str, Enum):
    INSTANT = "instant"
    DAILY = "daily"
    WEEKLY = "weekly"
```

---

## Database Migrations

### Backend (SQLAlchemy/Alembic)

```python
# migrations/versions/006_add_interaction_tables.py

def upgrade():
    # InteractionSession
    op.create_table(
        'interaction_sessions',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('story_id', sa.UUID(), sa.ForeignKey('stories.id'), nullable=False),
        sa.Column('parent_id', sa.UUID(), sa.ForeignKey('parents.id'), nullable=False),
        sa.Column('started_at', sa.DateTime(), nullable=False),
        sa.Column('ended_at', sa.DateTime(), nullable=True),
        sa.Column('mode', sa.String(20), nullable=False),
        sa.Column('status', sa.String(20), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # VoiceSegment
    op.create_table(
        'voice_segments',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('session_id', sa.UUID(), sa.ForeignKey('interaction_sessions.id'), nullable=False),
        sa.Column('sequence', sa.Integer(), nullable=False),
        sa.Column('started_at', sa.DateTime(), nullable=False),
        sa.Column('ended_at', sa.DateTime(), nullable=False),
        sa.Column('transcript', sa.Text(), nullable=True),
        sa.Column('audio_url', sa.String(500), nullable=True),
        sa.Column('is_recorded', sa.Boolean(), nullable=False, default=False),
        sa.Column('audio_format', sa.String(20), nullable=False, default='opus'),
        sa.Column('duration_ms', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # AIResponse
    op.create_table(
        'ai_responses',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('session_id', sa.UUID(), sa.ForeignKey('interaction_sessions.id'), nullable=False),
        sa.Column('voice_segment_id', sa.UUID(), sa.ForeignKey('voice_segments.id'), nullable=True),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('audio_url', sa.String(500), nullable=True),
        sa.Column('trigger_type', sa.String(20), nullable=False),
        sa.Column('was_interrupted', sa.Boolean(), nullable=False, default=False),
        sa.Column('interrupted_at_ms', sa.Integer(), nullable=True),
        sa.Column('response_latency_ms', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # InteractionTranscript
    op.create_table(
        'interaction_transcripts',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('session_id', sa.UUID(), sa.ForeignKey('interaction_sessions.id'), unique=True, nullable=False),
        sa.Column('plain_text', sa.Text(), nullable=False),
        sa.Column('html_content', sa.Text(), nullable=False),
        sa.Column('turn_count', sa.Integer(), nullable=False),
        sa.Column('total_duration_ms', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('email_sent_at', sa.DateTime(), nullable=True),
    )

    # InteractionSettings
    op.create_table(
        'interaction_settings',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('parent_id', sa.UUID(), sa.ForeignKey('parents.id'), unique=True, nullable=False),
        sa.Column('recording_enabled', sa.Boolean(), nullable=False, default=False),
        sa.Column('email_notifications', sa.Boolean(), nullable=False, default=True),
        sa.Column('notification_email', sa.String(255), nullable=True),
        sa.Column('notification_frequency', sa.String(20), nullable=False, default='daily'),
        sa.Column('interruption_threshold_ms', sa.Integer(), nullable=False, default=500),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # NoiseCalibration
    op.create_table(
        'noise_calibrations',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('session_id', sa.UUID(), sa.ForeignKey('interaction_sessions.id'), unique=True, nullable=False),
        sa.Column('noise_floor_db', sa.Float(), nullable=False),
        sa.Column('calibrated_at', sa.DateTime(), nullable=False),
        sa.Column('sample_count', sa.Integer(), nullable=False),
        sa.Column('percentile_90', sa.Float(), nullable=False),
        sa.Column('calibration_duration_ms', sa.Integer(), nullable=False),
    )

def downgrade():
    op.drop_table('noise_calibrations')
    op.drop_table('interaction_settings')
    op.drop_table('interaction_transcripts')
    op.drop_table('ai_responses')
    op.drop_table('voice_segments')
    op.drop_table('interaction_sessions')
```

### Frontend (Drift)

```dart
// lib/core/database/tables/interaction_tables.dart

class InteractionSessions extends Table {
  TextColumn get id => text()();
  TextColumn get storyId => text().references(Stories, #id)();
  TextColumn get parentId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get mode => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

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

// ... similar for other tables
```

---

## Indexes

```sql
-- Performance indexes
CREATE INDEX idx_interaction_sessions_story_id ON interaction_sessions(story_id);
CREATE INDEX idx_interaction_sessions_parent_id ON interaction_sessions(parent_id);
CREATE INDEX idx_interaction_sessions_status ON interaction_sessions(status);
CREATE INDEX idx_voice_segments_session_id ON voice_segments(session_id);
CREATE INDEX idx_ai_responses_session_id ON ai_responses(session_id);
CREATE INDEX idx_interaction_transcripts_email_sent_at ON interaction_transcripts(email_sent_at);
```
