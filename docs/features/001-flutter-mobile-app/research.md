# Research: Flutter Mobile App

**Branch**: `001-flutter-mobile-app` | **Date**: 2026-01-05

## Overview

This document consolidates research findings for the StoryBuddy Flutter mobile application. The app enables parents to record their voice for AI cloning, play stories using the cloned voice, and facilitate interactive Q&A sessions with children.

---

## 1. Audio Recording

### Decision: `record` package

### Rationale:
- Clean, modern API with minimal dependencies
- Full format support: WAV, AAC (44.1kHz, 16-bit as required by TR-001)
- Built-in amplitude stream for real-time waveform visualization
- Active maintenance by respected Flutter community member
- Lightweight compared to alternatives

### Implementation Notes:
```dart
final record = AudioRecorder();
await record.start(
  const RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 44100,
    numChannels: 1,
    bitRate: 128000,
  ),
  path: filePath,
);

// Waveform visualization
record.onAmplitudeChanged(Duration(milliseconds: 100)).listen((amp) {
  // amp.current provides decibel level for UI
});
```

### Alternatives Considered:
| Package | Why Not Chosen |
|---------|----------------|
| `flutter_sound` | Heavier package, more complex API, overkill for recording-only use case |
| `audio_waveforms` | Less control over audio format specifications |

---

## 2. Audio Playback

### Decision: `just_audio` + `audio_service`

### Rationale:
- **just_audio**: Best-in-class streaming support, reactive streams for UI, playback speed control
- **audio_service**: Required for background audio, lock screen controls, audio focus handling
- This combination is the de-facto standard for media apps in Flutter
- Parents need lock screen controls for bedtime story playback (TR-012)
- Must pause properly for phone calls (TR-013)

### Implementation Architecture:
```
┌─────────────────────────────────┐
│         StoryBuddy UI           │
│   (Play/Pause/Seek/Progress)    │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│         audio_service           │
│  (Background, notifications,    │
│   lock screen, audio focus)     │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│          just_audio             │
│  (Streaming, playback, seeking) │
└─────────────────────────────────┘
```

### Alternatives Considered:
| Package | Why Not Chosen |
|---------|----------------|
| `audioplayers` | Insufficient background support, weaker streaming |
| `audioplayers` + `audio_service` | just_audio has better API and more features |

---

## 3. State Management

### Decision: Riverpod 2.x with Clean Architecture

### Rationale:
- No BuildContext dependency - enables easier state access in audio services
- Compile-time safety catches errors early
- Excellent testing support with easy provider overrides
- Built-in caching and automatic disposal for story/audio resources
- Code generation (`riverpod_generator`) reduces boilerplate

### Architecture Layers:
```
lib/features/{feature}/
├── data/           # Data sources, repositories implementation
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/         # Business logic, entities, interfaces
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/   # UI, providers, widgets
    ├── providers/
    ├── pages/
    └── widgets/
```

### Alternatives Considered:
| Approach | Why Not Chosen |
|----------|----------------|
| Provider | BuildContext dependency complicates audio services; less testable |
| Bloc | Excessive boilerplate for StoryBuddy's complexity level |
| GetX | Mixes concerns; not recommended for production apps |

---

## 4. Local Database

### Decision: drift (formerly moor)

### Rationale:
- Type-safe SQL with compile-time validation
- Relational data support (StoryBuddy has clear entity relationships)
- Built-in schema migration for app updates
- Reactive streams for real-time UI updates
- SQLite foundation aligns with backend (PostgreSQL → SQLite local)
- Active maintenance and community support

### Entity Relationships:
```
VoiceProfile ─────┐
                  │
Parent ───────────┼──── Story ──── QASession ──── QAMessage
                  │         │
                  └─────────┴──── PendingQuestion
```

### Alternatives Considered:
| Package | Why Not Chosen |
|---------|----------------|
| sqflite | Too verbose; drift provides better DX with type safety |
| hive | No relational support; StoryBuddy needs entity relationships |
| isar | Development uncertainty; drift has stronger maintainability |

---

## 5. File Caching & Offline Storage

### Decision: `flutter_cache_manager` + `path_provider`

### Rationale:
- Automatic cache eviction (LRU-based)
- Download progress tracking
- Configurable cache duration and size limits
- Platform-specific directory access

