# Tasks: Interactive Story Mode

**Input**: Design documents from `/docs/features/006-interactive-story-mode/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required by Constitution (Test-First principle is NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend (Python)**: `src/`, `tests/` at repository root
- **Frontend (Flutter)**: `mobile/lib/`, `mobile/test/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency setup

- [x] T001 Add backend dependencies (google-cloud-speech, webrtcvad, jinja2, aiosmtplib) to pyproject.toml
- [x] T002 [P] Add Flutter dependencies (web_socket_channel, opus_flutter) to mobile/pubspec.yaml
- [x] T003 [P] Create src/services/interaction/__init__.py package structure
- [x] T004 [P] Create src/services/transcript/__init__.py package structure
- [x] T005 [P] Create mobile/lib/features/interaction/ directory structure per plan.md
- [x] T006 [P] Create mobile/lib/core/network/websocket_client.dart stub
- [x] T007 Configure environment variables for GOOGLE_APPLICATION_CREDENTIALS in .env.example

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Backend Database Setup

- [x] T008 Create database migration for interaction tables in src/db/migrations/006_add_interaction_tables.py
- [x] T009 [P] Create Enum definitions (SessionMode, SessionStatus, TriggerType, NotificationFrequency) in src/models/enums.py
- [x] T010 Create InteractionSession model in src/models/interaction.py
- [x] T011 [P] Create VoiceSegment model in src/models/interaction.py
- [x] T012 [P] Create AIResponse model in src/models/interaction.py
- [x] T013 [P] Create InteractionTranscript model in src/models/transcript.py
- [x] T014 [P] Create InteractionSettings model in src/models/interaction.py
- [x] T015 [P] Create NoiseCalibration model in src/models/interaction.py
- [x] T016 Extend src/db/repository.py with interaction CRUD operations

### Frontend Database Setup

- [x] T017 Create Drift tables for interaction entities in mobile/lib/core/database/tables/interaction_tables.dart
- [x] T018 Update mobile/lib/core/database/database.dart to include new tables
- [x] T019 Run Drift code generation (flutter pub run build_runner build)

### Shared Entities (Flutter)

- [x] T020 [P] Create InteractionSession entity in mobile/lib/features/interaction/domain/entities/interaction_session.dart
- [x] T021 [P] Create VoiceSegment entity in mobile/lib/features/interaction/domain/entities/voice_segment.dart
- [x] T022 [P] Create AIResponse entity in mobile/lib/features/interaction/domain/entities/ai_response.dart

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 開始互動式故事體驗 (Priority: P1) 🎯 MVP

**Goal**: 讓孩子可以在故事播放中與 AI 進行即時語音互動

**Independent Test**: 選擇互動模式播放故事，說出問題，AI 暫停故事、回應問題、然後繼續播放

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T023 [P] [US1] Unit test for VAD service in tests/unit/services/interaction/test_vad_service.py
- [x] T024 [P] [US1] Unit test for streaming STT in tests/unit/services/interaction/test_streaming_stt.py
- [x] T025 [P] [US1] Unit test for session manager in tests/unit/services/interaction/test_session_manager.py
- [x] T026 [P] [US1] Contract test for WebSocket protocol in tests/contract/test_interaction_websocket.py
- [x] T027 [P] [US1] Integration test for interaction flow in tests/integration/test_interaction_flow.py
- [x] T028 [P] [US1] Widget test for interactive playback page in mobile/test/widget/features/interaction/interactive_playback_page_test.dart
- [x] T028-A [P] [US1] Unit test for mode switching logic in mobile/test/unit/features/interaction/mode_switching_test.dart

### Backend Implementation for User Story 1

- [x] T029 [US1] Implement VAD service using webrtcvad in src/services/interaction/vad_service.py
- [x] T030 [US1] Implement streaming STT service using google-cloud-speech in src/services/interaction/streaming_stt.py
- [x] T031 [US1] Implement session manager in src/services/interaction/session_manager.py
- [x] T032 [US1] Implement WebSocket endpoint for interaction in src/api/interaction.py
- [x] T033 [US1] Add WebSocket message handlers (audio, speech_started, speech_ended) in src/api/interaction.py
- [x] T034 [US1] Register interaction routes in src/main.py

### Frontend Implementation for User Story 1

