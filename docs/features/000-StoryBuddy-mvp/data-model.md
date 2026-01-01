# Data Model: StoryBuddy MVP

**Branch**: `000-StoryBuddy-mvp` | **Date**: 2026-01-01

## Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   Parent    │──────<│   Story     │──────<│  QASession  │
│             │ 1:N   │             │ 1:N   │             │
└─────────────┘       └─────────────┘       └─────────────┘
      │                     │                     │
      │ 1:1                 │                     │ 1:N
      ▼                     │                     ▼
┌─────────────┐             │              ┌─────────────┐
│VoiceProfile │             │              │  QAMessage  │
└─────────────┘             │              └─────────────┘
      │                     │
      │ 1:N                 │ 1:N
      ▼                     ▼
┌─────────────┐       ┌─────────────┐
│ VoiceAudio  │       │PendingQuestion│
└─────────────┘       └─────────────┘
```

---

## Entities

### 1. Parent (家長)

代表應用程式的主要使用者 - 家長。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| name | VARCHAR(100) | NOT NULL | 家長名稱 |
| email | VARCHAR(255) | UNIQUE, NULL | Email（可選，用於未來帳號功能）|
| created_at | TIMESTAMP | NOT NULL | 建立時間 |
| updated_at | TIMESTAMP | NOT NULL | 更新時間 |

**MVP Note**: MVP 階段可能不需要完整的帳號系統，可使用設備 ID 區分。

---

### 2. VoiceProfile (聲音模型)

儲存家長的聲音克隆模型資訊。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| parent_id | UUID | FK → Parent, NOT NULL | 所屬家長 |
| name | VARCHAR(100) | NOT NULL | 聲音名稱（如「爸爸」「媽媽」）|
| elevenlabs_voice_id | VARCHAR(100) | NULL | ElevenLabs Voice ID |
| status | ENUM | NOT NULL | 狀態：pending, processing, ready, failed |
| sample_duration_seconds | INTEGER | NULL | 錄音樣本長度（秒）|
| created_at | TIMESTAMP | NOT NULL | 建立時間 |
| updated_at | TIMESTAMP | NOT NULL | 更新時間 |

**Status State Machine**:
```
pending ──(upload)──> processing ──(success)──> ready
                           │
                           └──(failure)──> failed
```

**Validation Rules**:
- sample_duration_seconds >= 30 (最少 30 秒)
- sample_duration_seconds <= 180 (最多 3 分鐘)

---

### 3. VoiceAudio (聲音錄音檔)

儲存家長錄製的原始語音檔案資訊。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| voice_profile_id | UUID | FK → VoiceProfile, NOT NULL | 所屬聲音模型 |
| file_path | VARCHAR(500) | NOT NULL | 本地檔案路徑 |
| file_size_bytes | INTEGER | NOT NULL | 檔案大小 |
| duration_seconds | INTEGER | NOT NULL | 錄音長度（秒）|
| format | VARCHAR(20) | NOT NULL | 音訊格式（wav, mp3, m4a）|
| created_at | TIMESTAMP | NOT NULL | 建立時間 |

---

### 4. Story (故事)

儲存故事內容，可以是匯入的或 AI 生成的。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| parent_id | UUID | FK → Parent, NOT NULL | 所屬家長 |
| title | VARCHAR(200) | NOT NULL | 故事標題 |
| content | TEXT | NOT NULL | 故事內容 |
| source | ENUM | NOT NULL | 來源：imported, ai_generated |
| keywords | TEXT | NULL | 生成關鍵字（JSON array）|
| word_count | INTEGER | NOT NULL | 字數 |
| estimated_duration_minutes | INTEGER | NULL | 預估講述時間 |
| audio_file_path | VARCHAR(500) | NULL | 生成的語音檔案路徑 |
| audio_generated_at | TIMESTAMP | NULL | 語音生成時間 |
| created_at | TIMESTAMP | NOT NULL | 建立時間 |
| updated_at | TIMESTAMP | NOT NULL | 更新時間 |

**Validation Rules**:
- word_count <= 5000 (單個故事最多 5000 字)
- 匯入故事過長需分章節

**Computed Fields**:
- estimated_duration_minutes ≈ word_count / 200 (假設每分鐘朗讀 200 字)

---

### 5. QASession (問答對話)

代表一次故事後的問答互動。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| story_id | UUID | FK → Story, NOT NULL | 關聯的故事 |
| started_at | TIMESTAMP | NOT NULL | 開始時間 |
| ended_at | TIMESTAMP | NULL | 結束時間 |
| message_count | INTEGER | NOT NULL, DEFAULT 0 | 訊息數量 |
| status | ENUM | NOT NULL | 狀態：active, completed, timeout |

**Validation Rules**:
- message_count <= 10 (每次問答最多 10 個問題)

---

### 6. QAMessage (問答訊息)

問答對話中的單條訊息。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| session_id | UUID | FK → QASession, NOT NULL | 所屬對話 |
| role | ENUM | NOT NULL | 角色：child, assistant |
| content | TEXT | NOT NULL | 訊息內容 |
| is_in_scope | BOOLEAN | NULL | 是否在故事範圍內（僅 child 訊息）|
| audio_input_path | VARCHAR(500) | NULL | 語音輸入檔案路徑（僅 child）|
| audio_output_path | VARCHAR(500) | NULL | 語音回應檔案路徑（僅 assistant）|
| created_at | TIMESTAMP | NOT NULL | 建立時間 |
| sequence | INTEGER | NOT NULL | 訊息順序 |

---

### 7. PendingQuestion (待回答問題)

儲存小朋友問的超出故事範圍的問題。

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | 唯一識別碼 |
| parent_id | UUID | FK → Parent, NOT NULL | 所屬家長 |
| story_id | UUID | FK → Story, NULL | 關聯故事（可選）|
| question | TEXT | NOT NULL | 問題內容 |
| asked_at | TIMESTAMP | NOT NULL | 提問時間 |
| answer | TEXT | NULL | 家長回答 |
| answer_audio_path | VARCHAR(500) | NULL | 家長語音回答路徑 |
| answered_at | TIMESTAMP | NULL | 回答時間 |
| status | ENUM | NOT NULL | 狀態：pending, answered |

---

## Enums

### VoiceProfileStatus
```python
class VoiceProfileStatus(str, Enum):
    PENDING = "pending"          # 等待上傳
    PROCESSING = "processing"    # 聲音模型建立中
    READY = "ready"              # 可使用
    FAILED = "failed"            # 建立失敗