### Cache Structure:
```
app_documents/
└── audio_cache/
    ├── stories/{story_id}/audio.mp3    # Persistent downloads
    └── voice_samples/{profile_id}.wav   # Voice recordings
temp/
└── streaming_cache/                     # Temporary playback
```

### Encryption (PS-001 Compliance):
- Use `encrypt` package for AES-256 encryption of cached audio
- Keys stored in `flutter_secure_storage`

---

## 6. Secure Storage

### Decision: `flutter_secure_storage`

### Rationale:
- Platform-native security (iOS Keychain, Android EncryptedSharedPreferences)
- Explicitly required by TR-005
- Simple key-value API for tokens
- No manual encryption key management

### What to Store:
- API authentication tokens (JWT)
- Refresh tokens
- Voice profile encryption keys
- User consent flags

---

## 7. Offline-First Architecture

### Decision: Repository Pattern with Local-First + Queue-Based Sync

### Pattern:
```
┌─────────────┐
│ Repository  │ ← Single source of truth
└──────┬──────┘
       │
  ┌────┴────┐
  │         │
┌─▼──┐  ┌──▼─┐
│Local│  │API │
│ DB  │  │    │
└────┘  └────┘
```

### Sync Strategy:
1. **Reads**: Return cached data immediately, fetch in background, update cache
2. **Writes**: Write locally, mark as "pending sync", queue API call
3. **Connectivity**: Monitor with `connectivity_plus`, process queue when online
4. **Background**: Use `workmanager` for sync when app is closed

### Entity Sync Strategies:
| Entity | Strategy | Conflict Resolution |
|--------|----------|---------------------|
| VoiceProfile | Upload on create | Server wins |
| Story | Bi-directional | Last-write-wins |
| QASession | Append-only | Merge |
| PendingQuestion | Append-only | No conflicts |

---

## 8. Recommended Package Stack

### Core Dependencies:

```yaml
dependencies:
  # UI Framework
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Routing
  go_router: ^14.0.0

  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0

  # Audio
  just_audio: ^0.9.36
  audio_service: ^0.18.12
  record: ^5.0.0

  # Database
  drift: ^2.15.0
  sqlite3_flutter_libs: ^0.5.0

  # Storage & Caching
  path_provider: ^2.1.0
  flutter_cache_manager: ^3.3.0
  flutter_secure_storage: ^9.0.0

  # Encryption
  encrypt: ^5.0.3

  # Background Tasks
  workmanager: ^0.5.2

  # Utilities
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  logger: ^2.0.0
  permission_handler: ^11.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  drift_dev: ^2.15.0

  # Testing
  mocktail: ^1.0.0
  integration_test:
    sdk: flutter
```

---

## 9. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        StoryBuddy App                           │
├─────────────────────────────────────────────────────────────────┤
│  Presentation Layer (Riverpod Providers + Widgets)              │
├─────────────────────────────────────────────────────────────────┤
│  Domain Layer (Use Cases + Repository Interfaces)               │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Drift DB      │  │  Audio Cache    │  │  Secure Storage │ │
│  │  (Stories, QA,  │  │  (MP3/WAV)      │  │  (Tokens, Keys) │ │
│  │   Sync Queue)   │  │                 │  │                 │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
│           └────────────────────┼────────────────────┘           │
│                                │                                │
│  ┌─────────────────────────────▼─────────────────────────────┐ │
│  │                    Sync Manager                            │ │
│  │  (Connectivity Monitor + Queue + Background Worker)        │ │
│  └─────────────────────────────┬─────────────────────────────┘ │
└────────────────────────────────┼────────────────────────────────┘
                                 │ HTTPS (TLS 1.2+)
                    ┌────────────▼────────────┐
                    │    Backend API          │
                    │    (Python/FastAPI)     │
                    │    /api/v1/*            │
                    └─────────────────────────┘
```

---

## 10. Key Implementation Decisions

| Area | Decision | Spec Compliance |
|------|----------|-----------------|
| Recording Format | WAV, 44.1kHz, 16-bit | TR-001 |
| Secure Storage | flutter_secure_storage | TR-005 |
| State Management | Riverpod | TR-006 |
| Audio Playback | just_audio + audio_service | TR-009, TR-012 |
| Audio Recording | record package | TR-010 |
| Local Cache Encryption | AES-256 via encrypt | PS-001 |
| API Communication | HTTPS/TLS | PS-002, TR-004 |