- [x] T035 [P] [US1] Implement WebSocket client in mobile/lib/core/network/websocket_client.dart
- [x] T036 [P] [US1] Implement audio streamer with Opus encoding in mobile/lib/core/audio/audio_streamer.dart
- [x] T037 [US1] Implement interaction remote datasource in mobile/lib/features/interaction/data/datasources/interaction_remote_datasource.dart
- [x] T038 [US1] Implement interaction repository in mobile/lib/features/interaction/data/repositories/interaction_repository_impl.dart
- [x] T039 [US1] Implement start_interaction usecase in mobile/lib/features/interaction/domain/usecases/start_interaction.dart
- [x] T040 [US1] Implement stop_interaction usecase in mobile/lib/features/interaction/domain/usecases/stop_interaction.dart
- [x] T041 [US1] Implement interaction provider in mobile/lib/features/interaction/presentation/providers/interaction_provider.dart
- [x] T042 [US1] Create mode toggle widget in mobile/lib/shared/widgets/mode_toggle.dart
- [x] T043 [US1] Create interaction indicator widget in mobile/lib/features/interaction/presentation/widgets/interaction_indicator.dart
- [x] T044 [US1] Create interactive playback page in mobile/lib/features/interaction/presentation/pages/interactive_playback_page.dart
- [x] T045 [US1] Update existing story_detail_page.dart to add interactive playback button in mobile/lib/features/stories/presentation/pages/story_detail_page.dart
- [x] T045-A [US1] Implement mid-playback mode switching logic in mobile/lib/features/interaction/presentation/providers/interaction_provider.dart (FR-013: interactive→passive: close WebSocket, stop VAD, send end_session; passive→interactive: start calibration, establish WebSocket; sync story position)
- [x] T046 [US1] Add route for interactive playback in mobile/lib/app/router.dart

**Checkpoint**: User Story 1 完成 - 基本互動功能可獨立測試

---

## Phase 4: User Story 2 - 安全的 AI 對話範圍 (Priority: P1)

**Goal**: 確保 AI 回應限制在兒童安全的對話範圍內

**Independent Test**: 在互動模式中嘗試各種話題（包括離題內容），AI 應始終保持在故事相關範疇

### Tests for User Story 2 ⚠️

- [x] T047 [P] [US2] Unit test for AI responder safety in tests/unit/services/interaction/test_ai_responder.py
- [x] T048 [P] [US2] Unit test for content filter in tests/unit/services/interaction/test_content_filter.py
- [x] T049 [P] [US2] Integration test for safe AI responses in tests/integration/test_safe_ai_responses.py

### Backend Implementation for User Story 2

- [x] T050 [US2] Create child-safe system prompt template in src/services/interaction/prompts.py
- [x] T051 [US2] Implement AI responder with Claude integration in src/services/interaction/ai_responder.py
- [x] T052 [US2] Implement content filter for response validation in src/services/interaction/content_filter.py
- [x] T053 [US2] Integrate AI responder with WebSocket handler in src/api/interaction.py
- [x] T054 [US2] Extend TTS service to generate AI response audio in src/services/tts/azure_tts.py

### Frontend Implementation for User Story 2

- [x] T055 [US2] Display AI response text in interactive playback page in mobile/lib/features/interaction/presentation/pages/interactive_playback_page.dart
- [x] T056 [US2] Handle AI audio playback in interaction provider in mobile/lib/features/interaction/presentation/providers/interaction_provider.dart

**Checkpoint**: User Stories 1 AND 2 完成 - 核心互動功能與安全機制可用 ✅

---

## Phase 5: User Story 3 - 錄音隱私設定 (Priority: P2)

**Goal**: 讓家長可以控制是否錄製孩子的語音

**Independent Test**: 切換錄音設定後進行互動對話，檢查是否有錄音檔案產生

### Tests for User Story 3 ⚠️

- [x] T057 [P] [US3] Unit test for recording toggle in tests/unit/services/interaction/test_recording_service.py
- [x] T058 [P] [US3] Contract test for settings API in tests/contract/test_interaction_settings.py
- [x] T059 [P] [US3] Widget test for interaction settings page in mobile/test/widget/features/settings/interaction_settings_page_test.dart

### Backend Implementation for User Story 3

