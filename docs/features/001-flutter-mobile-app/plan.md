# Implementation Plan: Flutter Mobile App

**Branch**: `001-flutter-mobile-app` | **Date**: 2026-01-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/001-flutter-mobile-app/spec.md`

## Summary

StoryBuddy Flutter mobile application enables parents to record their voice for AI cloning, play stories using the cloned voice, and facilitate interactive Q&A sessions with children. The app connects to the existing Python backend API (from 000-StoryBuddy-mvp) and provides offline-first functionality with local caching of stories and audio.

**Technical Approach**: Clean architecture with Riverpod for state management, Drift for local database, just_audio + audio_service for audio playback, and record package for voice recording. Offline-first design with sync queue for background synchronization.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (latest stable)
**Primary Dependencies**: flutter_riverpod, go_router, dio, just_audio, audio_service, record, drift, flutter_secure_storage
**Storage**: SQLite (Drift) for local data, encrypted file cache for audio
**Testing**: flutter_test, mocktail, integration_test
**Target Platform**: iOS 14+ and Android 8+ (API 26)
**Project Type**: Mobile (Flutter cross-platform)
**Performance Goals**:
- App startup < 3 seconds (cold start)
- Recording latency < 500ms
- Story list load < 2 seconds
- Audio playback latency < 2 seconds
**Constraints**:
- App size < 50MB (excluding downloaded content)
- Offline-capable for downloaded stories
- Background audio playback required
**Scale/Scope**: Single-family use (MVP), ~10 screens, 7 user stories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First (NON-NEGOTIABLE) | ✅ PASS | Tasks will follow TDD: write test → implement → refactor |
| II. Modular Design | ✅ PASS | Clean architecture with data/domain/presentation layers per feature |
| III. Security & Privacy | ✅ PASS | flutter_secure_storage for tokens, AES-256 for cached audio, TLS for API |
| IV. Observability | ✅ PASS | logger package for structured logging, API call logging via Dio interceptors |
| V. Simplicity | ✅ PASS | MVP scope respected, single project, standard Flutter patterns |

### Children's Safety Standards

| Requirement | Implementation |
|-------------|----------------|
| Age-Appropriate Content | Backend handles content moderation for AI-generated stories |
| No Harmful Content | Backend filtering; app displays filtered content only |
| Safe Defaults | Questions outside story scope deferred to parents (US7) |
| Parental Oversight | Pending questions list visible to parents |
| Question Boundaries | 10-question limit per session; out-of-scope → PendingQuestion |

### Privacy Requirements

| Requirement | Implementation |
|-------------|----------------|
| Data Minimization | Store only necessary data; no analytics in MVP |
| Consent First | Privacy consent dialog before first voice recording (PS-003) |
| Local First | Offline-first with sync; minimize server dependency |
| Retention Limits | Configurable cache size; LRU eviction |
| Deletion Rights | Settings page includes "Delete Local Data" option (PS-004) |
| Third-Party Disclosure | Backend handles ElevenLabs/Azure/Anthropic disclosure |

### Quality Gates

| Gate | Implementation |
|------|----------------|
| Tests | flutter test in CI; blocks merge on failure |
| Coverage | PR review ensures new code has tests |
| Linting | flutter analyze in CI; blocks merge on failure |
| Types | Dart strong typing enforced |
| Security | flutter_secure_storage; no hardcoded secrets |
| Docs | Public APIs documented in code |

## Project Structure

### Documentation (this feature)

```text
docs/features/001-flutter-mobile-app/
├── plan.md              # This file
├── research.md          # Phase 0 output (complete)
├── data-model.md        # Phase 1 output (complete)
├── quickstart.md        # Phase 1 output (complete)
├── contracts/           # Phase 1 output (contains openapi.yaml)
└── tasks.md             # Phase 2 output (complete - needs TDD updates)
```

### Source Code (repository root)

```text
mobile/
├── lib/
│   ├── main.dart                    # App entry point with ProviderScope
│   ├── app/
│   │   └── app.dart                 # MaterialApp configuration
│   ├── core/
│   │   ├── constants/
│   │   │   └── env.dart             # Environment configuration
│   │   ├── database/
│   │   │   ├── app_database.dart    # Drift database setup
│   │   │   └── tables/              # Table definitions
│   │   ├── error/
│   │   │   └── failures.dart        # Error handling
│   │   ├── network/
│   │   │   ├── api_client.dart      # Dio HTTP client
│   │   │   └── interceptors/        # Auth, logging interceptors
│   │   ├── router/
│   │   │   └── app_router.dart      # GoRouter configuration
│   │   ├── storage/
│   │   │   └── secure_storage.dart  # FlutterSecureStorage wrapper
│   │   ├── sync/
│   │   │   └── sync_manager.dart    # Offline sync queue
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Light/Dark themes
│   │   └── utils/
│   │       └── permission_handler.dart
│   ├── features/
│   │   ├── voice_profile/
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── audio_recorder_service.dart
│   │   │   │   ├── models/
│   │   │   │   └── repositories/
│   │   │   │       └── voice_profile_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── voice_profile.dart
│   │   │   │   └── repositories/
│   │   │   │       └── voice_profile_repository.dart
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   └── voice_recording_page.dart
│   │   │       ├── providers/
│   │   │       │   └── voice_recording_provider.dart
│   │   │       └── widgets/
│   │   │           └── waveform_widget.dart
│   │   ├── stories/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── playback/
│   │   │   ├── data/
│   │   │   │   └── datasources/
│   │   │   │       └── audio_player_service.dart
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── qa_session/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── pending_questions/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   └── settings/
│   │       └── presentation/
│   │           └── pages/
│   │               └── settings_page.dart
│   └── shared/
│       ├── widgets/
│       │   ├── loading_indicator.dart
│       │   └── error_view.dart
│       └── providers/
├── test/
│   ├── unit/
│   │   ├── voice_profile/
│   │   ├── stories/
│   │   ├── playback/
│   │   └── qa_session/
│   ├── widget/
│   │   └── shared/
│   └── mocks/
├── integration_test/
└── assets/
    ├── images/
    ├── l10n/
    └── fonts/
```

**Structure Decision**: Mobile app structure following Clean Architecture with feature-based organization. Each feature has data/domain/presentation layers. Core module contains shared infrastructure. Tests mirror the lib structure.

## Complexity Tracking

> No constitution violations requiring justification. Architecture follows constitution principles.

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| State Management | Riverpod | Constitution Principle V (Simplicity) - no BuildContext dependency, excellent testing |
| Local Database | Drift | Type-safe SQL, relational data support for entities, reactive streams |
| Audio Playback | just_audio + audio_service | De-facto standard for Flutter media apps, background support |
| Architecture | Clean Architecture | Constitution Principle II (Modular Design) - clear layer separation |

## Implementation Phases

### Phase 0: Research (Complete)

Research artifacts generated in `research.md`:
- Audio recording: `record` package selected
- Audio playback: `just_audio` + `audio_service` selected
- State management: Riverpod 2.x selected
- Local database: Drift selected
- Offline architecture: Repository pattern with sync queue

### Phase 1: Design (Complete)

Design artifacts generated:
- `data-model.md`: Entity definitions with Drift schema and Freezed models
- `contracts/openapi.yaml`: API contract for backend integration
- `quickstart.md`: Project setup and development workflow

### Phase 2: Tasks (Generated separately)

See `tasks.md` for implementation task breakdown by user story.

**Note**: Tasks require TDD restructuring - each implementation task should be preceded by its test task per Constitution Principle I.
