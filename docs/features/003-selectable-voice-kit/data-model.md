# Data Model: Selectable Voice Kit

**Feature**: 003-selectable-voice-kit
**Date**: 2026-01-05

## Entity Relationship Diagram

```
┌─────────────────────┐       ┌─────────────────────┐
│     VoiceKit        │       │   VoiceCharacter    │
├─────────────────────┤       ├─────────────────────┤
│ id: str (PK)        │◄──────│ id: str (PK)        │
│ name: str           │  1:N  │ kit_id: str (FK)    │
│ description: str    │       │ name: str           │
│ provider: str       │       │ provider_voice_id   │
│ version: str        │       │ ssml_options: json  │
│ download_size: int  │       │ gender: str         │
│ is_builtin: bool    │       │ age_group: str      │
│ is_downloaded: bool │       │ style: str          │
│ created_at: datetime│       │ preview_url: str    │
└─────────────────────┘       │ preview_text: str   │
                              └─────────────────────┘
                                        │
                                        │ 1:N
                                        ▼
┌─────────────────────┐       ┌─────────────────────┐
│  VoicePreference    │       │   StoryVoiceMap     │
├─────────────────────┤       ├─────────────────────┤
│ user_id: str (PK)   │◄──────│ story_id: str (PK)  │
│ default_voice_id    │  1:N  │ user_id: str (PK)   │
│ updated_at: datetime│       │ role: str           │
└─────────────────────┘       │ voice_id: str       │
                              └─────────────────────┘
```

## Entities

### VoiceKit

Represents a collection of related voices (e.g., "Built-in Voices", "Adventure Pack").

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | string | PK, UUID | Unique identifier |
| name | string | required, max 100 | Display name (e.g., "內建角色") |
| description | string | max 500 | Kit description |
| provider | string | required | Primary TTS provider (azure, elevenlabs, google) |
| version | string | semver | Kit version for updates |
| download_size | integer | >= 0 | Size in bytes (0 for built-in) |
| is_builtin | boolean | default true | Whether kit is included by default |
| is_downloaded | boolean | default false | Whether kit is downloaded locally |
| created_at | datetime | auto | Creation timestamp |

### VoiceCharacter

Individual voice/character within a kit.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | string | PK, UUID | Unique identifier |
| kit_id | string | FK -> VoiceKit | Parent kit |
| name | string | required, max 50 | Character name (e.g., "故事姐姐") |
| provider_voice_id | string | required | Provider's voice ID (e.g., "zh-TW-HsiaoChenNeural") |
| ssml_options | json | nullable | SSML customization (role, style, pitch, rate) |
| gender | string | enum | male, female, neutral |
| age_group | string | enum | child, adult, senior |
| style | string | enum | narrator, character, both |
| preview_url | string | URL | URL to preview audio |
| preview_text | string | max 200 | Text used for preview |

**SSML Options Schema:**
```json
{
  "role": "Girl|Boy|YoungAdultFemale|...",
  "style": "cheerful|calm|gentle|...",
  "pitch": "+0%",
  "rate": "1.0",
  "volume": "medium"
}
```

### VoicePreference

User's voice selection preferences.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| user_id | string | PK, FK -> User | User identifier |
| default_voice_id | string | FK -> VoiceCharacter | Default voice for new stories |
| updated_at | datetime | auto | Last update timestamp |

### StoryVoiceMap

Per-story voice assignments (for multi-character stories).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| story_id | string | PK, FK -> Story | Story identifier |
| user_id | string | PK, FK -> User | User identifier |
| role | string | PK | Story role (narrator, character1, etc.) |
| voice_id | string | FK -> VoiceCharacter | Assigned voice |

## Enumerations

### Gender
```python
class Gender(str, Enum):
    MALE = "male"
    FEMALE = "female"
    NEUTRAL = "neutral"
```

### AgeGroup
```python
class AgeGroup(str, Enum):
    CHILD = "child"
    ADULT = "adult"
    SENIOR = "senior"
```

### VoiceStyle
```python
class VoiceStyle(str, Enum):
    NARRATOR = "narrator"    # For story narration
    CHARACTER = "character"  # For character dialogue
    BOTH = "both"           # Can be used for both
```