- [x] T060 [US3] Implement settings REST endpoints (GET/PUT) in src/api/transcripts.py
- [x] T061 [US3] Implement audio recording storage service in src/services/interaction/recording_service.py
- [x] T062 [US3] Integrate recording toggle with WebSocket handler in src/api/interaction.py
- [x] T063 [US3] Add 30-day retention cleanup job in src/services/interaction/retention_service.py

### Frontend Implementation for User Story 3

- [x] T064 [P] [US3] Create InteractionSettings model in mobile/lib/features/interaction/data/models/interaction_settings_model.dart
- [x] T065 [US3] Implement settings local datasource in mobile/lib/features/interaction/data/datasources/interaction_local_datasource.dart
- [x] T066 [US3] Create interaction settings page in mobile/lib/features/interaction/presentation/pages/interaction_settings_page.dart
- [x] T067 [US3] Implement settings provider in mobile/lib/features/interaction/presentation/providers/interaction_settings_provider.dart
- [x] T068 [US3] Create domain entities and repository in mobile/lib/features/interaction/domain/

**Checkpoint**: User Story 3 完成 - 隱私設定功能可用 ✅

---

## Phase 6: User Story 4 - 互動紀錄與分享 (Priority: P2)

**Goal**: 產生互動紀錄並允許家長透過郵件分享

**Independent Test**: 完成一次互動後，檢查是否產生紀錄，並測試郵件分享功能

### Tests for User Story 4 ⚠️

- [ ] T069 [P] [US4] Unit test for transcript generator in tests/unit/services/transcript/test_generator.py
- [ ] T070 [P] [US4] Unit test for email sender in tests/unit/services/transcript/test_email_sender.py
- [ ] T071 [P] [US4] Contract test for transcripts API in tests/contract/test_transcripts_api.py
- [ ] T072 [P] [US4] Widget test for transcript viewer in mobile/test/widget/features/interaction/transcript_viewer_test.dart

### Backend Implementation for User Story 4

- [ ] T073 [US4] Create HTML email template in src/services/transcript/templates/transcript_email.html
- [ ] T074 [US4] Implement transcript generator in src/services/transcript/generator.py
- [ ] T075 [US4] Implement email sender with SMTP in src/services/transcript/email_sender.py
- [ ] T076 [US4] Implement transcripts REST endpoints in src/api/transcripts.py
- [ ] T077 [US4] Implement scheduled email job (instant/daily/weekly) in src/services/transcript/scheduler.py
- [ ] T078 [US4] Generate transcript on session end in session_manager.py

### Frontend Implementation for User Story 4

- [ ] T079 [P] [US4] Create InteractionTranscript model in mobile/lib/features/interaction/data/models/interaction_transcript_model.dart
- [ ] T080 [US4] Implement transcript API methods in interaction remote datasource
- [ ] T081 [US4] Create transcript viewer widget in mobile/lib/features/interaction/presentation/widgets/transcript_viewer.dart
- [ ] T082 [US4] Create transcript history page in mobile/lib/features/interaction/presentation/pages/transcript_history_page.dart
- [ ] T083 [US4] Implement share transcript feature with share_plus in transcript viewer
- [ ] T084 [US4] Add notification frequency setting to interaction settings page

**Checkpoint**: User Story 4 完成 - 互動紀錄與分享功能可用

---

## Phase 7: User Story 5 - 語音活動偵測 (Priority: P3)

**Goal**: 智慧偵測語音活動，只在說話時傳送音訊，節省頻寬和電力

**Independent Test**: 在互動模式中觀察，靜音時不應有音訊傳送，開始說話時才傳送

### Tests for User Story 5 ⚠️

- [ ] T085 [P] [US5] Unit test for noise calibration in tests/unit/services/interaction/test_noise_calibration.py
- [ ] T086 [P] [US5] Unit test for client-side VAD in mobile/test/unit/features/interaction/vad_service_test.dart
- [ ] T087 [P] [US5] Integration test for VAD accuracy in tests/integration/test_vad_accuracy.py

### Backend Implementation for User Story 5

- [ ] T088 [US5] Implement noise calibration endpoint in src/api/interaction.py
- [ ] T089 [US5] Store and use noise calibration in session manager

### Frontend Implementation for User Story 5

