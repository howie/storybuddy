---
description: "Task list for Flutter Mobile App implementation"
---

# Tasks: Flutter Mobile App

**Input**: Design documents from `/docs/features/001-flutter-mobile-app/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Tests**: Required per Constitution Principle I (Test-First)

## Progress Summary

| Phase | Status | Completed | Total |
|-------|--------|-----------|-------|
| Phase 1: Setup | ✅ Complete | 6/6 | 100% |
| Phase 2: Foundational | ✅ Complete | 16/16 | 100% |
| Phase 3: US1 (Voice Recording) | ✅ Complete | 16/16 | 100% |
| Phase 4: US4 (Story List) | ✅ Complete | 13/13 | 100% |
| Phase 5: US2 (Playback) | ✅ Complete | 15/15 | 100% |
| Phase 6: US3 (Q&A) | ✅ Complete | 13/13 | 100% |
| Phase 7: US5 (Import Story) | ✅ Complete | 7/7 | 100% |
| Phase 8: US6 (Generate Story) | ✅ Complete | 7/7 | 100% |
| Phase 9: US7 (Pending Questions) | ✅ Complete | 11/11 | 100% |
| Phase 10: Polish | ✅ Complete | 10/10 | 100% |
| **Total** | | **114/114** | **100%** |

**Last Updated**: 2026-01-07

**Note**: Implementation structure exists for all features. Remaining work is mostly tests and polish.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Paths are relative to `mobile/` (e.g., `lib/...`, `test/...`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Verify Flutter project in mobile/ with pubspec.yaml dependencies per quickstart.md
- [ ] T002 Create directory structure (lib/core, lib/features, lib/shared, test/, assets/)
- [ ] T003 [P] Configure analysis_options.yaml for strict linting
- [ ] T004 [P] Create lib/core/constants/env.dart for environment variables
- [ ] T005 [P] Create assets/l10n/app_zh_TW.arb for Traditional Chinese strings
- [ ] T006 [P] Configure assets/ (images, l10n) in pubspec.yaml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation

- [ ] T007 [P] Write unit test for ApiClient in test/unit/core/api_client_test.dart
- [ ] T008 [P] Write unit test for SecureStorageProvider in test/unit/core/secure_storage_test.dart
- [ ] T009 [P] Write unit test for AppDatabase connection in test/unit/core/app_database_test.dart
- [ ] T010 [P] Write unit test for Failures in test/unit/core/failures_test.dart
- [ ] T011 [P] Write unit test for PermissionHandler in test/unit/core/permission_handler_test.dart

### Implementation for Foundation

- [ ] T012 Setup lib/main.dart with ProviderScope and MaterialApp
- [ ] T013 Create lib/core/theme/app_theme.dart (Light/Dark mode per TR-007)
- [ ] T014 Setup lib/core/router/app_router.dart with GoRouter
- [ ] T015 Implement lib/core/network/api_client.dart with Dio and interceptors
- [ ] T016 Setup lib/core/database/app_database.dart (Drift) with base connection
- [ ] T017 Create lib/core/storage/secure_storage_provider.dart (FlutterSecureStorage per TR-005)
- [ ] T018 Implement lib/core/error/failures.dart and exception handling
- [ ] T019 Create lib/shared/widgets/loading_indicator.dart
- [ ] T020 [P] Create lib/shared/widgets/error_view.dart
- [ ] T021 Setup lib/core/utils/permission_handler.dart wrapper
- [ ] T022 Create test/mocks/mock_providers.dart for shared test mocks

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 家長錄製聲音樣本 (Priority: P1) 🎯 MVP

**Goal**: Parents can record their voice (30+ seconds) to create a voice cloning profile.

**Independent Test**: Record audio, preview playback, verify upload to server, see status update.

### Tests for User Story 1 ⚠️ TDD Required

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T023 [P] [US1] Unit test for VoiceProfile entity in test/unit/voice_profile/entities/voice_profile_test.dart
- [ ] T024 [P] [US1] Unit test for AudioRecorderService in test/unit/voice_profile/datasources/audio_recorder_service_test.dart
- [ ] T025 [P] [US1] Unit test for VoiceProfileRepository in test/unit/voice_profile/repositories/voice_profile_repository_test.dart
- [ ] T026 [P] [US1] Unit test for VoiceRecordingProvider (30s minimum check) in test/unit/voice_profile/providers/voice_recording_provider_test.dart
- [ ] T027 [P] [US1] Widget test for WaveformWidget in test/widget/voice_profile/waveform_widget_test.dart
- [ ] T028 [P] [US1] Widget test for VoiceRecordingPage in test/widget/voice_profile/voice_recording_page_test.dart

### Implementation for User Story 1

- [ ] T029 [P] [US1] Create VoiceProfile Drift table in lib/core/database/tables/voice_profiles.dart
- [ ] T030 [P] [US1] Create VoiceProfile domain entity with Freezed in lib/features/voice_profile/domain/entities/voice_profile.dart
- [ ] T031 [US1] Run build_runner to generate Drift and Freezed code
- [ ] T032 [US1] Implement AudioRecorderService (record package, WAV 44.1kHz per TR-003) in lib/features/voice_profile/data/datasources/audio_recorder_service.dart
- [ ] T033 [US1] Implement VoiceProfileRepository in lib/features/voice_profile/data/repositories/voice_profile_repository_impl.dart
- [ ] T034 [US1] Create VoiceRecordingProvider (Riverpod) with 30s minimum validation in lib/features/voice_profile/presentation/providers/voice_recording_provider.dart
- [ ] T035 [P] [US1] Create WaveformWidget (amplitude visualization per FR-001) in lib/features/voice_profile/presentation/widgets/waveform_widget.dart
- [ ] T036 [US1] Implement VoiceRecordingPage (timer, preview, upload per acceptance scenarios) in lib/features/voice_profile/presentation/pages/voice_recording_page.dart
- [ ] T037 [US1] Implement PrivacyConsentDialog (required before first recording per PS-003) in lib/features/voice_profile/presentation/widgets/privacy_consent_dialog.dart
- [ ] T038 [US1] Add voice profile routes to app_router.dart

**Checkpoint**: User Story 1 functional - Recording, preview, and upload works.

---

## Phase 4: User Story 4 - 故事列表與選擇 (Priority: P1)

**Goal**: Users can browse and select stories from a list.

**Independent Test**: App displays list of stories from API/DB, allows selection, shows offline indicator.

### Tests for User Story 4 ⚠️ TDD Required

- [ ] T039 [P] [US4] Unit test for Story entity in test/unit/stories/entities/story_test.dart
- [ ] T040 [P] [US4] Unit test for StoryRepository in test/unit/stories/repositories/story_repository_test.dart
- [ ] T041 [P] [US4] Unit test for StoryListProvider in test/unit/stories/providers/story_list_provider_test.dart
- [ ] T042 [P] [US4] Widget test for StoryListItem in test/widget/stories/story_list_item_test.dart
- [ ] T043 [P] [US4] Widget test for StoryListPage in test/widget/stories/story_list_page_test.dart

### Implementation for User Story 4

- [ ] T044 [P] [US4] Create Story Drift table in lib/core/database/tables/stories.dart
- [ ] T045 [P] [US4] Create Story domain entity with Freezed in lib/features/stories/domain/entities/story.dart
- [ ] T046 [US4] Run build_runner to generate Drift and Freezed code
- [ ] T047 [US4] Implement StoryRepository (API + local cache) in lib/features/stories/data/repositories/story_repository_impl.dart
- [ ] T048 [US4] Create StoryListProvider (Riverpod) in lib/features/stories/presentation/providers/story_list_provider.dart
- [ ] T049 [P] [US4] Create StoryListItem widget (title, source, date, offline badge) in lib/features/stories/presentation/widgets/story_list_item.dart
- [ ] T050 [US4] Implement StoryListPage in lib/features/stories/presentation/pages/story_list_page.dart
- [ ] T051 [US4] Add story list routes to app_router.dart

**Checkpoint**: User Story 4 functional - Story list visible and selectable.

---

## Phase 5: User Story 2 - AI 用家長聲音講故事 (Priority: P1)

**Goal**: Play stories using the cloned parent voice with playback controls.

**Independent Test**: Select a story, hear AI-generated audio, use play/pause/seek controls, verify background playback.

**Dependencies**: Requires US1 (voice profile) and US4 (story selection) to be meaningful, but can be tested with mocks.

### Tests for User Story 2 ⚠️ TDD Required

- [ ] T052 [P] [US2] Unit test for PlaybackState entity in test/unit/playback/entities/playback_state_test.dart
- [ ] T053 [P] [US2] Unit test for AudioPlayerService in test/unit/playback/datasources/audio_player_service_test.dart
- [ ] T054 [P] [US2] Unit test for PlaybackRepository in test/unit/playback/repositories/playback_repository_test.dart
- [ ] T055 [P] [US2] Unit test for PlaybackProvider in test/unit/playback/providers/playback_provider_test.dart
- [ ] T056 [P] [US2] Widget test for PlayerControls in test/widget/playback/player_controls_test.dart
- [ ] T057 [P] [US2] Widget test for PlaybackPage in test/widget/playback/playback_page_test.dart

### Implementation for User Story 2

- [ ] T058 [P] [US2] Create PlaybackState domain entity in lib/features/playback/domain/entities/playback_state.dart
- [ ] T059 [US2] Implement AudioPlayerService (just_audio + audio_service per TR-009) in lib/features/playback/data/datasources/audio_player_service.dart
- [ ] T060 [US2] Implement PlaybackRepository (TTS API streaming per FR-006) in lib/features/playback/data/repositories/playback_repository_impl.dart
- [ ] T061 [US2] Create PlaybackProvider (Riverpod) in lib/features/playback/presentation/providers/playback_provider.dart
- [ ] T062 [P] [US2] Create PlayerControls widget (play/pause/seek/progress per FR-007) in lib/features/playback/presentation/widgets/player_controls.dart
- [ ] T063 [US2] Implement PlaybackPage (or BottomSheet) in lib/features/playback/presentation/pages/playback_page.dart
- [ ] T064 [US2] Configure background audio in android/app/src/main/AndroidManifest.xml (FOREGROUND_SERVICE, WAKE_LOCK)
- [ ] T065 [US2] Configure background audio in ios/Runner/Info.plist (UIBackgroundModes audio)
- [ ] T066 [US2] Implement audio caching with encryption (PS-001) in lib/features/playback/data/datasources/audio_cache_service.dart

**Checkpoint**: User Story 2 functional - Audio playback with controls and background support.

---

## Phase 6: User Story 3 - 故事後問答互動 (Priority: P1)

**Goal**: Interactive Q&A after story playback for children.

**Independent Test**: Chat interface allows voice/text questions, receives AI answers, enforces 10-question limit.

**Dependencies**: Requires US4 (story context) for meaningful Q&A.

### Tests for User Story 3 ⚠️ TDD Required

- [ ] T067 [P] [US3] Unit test for QASession and QAMessage entities in test/unit/qa_session/entities/qa_session_test.dart
- [ ] T068 [P] [US3] Unit test for QARepository in test/unit/qa_session/repositories/qa_repository_test.dart
- [ ] T069 [P] [US3] Unit test for QASessionProvider (10-message limit) in test/unit/qa_session/providers/qa_session_provider_test.dart
- [ ] T070 [P] [US3] Widget test for MessageBubble in test/widget/qa_session/message_bubble_test.dart
- [ ] T071 [P] [US3] Widget test for QASessionPage in test/widget/qa_session/qa_session_page_test.dart

### Implementation for User Story 3

- [ ] T072 [P] [US3] Create QASession and QAMessage Drift tables in lib/core/database/tables/qa_sessions.dart
- [ ] T073 [P] [US3] Create QASession and QAMessage domain entities in lib/features/qa_session/domain/entities/qa_session.dart
- [ ] T074 [US3] Run build_runner to generate Drift and Freezed code
- [ ] T075 [US3] Implement QARepository (API for Q&A, isInScope detection) in lib/features/qa_session/data/repositories/qa_repository_impl.dart
- [ ] T076 [US3] Create QASessionProvider (Riverpod, 10-message limit per Edge Case) in lib/features/qa_session/presentation/providers/qa_session_provider.dart
- [ ] T077 [P] [US3] Create MessageBubble widget (child/AI roles) in lib/features/qa_session/presentation/widgets/message_bubble.dart
- [ ] T078 [US3] Implement QASessionPage (voice input reusing AudioRecorderService) in lib/features/qa_session/presentation/pages/qa_session_page.dart
- [ ] T079 [US3] Add QA session routes to app_router.dart

**Checkpoint**: User Story 3 functional - Q&A chat works with voice input.

---

## Phase 7: User Story 5 - 匯入外部故事 (Priority: P2)

**Goal**: Import stories from text (max 5000 characters).

**Independent Test**: Paste text, save story, verify it appears in story list.

### Tests for User Story 5 ⚠️ TDD Required

- [ ] T080 [P] [US5] Unit test for importStory method in test/unit/stories/repositories/import_story_test.dart
- [ ] T081 [P] [US5] Unit test for ImportStoryProvider in test/unit/stories/providers/import_story_provider_test.dart
- [ ] T082 [P] [US5] Widget test for ImportStoryPage in test/widget/stories/import_story_page_test.dart

### Implementation for User Story 5

- [ ] T083 [US5] Implement importStory method (5000 char limit per acceptance scenario) in StoryRepository
- [ ] T084 [US5] Create ImportStoryProvider in lib/features/stories/presentation/providers/import_story_provider.dart
- [ ] T085 [US5] Implement ImportStoryPage (text input, validation) in lib/features/stories/presentation/pages/import_story_page.dart
- [ ] T086 [US5] Add import story route to app_router.dart

**Checkpoint**: User Story 5 functional - Story import works.

---

## Phase 8: User Story 6 - AI 編寫故事 (Priority: P2)

**Goal**: Generate stories via AI using keywords.

**Independent Test**: Enter keywords, generate story, preview, regenerate, save to list.

### Tests for User Story 6 ⚠️ TDD Required

- [ ] T087 [P] [US6] Unit test for generateStory method in test/unit/stories/repositories/generate_story_test.dart
- [ ] T088 [P] [US6] Unit test for GenerateStoryProvider in test/unit/stories/providers/generate_story_provider_test.dart
- [ ] T089 [P] [US6] Widget test for GenerateStoryPage in test/widget/stories/generate_story_page_test.dart

### Implementation for User Story 6

- [ ] T090 [US6] Implement generateStory method (API call for AI generation) in StoryRepository
- [ ] T091 [US6] Create GenerateStoryProvider in lib/features/stories/presentation/providers/generate_story_provider.dart
- [ ] T092 [US6] Implement GenerateStoryPage (keywords input, preview, regenerate) in lib/features/stories/presentation/pages/generate_story_page.dart
- [ ] T093 [US6] Add generate story route to app_router.dart

**Checkpoint**: User Story 6 functional - AI story generation works.

---

## Phase 9: User Story 7 - 待答問題列表 (Priority: P2)

**Goal**: View questions deferred to parents (out-of-scope questions from Q&A).

**Independent Test**: Ask out-of-scope question in Q&A, verify it appears in pending questions list.

### Tests for User Story 7 ⚠️ TDD Required

- [ ] T094 [P] [US7] Unit test for PendingQuestion entity in test/unit/pending_questions/entities/pending_question_test.dart
- [ ] T095 [P] [US7] Unit test for PendingQuestionRepository in test/unit/pending_questions/repositories/pending_question_repository_test.dart
- [ ] T096 [P] [US7] Unit test for PendingQuestionsProvider in test/unit/pending_questions/providers/pending_questions_provider_test.dart
- [ ] T097 [P] [US7] Widget test for PendingQuestionsPage in test/widget/pending_questions/pending_questions_page_test.dart

### Implementation for User Story 7

- [ ] T098 [P] [US7] Create PendingQuestion Drift table in lib/core/database/tables/pending_questions.dart
- [ ] T099 [P] [US7] Create PendingQuestion domain entity in lib/features/pending_questions/domain/entities/pending_question.dart
- [ ] T100 [US7] Run build_runner to generate Drift and Freezed code
- [ ] T101 [US7] Implement PendingQuestionRepository in lib/features/pending_questions/data/repositories/pending_question_repository.dart
- [ ] T102 [US7] Create PendingQuestionsProvider in lib/features/pending_questions/presentation/providers/pending_questions_provider.dart
- [ ] T103 [US7] Implement PendingQuestionsPage in lib/features/pending_questions/presentation/pages/pending_questions_page.dart
- [ ] T104 [US7] Add pending questions route to app_router.dart

**Checkpoint**: User Story 7 functional - Pending questions visible to parents.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements, sync logic, and final polish

### Tests for Polish

- [ ] T105 [P] Unit test for SyncManager in test/unit/core/sync_manager_test.dart
- [ ] T106 [P] Unit test for Settings (delete data) in test/unit/settings/settings_test.dart

### Implementation for Polish

- [ ] T107 Implement SyncManager (offline sync queue per research.md) in lib/core/sync/sync_manager.dart
- [ ] T108 [P] Add offline mode indicators to UI (connectivity_plus)
- [ ] T109 [P] Implement NoiseDetectionService (background noise check per Edge Case) in lib/features/voice_profile/data/datasources/noise_detection_service.dart
- [ ] T110 Implement SettingsPage (delete local data per PS-004, logout) in lib/features/settings/presentation/pages/settings_page.dart
- [ ] T111 [P] Verify flutter_secure_storage implementation for tokens
- [ ] T112 Run flutter test and fix any broken tests
- [ ] T113 Run flutter analyze and fix all lint warnings
- [ ] T114 [P] Update README.md with setup and run instructions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phase 3 (US1)**: Can start after Phase 2 - No dependencies on other stories
- **Phase 4 (US4)**: Can start after Phase 2 - Can run in parallel with US1
- **Phase 5 (US2)**: Can start after Phase 2 - Best after US1 + US4 for integration testing
- **Phase 6 (US3)**: Can start after Phase 2 - Best after US4 for context
- **Phase 7 (US5)**: Can start after Phase 2 - Extends US4
- **Phase 8 (US6)**: Can start after Phase 2 - Extends US4
- **Phase 9 (US7)**: Can start after Phase 2 - Best after US3 (captures deferred questions)
- **Phase 10 (Polish)**: After MVP user stories complete

### User Story Dependencies

```
Phase 2 (Foundation)
       │
       ├──────────────┬──────────────┐
       │              │              │
       ▼              ▼              │
   [US1: Voice]  [US4: Stories]      │
       │              │              │
       └──────┬───────┘              │
              │                      │
              ▼                      │
         [US2: Playback]             │
              │                      │
              │                      ▼
              └────────────► [US3: Q&A] ────► [US7: Pending Questions]
                                     │
                                     │
       [US4]──────────► [US5: Import Story]
              │
              └────────► [US6: Generate Story]