```

### StorySource
```python
class StorySource(str, Enum):
    IMPORTED = "imported"        # 家長匯入
    AI_GENERATED = "ai_generated"  # AI 生成
```

### QASessionStatus
```python
class QASessionStatus(str, Enum):
    ACTIVE = "active"            # 進行中
    COMPLETED = "completed"      # 正常結束
    TIMEOUT = "timeout"          # 超時結束
```

### MessageRole
```python
class MessageRole(str, Enum):
    CHILD = "child"              # 小朋友訊息
    ASSISTANT = "assistant"      # AI 回應
```

### PendingQuestionStatus
```python
class PendingQuestionStatus(str, Enum):
    PENDING = "pending"          # 待回答
    ANSWERED = "answered"        # 已回答
```

---

## Indexes

### VoiceProfile
- `idx_voice_profile_parent_id` ON (parent_id)
- `idx_voice_profile_status` ON (status)

### Story
- `idx_story_parent_id` ON (parent_id)
- `idx_story_source` ON (source)
- `idx_story_created_at` ON (created_at DESC)

### QASession
- `idx_qa_session_story_id` ON (story_id)
- `idx_qa_session_started_at` ON (started_at DESC)

### QAMessage
- `idx_qa_message_session_id_sequence` ON (session_id, sequence)

### PendingQuestion
- `idx_pending_question_parent_id_status` ON (parent_id, status)
- `idx_pending_question_asked_at` ON (asked_at DESC)

---

## SQLite Schema (MVP)

```sql
-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- Parent
CREATE TABLE parent (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- VoiceProfile
CREATE TABLE voice_profile (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    elevenlabs_voice_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'failed')),
    sample_duration_seconds INTEGER CHECK (sample_duration_seconds >= 30 AND sample_duration_seconds <= 180),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_voice_profile_parent_id ON voice_profile(parent_id);
CREATE INDEX idx_voice_profile_status ON voice_profile(status);

-- VoiceAudio
CREATE TABLE voice_audio (
    id TEXT PRIMARY KEY,
    voice_profile_id TEXT NOT NULL REFERENCES voice_profile(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    duration_seconds INTEGER NOT NULL,
    format TEXT NOT NULL CHECK (format IN ('wav', 'mp3', 'm4a')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Story
CREATE TABLE story (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('imported', 'ai_generated')),
    keywords TEXT,  -- JSON array
    word_count INTEGER NOT NULL CHECK (word_count <= 5000),
    estimated_duration_minutes INTEGER,
    audio_file_path TEXT,
    audio_generated_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_story_parent_id ON story(parent_id);
CREATE INDEX idx_story_source ON story(source);
CREATE INDEX idx_story_created_at ON story(created_at DESC);

-- QASession
CREATE TABLE qa_session (
    id TEXT PRIMARY KEY,
    story_id TEXT NOT NULL REFERENCES story(id) ON DELETE CASCADE,
    started_at TEXT NOT NULL DEFAULT (datetime('now')),
    ended_at TEXT,
    message_count INTEGER NOT NULL DEFAULT 0 CHECK (message_count <= 10),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'timeout'))
);

CREATE INDEX idx_qa_session_story_id ON qa_session(story_id);
CREATE INDEX idx_qa_session_started_at ON qa_session(started_at DESC);

-- QAMessage
CREATE TABLE qa_message (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES qa_session(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('child', 'assistant')),
    content TEXT NOT NULL,
    is_in_scope INTEGER,  -- SQLite doesn't have boolean, use 0/1
    audio_input_path TEXT,
    audio_output_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    sequence INTEGER NOT NULL
);

CREATE INDEX idx_qa_message_session_id_sequence ON qa_message(session_id, sequence);

-- PendingQuestion
CREATE TABLE pending_question (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    story_id TEXT REFERENCES story(id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    asked_at TEXT NOT NULL DEFAULT (datetime('now')),
    answer TEXT,
    answer_audio_path TEXT,
    answered_at TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'answered'))
);