- [ ] T090 [US5] Implement client-side VAD service in mobile/lib/core/audio/vad_service.dart
- [ ] T091 [US5] Implement noise calibration logic in mobile/lib/features/interaction/data/services/noise_calibration_service.dart
- [ ] T092 [US5] Create noise calibration dialog in mobile/lib/features/interaction/presentation/widgets/noise_calibration_dialog.dart
- [ ] T093 [US5] Integrate VAD with audio streamer to skip silent frames
- [ ] T094 [US5] Show calibration dialog before starting interactive mode

**Checkpoint**: User Story 5 完成 - 語音活動偵測優化可用

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T095 [P] Add error handling for network disconnection in WebSocket client
- [ ] T096 [P] Add reconnection logic with exponential backoff in WebSocket client
- [ ] T096-A [P] Implement WebSocket ping/pong heartbeat (30s interval) in mobile/lib/core/network/websocket_client.dart
- [ ] T096-B [P] Add server-side idle connection timeout handling (60s) in src/api/interaction.py
- [ ] T097 [P] Add loading states and error UI in interactive playback page
- [ ] T098 [P] Add structured logging for interaction events in backend
- [ ] T099 [P] Add battery usage monitoring in interaction provider
- [ ] T100 Run quickstart.md validation to verify setup instructions
- [ ] T101 Update CLAUDE.md with 006 feature technologies

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 & US2 can proceed in parallel (both P1)
  - US3 & US4 can proceed in parallel after US1 (both P2)
  - US5 can proceed after US1 (P3)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories ✅ MVP
- **User Story 2 (P1)**: Can start after Foundational - Integrates with US1 AI response path
- **User Story 3 (P2)**: Can start after US1 WebSocket is working - Uses session infrastructure
- **User Story 4 (P2)**: Can start after US1 - Generates transcripts from session data
- **User Story 5 (P3)**: Can start after US1 audio streaming is working - Optimizes audio path

### Entity to User Story Mapping

| Entity | User Stories | Created In |
|--------|--------------|------------|
| InteractionSession | US1, US3, US4, US5 | Foundational |
| VoiceSegment | US1, US3, US4 | Foundational |
| AIResponse | US1, US2, US4 | Foundational |
| InteractionTranscript | US4 | Foundational |
| InteractionSettings | US3, US4 | Foundational |
| NoiseCalibration | US5 | Foundational |

### Parallel Opportunities

**Phase 2 (Foundational)**:
```
T009, T011, T012, T013, T014, T015 can run in parallel (different model files)
T017 can run in parallel with backend models
T020, T021, T022 can run in parallel (different entity files)
```

**Phase 3 (User Story 1)**:
```
T023, T024, T025, T026, T027, T028 can run in parallel (test files)
T035, T036 can run in parallel (different core services)
```

**Cross-Story Parallelism**:
- After Foundational completes, US1 and US2 can be worked on in parallel
- After US1 completes, US3 and US4 can be worked on in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test for VAD service in tests/unit/services/interaction/test_vad_service.py"
Task: "Unit test for streaming STT in tests/unit/services/interaction/test_streaming_stt.py"
Task: "Unit test for session manager in tests/unit/services/interaction/test_session_manager.py"
Task: "Contract test for WebSocket protocol in tests/contract/test_interaction_websocket.py"

# Launch frontend core services together:
Task: "Implement WebSocket client in mobile/lib/core/network/websocket_client.dart"
Task: "Implement audio streamer with Opus encoding in mobile/lib/core/audio/audio_streamer.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test interactive mode independently
5. Deploy/demo if ready - basic interaction works!

### Recommended Order

1. **Setup + Foundational** → Foundation ready
2. **User Story 1** → 基本互動功能 (MVP)
3. **User Story 2** → 加入 AI 安全機制
4. **User Story 3** → 加入錄音隱私控制
5. **User Story 4** → 加入紀錄與分享
6. **User Story 5** → 加入效能優化
7. **Polish** → 完善細節

### Task Count Summary

| Phase | Task Count |
|-------|------------|
| Setup | 7 |
| Foundational | 15 |
| User Story 1 | 26 |
| User Story 2 | 10 |
| User Story 3 | 12 |
| User Story 4 | 16 |
| User Story 5 | 10 |
| Polish | 9 |
| **Total** | **105** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD required by Constitution)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