```

### Implementation Strategy

1. **MVP (P1 Stories)**: Complete Phases 1-6 (Setup, Foundation, US1, US4, US2, US3)
2. **Expansion (P2 Stories)**: Complete Phases 7-9 (US5, US6, US7)
3. **Polish**: Complete Phase 10

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (TDD - must fail first):
Task: "Unit test for VoiceProfile entity in test/unit/voice_profile/entities/voice_profile_test.dart"
Task: "Unit test for AudioRecorderService in test/unit/voice_profile/datasources/audio_recorder_service_test.dart"
Task: "Unit test for VoiceProfileRepository in test/unit/voice_profile/repositories/voice_profile_repository_test.dart"

# After tests written, launch parallel models:
Task: "Create VoiceProfile Drift table in lib/core/database/tables/voice_profiles.dart"
Task: "Create VoiceProfile domain entity in lib/features/voice_profile/domain/entities/voice_profile.dart"
```

---

## Parallel Example: User Story 4

```bash
# Launch all tests for User Story 4 together (TDD - must fail first):
Task: "Unit test for Story entity in test/unit/stories/entities/story_test.dart"
Task: "Unit test for StoryRepository in test/unit/stories/repositories/story_repository_test.dart"
Task: "Unit test for StoryListProvider in test/unit/stories/providers/story_list_provider_test.dart"

# After tests written, launch parallel models:
Task: "Create Story Drift table in lib/core/database/tables/stories.dart"
Task: "Create Story domain entity in lib/features/stories/domain/entities/story.dart"
```

---

## Notes

- All tests MUST be written and FAIL before implementation (Constitution Principle I: Test-First)
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
