# Tasks: Selectable Voice Kit

**Input**: Design documents from `/docs/features/003-selectable-voice-kit/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/voice-api.yaml

**Tests**: Following constitution principle I (Test-First), tests are included for TDD compliance.

## Progress Summary

| Phase | Status | Completed | Total |
|-------|--------|-----------|-------|
| Phase 1: Setup | ⏳ Pending | 0/4 | 0% |
| Phase 2: Foundational | ⏳ Pending | 0/9 | 0% |
| Phase 3: US1 (Voice Selection) | ⏳ Pending | 0/24 | 0% |
| Phase 4: US2 (Voice Packs) | ⏳ Pending | 0/14 | 0% |
| Phase 5: US3 (Multi-Voice) | ⏳ Pending | 0/14 | 0% |
| Phase 6: Polish | ⏳ Pending | 0/7 | 0% |
| **Total** | | **0/72** | **0%** |

**Last Updated**: 2026-01-07

**Note**: Research phase complete (TTS provider selection: Google Cloud TTS). Implementation not yet started.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `src/` at repository root (Python/FastAPI)
- **Flutter**: `lib/` at repository root (Dart/Flutter)
- **Tests**: `tests/` (backend), `test/` (Flutter)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Google Cloud TTS integration setup

- [ ] T001 Add google-cloud-texttospeech to requirements.txt
- [ ] T002 [P] Add Google credentials handling to config (GOOGLE_APPLICATION_CREDENTIALS)
- [ ] T003 [P] Create src/services/tts/ directory structure with __init__.py
- [ ] T004 [P] Add Flutter dependencies to pubspec.yaml (just_audio, provider)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core TTS abstraction and database schema that MUST be complete before ANY user story

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create TTSProvider abstract base class in src/services/tts/base.py
- [ ] T006 [P] Create voice-related enums (Gender, AgeGroup, VoiceStyle, TTSProvider) in src/models/voice.py
- [ ] T007 [P] Create database migration for voice_kits table in src/migrations/
- [ ] T008 [P] Create database migration for voice_characters table in src/migrations/
- [ ] T009 [P] Create database migration for voice_preferences table in src/migrations/
- [ ] T010 Implement GoogleTTSProvider in src/services/tts/google_tts.py
- [ ] T011 Create SSML generation utility (for pitch/rate) in src/services/tts/ssml_utils.py
- [ ] T012 [P] Create VoiceCharacter Dart model in lib/models/voice_kit.dart
- [ ] T013 [P] Create VoiceKit Dart model in lib/models/voice_kit.dart

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 選擇角色聲音播放故事 (Priority: P1) MVP

**Goal**: Children can select a character voice and play stories using that voice

**Independent Test**: Select a voice, play a story, confirm voice matches selection

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T014 [P] [US1] Contract test for GET /api/voices in tests/contract/test_voice_api.py
- [ ] T015 [P] [US1] Contract test for GET /api/voices/{voice_id}/preview in tests/contract/test_voice_api.py
- [ ] T016 [P] [US1] Contract test for POST /api/stories/{story_id}/generate-audio in tests/contract/test_voice_api.py
- [ ] T017 [P] [US1] Unit test for VoiceKitService in tests/unit/services/test_voice_kit_service.py
- [ ] T018 [P] [US1] Integration test for Google TTS in tests/integration/test_google_tts.py

### Implementation for User Story 1

- [ ] T019 [P] [US1] Create VoiceKit model in src/models/voice.py
- [ ] T020 [P] [US1] Create VoiceCharacter model in src/models/voice.py
- [ ] T021 [US1] Create VoiceKitService with built-in voices (Google simulated) in src/services/voice_kit_service.py
- [ ] T022 [US1] Implement list_voices() in VoiceKitService
- [ ] T023 [US1] Implement get_voice() in VoiceKitService
- [ ] T024 [US1] Implement get_voice_preview() in VoiceKitService using Google TTS
- [ ] T025 [US1] Implement generate_story_audio() in VoiceKitService
- [ ] T026 [P] [US1] Create voice routes in src/api/voice_routes.py
- [ ] T027 [US1] Implement GET /api/voices endpoint
- [ ] T028 [US1] Implement GET /api/voices/{voice_id} endpoint
- [ ] T029 [US1] Implement GET /api/voices/{voice_id}/preview endpoint
- [ ] T030 [US1] Implement POST /api/stories/{story_id}/generate-audio endpoint
- [ ] T031 [US1] Register voice routes in main application
- [ ] T032 [P] [US1] Create VoiceService API client in lib/services/voice_service.dart
- [ ] T033 [P] [US1] Create VoiceProvider state management in lib/providers/voice_provider.dart
- [ ] T034 [US1] Create VoiceSelectionScreen in lib/screens/voice_selection_screen.dart
- [ ] T035 [US1] Implement voice list display with icons
- [ ] T036 [US1] Implement voice preview playback using just_audio
- [ ] T037 [US1] Integrate voice selection with story playback

**Checkpoint**: User Story 1 complete - children can select and use character voices

---

## Phase 4: User Story 2 - 下載額外聲音包 (Priority: P2)

**Goal**: Parents can download additional voice packs to expand voice options

**Independent Test**: Download a voice pack, verify new voices appear in selection list

### Tests for User Story 2

- [ ] T038 [P] [US2] Contract test for GET /api/voice-kits in tests/contract/test_voice_api.py
- [ ] T039 [P] [US2] Contract test for POST /api/voice-kits/{kit_id}/download in tests/contract/test_voice_api.py
- [ ] T040 [P] [US2] Contract test for DELETE /api/voice-kits/{kit_id} in tests/contract/test_voice_api.py

### Implementation for User Story 2

- [ ] T041 [US2] Create database migration for story_voice_maps table in src/migrations/
- [ ] T042 [US2] Implement list_voice_kits() in VoiceKitService
- [ ] T043 [US2] Implement download_voice_kit() in VoiceKitService
- [ ] T044 [US2] Implement delete_voice_kit() in VoiceKitService
- [ ] T045 [US2] Implement GET /api/voice-kits endpoint
- [ ] T046 [US2] Implement POST /api/voice-kits/{kit_id}/download endpoint
- [ ] T047 [US2] Implement DELETE /api/voice-kits/{kit_id} endpoint
- [ ] T048 [P] [US2] Create VoiceKitManagementScreen in lib/screens/voice_kit_management_screen.dart
- [ ] T049 [US2] Implement downloadable voice kit list display
- [ ] T050 [US2] Implement download progress indicator
- [ ] T051 [US2] Implement voice kit deletion with confirmation

**Checkpoint**: User Story 2 complete - users can download and manage voice packs

---

## Phase 5: User Story 3 - 混合使用家長聲音與角色聲音 (Priority: P2)

**Goal**: Parents can assign different voices to different story roles (narrator, characters)

**Independent Test**: Configure multi-voice story, verify each role uses assigned voice

### Tests for User Story 3

- [ ] T052 [P] [US3] Contract test for GET /api/users/{user_id}/voice-preference in tests/contract/test_voice_api.py
- [ ] T053 [P] [US3] Contract test for PUT /api/users/{user_id}/voice-preference in tests/contract/test_voice_api.py
- [ ] T054 [P] [US3] Unit test for multi-voice story generation in tests/unit/services/test_voice_kit_service.py

### Implementation for User Story 3

- [ ] T055 [P] [US3] Create VoicePreference model in src/models/voice.py
- [ ] T056 [P] [US3] Create StoryVoiceMap model in src/models/voice.py
- [ ] T057 [US3] Implement get_voice_preference() in VoiceKitService
- [ ] T058 [US3] Implement set_voice_preference() in VoiceKitService
- [ ] T059 [US3] Implement generate_multi_voice_audio() in VoiceKitService
- [ ] T060 [US3] Implement GET /api/users/{user_id}/voice-preference endpoint
- [ ] T061 [US3] Implement PUT /api/users/{user_id}/voice-preference endpoint
- [ ] T062 [US3] Extend POST /api/stories/{story_id}/generate-audio for voice_mappings
- [ ] T063 [P] [US3] Create VoiceConfigurationScreen in lib/screens/voice_configuration_screen.dart
- [ ] T064 [US3] Implement per-role voice assignment UI
- [ ] T065 [US3] Integrate multi-voice playback with story player

**Checkpoint**: User Story 3 complete - stories can use multiple voices

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T066 [P] Add structured logging for all TTS operations in src/services/tts/
- [ ] T067 [P] Implement TTS request caching in src/services/tts/cache.py
- [ ] T068 [P] Add voice attribution display ("Powered by Azure") in Flutter
- [ ] T069 [P] Add offline voice fallback handling
- [ ] T070 [P] Add error handling for TTS service failures
- [ ] T071 Run quickstart.md validation scenarios
- [ ] T072 Update API documentation with voice endpoints

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 -> P2 -> P2)
  - US2 and US3 are both P2, can be done in parallel if staffed
- **Polish (Phase 6)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Independent of US1
- **User Story 3 (P2)**: Can start after Foundational - Uses VoicePreference which is story-specific

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Backend before Flutter integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- All tests for a user story marked [P] can run in parallel
- Backend and Flutter models marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test for GET /api/voices in tests/contract/test_voice_api.py"
Task: "Contract test for GET /api/voices/{voice_id}/preview in tests/contract/test_voice_api.py"
Task: "Contract test for POST /api/stories/{story_id}/generate-audio in tests/contract/test_voice_api.py"
Task: "Unit test for VoiceKitService in tests/unit/services/test_voice_kit_service.py"
Task: "Integration test for Google TTS in tests/integration/test_google_tts.py"

# Launch backend and Flutter models together:
Task: "Create VoiceKit model in src/models/voice.py"
Task: "Create VoiceCharacter model in src/models/voice.py"
Task: "Create VoiceService API client in lib/services/voice_service.dart"
Task: "Create VoiceProvider state management in lib/providers/voice_provider.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test voice selection and playback
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test independently -> Deploy/Demo (MVP!)
3. Add User Story 2 -> Test independently -> Deploy/Demo
4. Add User Story 3 -> Test independently -> Deploy/Demo
5. Each story adds value without breaking previous stories

### Suggested MVP Scope

**MVP = User Story 1 only (20 tasks)**
- 6 built-in character voices
- Voice selection UI
- Voice preview playback
- Story audio generation with selected voice

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| Phase 1: Setup | 4 | Project initialization |
| Phase 2: Foundational | 9 | TTS abstraction, database schema |
| Phase 3: US1 (P1) | 24 | Select voice and play stories |
| Phase 4: US2 (P2) | 14 | Download voice packs |
| Phase 5: US3 (P2) | 14 | Multi-voice stories |
| Phase 6: Polish | 7 | Cross-cutting improvements |
| **Total** | **72** | |

### Tasks per User Story

| Story | Tasks | Priority |
|-------|-------|----------|
| User Story 1 | 24 | P1 (MVP) |
| User Story 2 | 14 | P2 |
| User Story 3 | 14 | P2 |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