### TTSProvider
```python
class TTSProvider(str, Enum):
    AZURE = "azure"
    GOOGLE = "google"
    ELEVENLABS = "elevenlabs"
    AMAZON = "amazon"
```

## Validation Rules

### VoiceKit
- `name` must be unique within the system
- `version` must follow semantic versioning (x.y.z)
- `download_size` must be 0 for built-in kits

### VoiceCharacter
- `name` must be unique within a kit
- `provider_voice_id` must be valid for the kit's provider
- `preview_text` should be in Traditional Chinese for zh-TW voices

### VoicePreference
- `default_voice_id` must reference an available voice (built-in or downloaded)

## State Transitions

### VoiceKit Download States

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ┌──────────┐    download    ┌─────────────┐          │
│   │          │  ──────────►   │             │          │
│   │ Available│                │ Downloading │          │
│   │          │  ◄──────────   │             │          │
│   └──────────┘    cancel      └─────────────┘          │
│        ▲                            │                   │
│        │ delete                     │ complete          │
│        │                            ▼                   │
│   ┌──────────┐                ┌─────────────┐          │
│   │          │  ◄──────────   │             │          │
│   │ Deleted  │    uninstall   │ Downloaded  │          │
│   │          │                │             │          │
│   └──────────┘                └─────────────┘          │
│                                     │                   │
│                                     │ update            │
│                                     ▼                   │
│                               ┌─────────────┐          │
│                               │   Updating  │          │
│                               └─────────────┘          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Sample Data

### Built-in VoiceKit

```json
{
  "id": "builtin-v1",
  "name": "內建角色",
  "description": "StoryBuddy 預設的故事角色聲音",
  "provider": "azure",
  "version": "1.0.0",
  "download_size": 0,
  "is_builtin": true,
  "is_downloaded": true,
  "voices": [
    {
      "id": "narrator-female",
      "name": "故事姐姐",
      "provider_voice_id": "zh-TW-HsiaoChenNeural",
      "ssml_options": null,
      "gender": "female",
      "age_group": "adult",
      "style": "narrator",
      "preview_text": "大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！"
    },
    {
      "id": "child-girl",
      "name": "小美",
      "provider_voice_id": "zh-TW-HsiaoChenNeural",
      "ssml_options": {
        "role": "Girl",
        "style": "cheerful"
      },
      "gender": "female",
      "age_group": "child",
      "style": "character",
      "preview_text": "哈囉！我是小美，我們一起來冒險吧！"
    }
  ]
}
```

### VoicePreference Example

```json
{
  "user_id": "user-123",
  "default_voice_id": "narrator-female",
  "updated_at": "2026-01-05T10:30:00Z"
}
```

## Database Schema (SQLite)

```sql
-- Voice Kits
CREATE TABLE voice_kits (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    provider TEXT NOT NULL,
    version TEXT NOT NULL,
    download_size INTEGER DEFAULT 0,
    is_builtin INTEGER DEFAULT 1,
    is_downloaded INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Voice Characters
CREATE TABLE voice_characters (
    id TEXT PRIMARY KEY,
    kit_id TEXT NOT NULL REFERENCES voice_kits(id),
    name TEXT NOT NULL,
    provider_voice_id TEXT NOT NULL,
    ssml_options TEXT, -- JSON
    gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'neutral')),
    age_group TEXT NOT NULL CHECK (age_group IN ('child', 'adult', 'senior')),
    style TEXT NOT NULL CHECK (style IN ('narrator', 'character', 'both')),
    preview_url TEXT,
    preview_text TEXT,
    UNIQUE(kit_id, name)
);

-- User Voice Preferences
CREATE TABLE voice_preferences (
    user_id TEXT PRIMARY KEY,
    default_voice_id TEXT REFERENCES voice_characters(id),
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Story Voice Mappings
CREATE TABLE story_voice_maps (
    story_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL,
    voice_id TEXT NOT NULL REFERENCES voice_characters(id),
    PRIMARY KEY (story_id, user_id, role)
);

-- Indexes
CREATE INDEX idx_voice_characters_kit ON voice_characters(kit_id);
CREATE INDEX idx_story_voice_maps_story ON story_voice_maps(story_id);
```