CREATE INDEX idx_pending_question_parent_id_status ON pending_question(parent_id, status);
CREATE INDEX idx_pending_question_asked_at ON pending_question(asked_at DESC);
```

---

## Pydantic Models (Python)

```python
from datetime import datetime
from typing import Optional, List
from enum import Enum
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class VoiceProfileStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    READY = "ready"
    FAILED = "failed"


class StorySource(str, Enum):
    IMPORTED = "imported"
    AI_GENERATED = "ai_generated"


class QASessionStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    TIMEOUT = "timeout"


class MessageRole(str, Enum):
    CHILD = "child"
    ASSISTANT = "assistant"


class PendingQuestionStatus(str, Enum):
    PENDING = "pending"
    ANSWERED = "answered"


# ========== Parent ==========
class ParentBase(BaseModel):
    name: str = Field(..., max_length=100)
    email: Optional[str] = Field(None, max_length=255)


class ParentCreate(ParentBase):
    pass


class Parent(ParentBase):
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ========== VoiceProfile ==========
class VoiceProfileBase(BaseModel):
    name: str = Field(..., max_length=100)


class VoiceProfileCreate(VoiceProfileBase):
    parent_id: UUID


class VoiceProfile(VoiceProfileBase):
    id: UUID = Field(default_factory=uuid4)
    parent_id: UUID
    elevenlabs_voice_id: Optional[str] = None
    status: VoiceProfileStatus = VoiceProfileStatus.PENDING
    sample_duration_seconds: Optional[int] = Field(None, ge=30, le=180)
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ========== Story ==========
class StoryBase(BaseModel):
    title: str = Field(..., max_length=200)
    content: str


class StoryCreate(StoryBase):
    parent_id: UUID
    source: StorySource
    keywords: Optional[List[str]] = None


class Story(StoryBase):
    id: UUID = Field(default_factory=uuid4)
    parent_id: UUID
    source: StorySource
    keywords: Optional[List[str]] = None
    word_count: int = Field(..., le=5000)
    estimated_duration_minutes: Optional[int] = None
    audio_file_path: Optional[str] = None
    audio_generated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ========== QASession ==========
class QASessionCreate(BaseModel):
    story_id: UUID


class QASession(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    story_id: UUID
    started_at: datetime
    ended_at: Optional[datetime] = None
    message_count: int = Field(0, le=10)
    status: QASessionStatus = QASessionStatus.ACTIVE

    class Config:
        from_attributes = True


# ========== QAMessage ==========
class QAMessageCreate(BaseModel):
    session_id: UUID
    role: MessageRole
    content: str
    is_in_scope: Optional[bool] = None


class QAMessage(QAMessageCreate):
    id: UUID = Field(default_factory=uuid4)
    audio_input_path: Optional[str] = None
    audio_output_path: Optional[str] = None
    created_at: datetime
    sequence: int

    class Config:
        from_attributes = True


# ========== PendingQuestion ==========
class PendingQuestionCreate(BaseModel):
    parent_id: UUID
    story_id: Optional[UUID] = None
    question: str


class PendingQuestion(PendingQuestionCreate):
    id: UUID = Field(default_factory=uuid4)
    asked_at: datetime
    answer: Optional[str] = None
    answer_audio_path: Optional[str] = None
    answered_at: Optional[datetime] = None
    status: PendingQuestionStatus = PendingQuestionStatus.PENDING

    class Config:
        from_attributes = True
```

---

## File Storage Structure

```
data/
├── audio/
│   ├── voice_samples/         # 家長錄音樣本
│   │   └── {voice_profile_id}/
│   │       └── sample_{timestamp}.wav
│   ├── stories/               # 生成的故事語音
│   │   └── {story_id}/
│   │       └── story.mp3
│   ├── qa_responses/          # AI 問答語音回應
│   │   └── {session_id}/
│   │       └── {message_id}.mp3
│   └── parent_answers/        # 家長回答錄音
│       └── {pending_question_id}.mp3
└── db/
    └── storybuddy.db          # SQLite 資料庫
```
