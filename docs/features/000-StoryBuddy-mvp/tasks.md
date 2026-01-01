# Tasks: StoryBuddy MVP

**Input**: Design documents from `/docs/features/000-StoryBuddy-mvp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml

**Tests**: Tests are not explicitly requested in the specification. Test tasks are omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `src/` at repository root (Python FastAPI)
- **Mobile App**: `app/src/` (React Native + Expo)
- **Tests**: `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create backend project structure with src/, tests/, data/ directories
- [ ] T002 Initialize Python project with pyproject.toml and dependencies (fastapi, uvicorn, pydantic, anthropic, elevenlabs, azure-cognitiveservices-speech, aiosqlite)
- [ ] T003 [P] Configure ruff for linting and formatting in pyproject.toml
- [ ] T004 [P] Create .env.example with required environment variables (ELEVENLABS_API_KEY, AZURE_SPEECH_KEY, AZURE_SPEECH_REGION, ANTHROPIC_API_KEY)
- [ ] T005 [P] Initialize React Native + Expo project in app/ directory with expo-av, react-native-track-player dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create config.py with Settings class using pydantic-settings in src/config.py
- [ ] T007 Create SQLite database schema from data-model.md in src/db/init.py
- [ ] T008 [P] Implement database repository with aiosqlite in src/db/repository.py
- [ ] T009 [P] Create shared Pydantic base models and enums in src/models/__init__.py
- [ ] T010 Create FastAPI app entry point with CORS middleware in src/main.py
- [ ] T011 [P] Create Parent model in src/models/parent.py
- [ ] T012 Configure structured logging in src/main.py
- [ ] T013 Create data directories (data/db/, data/audio/voice_samples/, data/audio/stories/, data/audio/qa_responses/, data/audio/parent_answers/)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 家長錄製聲音樣本 (Priority: P1) 🎯 MVP

**Goal**: 家長可以錄製 30-180 秒的中文語音樣本，系統建立聲音克隆模型

**Independent Test**: 家長完成錄音後，可以播放預覽，確認錄音品質，並儲存聲音樣本

### Implementation for User Story 1

- [ ] T014 [P] [US1] Create VoiceProfile model in src/models/voice.py
- [ ] T015 [P] [US1] Create VoiceAudio model in src/models/voice.py
- [ ] T016 [US1] Implement ElevenLabs voice cloning service in src/services/voice_cloning.py (clone voice, generate TTS, get voice status)
- [ ] T017 [US1] Implement VoiceProfile repository methods in src/db/repository.py (create, get, update, delete, list)
- [ ] T018 [US1] Implement VoiceAudio repository methods in src/db/repository.py (create, get by profile)
- [ ] T019 [US1] Implement voice profile API routes in src/api/voice.py (POST /voice-profiles, GET /voice-profiles, GET /voice-profiles/{id}, DELETE /voice-profiles/{id})
- [ ] T020 [US1] Implement voice sample upload endpoint in src/api/voice.py (POST /voice-profiles/{id}/upload with audio duration validation 30-180s)
- [ ] T021 [US1] Implement voice preview endpoint in src/api/voice.py (POST /voice-profiles/{id}/preview)
- [ ] T022 [US1] Register voice router in src/main.py
- [ ] T023 [P] [US1] Create RecordVoiceScreen in app/src/screens/RecordVoiceScreen.tsx (recording UI with timer, preview, save)
- [ ] T024 [P] [US1] Create useAudioRecorder hook in app/src/hooks/useAudioRecorder.ts (expo-av recording)
- [ ] T025 [US1] Create VoiceService API client in app/src/services/voiceService.ts

**Checkpoint**: At this point, User Story 1 should be fully functional - parent can record voice, upload, and preview cloned voice

---

## Phase 4: User Story 2 - AI 用家長聲音講故事 (Priority: P1) 🎯 MVP

**Goal**: AI 使用家長聲音模型朗讀故事，支援播放控制

**Independent Test**: 選擇故事後，可聽到 AI 用模仿家長聲音的方式講故事

**Dependencies**: Requires US1 (voice profile) and at least one story (US3 or US4)

### Implementation for User Story 2

- [ ] T026 [P] [US2] Create Story model in src/models/story.py
- [ ] T027 [US2] Implement Story repository methods in src/db/repository.py (create, get, update, delete, list)
- [ ] T028 [US2] Implement story audio generation in src/services/voice_cloning.py (generate_story_audio using ElevenLabs TTS with cloned voice)
- [ ] T029 [US2] Implement story audio API routes in src/api/stories.py (POST /stories/{id}/audio, GET /stories/{id}/audio)
- [ ] T030 [US2] Register stories router in src/main.py
- [ ] T031 [P] [US2] Create StoryPlayerScreen in app/src/screens/StoryPlayerScreen.tsx (play, pause, progress bar)
- [ ] T032 [P] [US2] Create useAudioPlayer hook in app/src/hooks/useAudioPlayer.ts (react-native-track-player for background play)
- [ ] T033 [US2] Create StoryService API client in app/src/services/storyService.ts
- [ ] T034 [US2] Implement story completion prompt UI in StoryPlayerScreen (「故事講完了！要開始問答嗎？」)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - parent can record voice and listen to stories with cloned voice

---

## Phase 5: User Story 3 - 匯入外部故事 (Priority: P2)

**Goal**: 家長可以匯入外部故事文本作為 AI 講故事的素材

**Independent Test**: 匯入一段故事文字後，可在故事列表中看到並選擇播放

### Implementation for User Story 3

- [ ] T035 [US3] Implement story CRUD API routes in src/api/stories.py (POST /stories, GET /stories, GET /stories/{id}, PUT /stories/{id}, DELETE /stories/{id})
- [ ] T036 [US3] Add word count calculation and validation (max 5000 chars) in src/api/stories.py
- [ ] T037 [P] [US3] Create StoryListScreen in app/src/screens/StoryListScreen.tsx (list stories, filter by source)
- [ ] T038 [P] [US3] Create ImportStoryModal component in app/src/components/ImportStoryModal.tsx (text input, title, save)
- [ ] T039 [US3] Integrate import story flow with StoryService in app/src/screens/StoryListScreen.tsx

**Checkpoint**: At this point, User Story 3 should work independently - parent can import stories

---

## Phase 6: User Story 4 - AI 編寫故事 (Priority: P2)

**Goal**: 家長可以給 AI 關鍵字或主題，讓 AI 創作適合兒童的原創故事

**Independent Test**: 輸入主題後，AI 生成一個完整故事並可播放

### Implementation for User Story 4

- [ ] T040 [US4] Implement Claude story generator service in src/services/story_generator.py (generate child-safe story from keywords)
- [ ] T041 [US4] Implement story generation API route in src/api/stories.py (POST /stories/generate)
- [ ] T042 [US4] Add content safety validation in src/services/story_generator.py (child-appropriate filter)
- [ ] T043 [P] [US4] Create GenerateStoryScreen in app/src/screens/GenerateStoryScreen.tsx (keyword input, age group selector, generate button)
- [ ] T044 [US4] Implement regenerate story feature in GenerateStoryScreen (「重新生成」button)

**Checkpoint**: At this point, User Story 4 should work independently - AI can generate stories from keywords

---

## Phase 7: User Story 5 - 故事後問答互動 (Priority: P1) 🎯 MVP

**Goal**: 故事講完後，小朋友可以語音提問，AI 用簡單語言回答故事相關問題

**Independent Test**: 故事播放完畢後，小朋友可以語音提問並獲得 AI 回答

**Dependencies**: Requires US2 (story playback complete) for optimal flow, but can work with any story

### Implementation for User Story 5

- [ ] T045 [P] [US5] Create QASession model in src/models/qa.py
- [ ] T046 [P] [US5] Create QAMessage model in src/models/qa.py
- [ ] T047 [US5] Implement QASession repository methods in src/db/repository.py (create, get, update, list by story)
- [ ] T048 [US5] Implement QAMessage repository methods in src/db/repository.py (create, list by session)
- [ ] T049 [US5] Implement Azure Speech STT service in src/services/speech_recognition.py (transcribe child audio to text, zh-TW support)
- [ ] T050 [US5] Implement Claude QA handler service in src/services/qa_handler.py (answer story questions, detect out-of-scope)
- [ ] T051 [US5] Implement TTS for QA responses in src/services/voice_cloning.py (generate audio response)
- [ ] T052 [US5] Implement QA session API routes in src/api/qa.py (POST /qa/sessions, GET /qa/sessions/{id}, PATCH /qa/sessions/{id})
- [ ] T053 [US5] Implement QA message API route in src/api/qa.py (POST /qa/sessions/{id}/messages with audio or text input)
- [ ] T054 [US5] Register qa router in src/main.py
- [ ] T055 [P] [US5] Create QAScreen in app/src/screens/QAScreen.tsx (voice input, message history, audio playback)
- [ ] T056 [P] [US5] Create useSpeechRecognition hook in app/src/hooks/useSpeechRecognition.ts (@react-native-voice/voice)
- [ ] T057 [US5] Create QAService API client in app/src/services/qaService.ts
- [ ] T058 [US5] Implement message limit (10 questions) and timeout handling in QAScreen

**Checkpoint**: At this point, User Story 5 should work - children can ask questions about the story

---

## Phase 8: User Story 6 - 記錄待詢問問題 (Priority: P2)

**Goal**: 超出故事範圍的問題被記錄，讓家長之後可以查看並回答

**Independent Test**: 小朋友問了故事外的問題後，家長可以在「問題清單」中看到

**Dependencies**: Requires US5 (out-of-scope detection triggers question recording)

### Implementation for User Story 6

- [ ] T059 [P] [US6] Create PendingQuestion model in src/models/question.py
- [ ] T060 [US6] Implement PendingQuestion repository methods in src/db/repository.py (create, get, update, list by parent, list by status)
- [ ] T061 [US6] Integrate out-of-scope detection with PendingQuestion creation in src/services/qa_handler.py
- [ ] T062 [US6] Implement pending questions API routes in src/api/questions.py (GET /questions, GET /questions/{id}, POST /questions/{id}/answer)
- [ ] T063 [US6] Register questions router in src/main.py
- [ ] T064 [P] [US6] Create PendingQuestionsScreen in app/src/screens/PendingQuestionsScreen.tsx (list questions, status filter)
- [ ] T065 [P] [US6] Create AnswerQuestionModal component in app/src/components/AnswerQuestionModal.tsx (text or audio answer)
- [ ] T066 [US6] Create QuestionsService API client in app/src/services/questionsService.ts
- [ ] T067 [US6] Implement answer playback when same question asked again in src/services/qa_handler.py

**Checkpoint**: At this point, User Story 6 should work - out-of-scope questions are recorded and parents can answer them

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T068 [P] Create HomeScreen with navigation to all features in app/src/screens/HomeScreen.tsx
- [ ] T069 [P] Setup React Navigation in app/src/App.tsx (stack navigator)
- [ ] T070 Add error handling middleware in src/main.py
- [ ] T071 [P] Add loading states and error messages in all screens
- [ ] T072 Implement offline story playback (download audio files) in StoryPlayerScreen
- [ ] T073 [P] Add privacy notice UI for voice data upload in RecordVoiceScreen
- [ ] T074 Run quickstart.md validation - verify all setup steps work

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 (P1): Can start immediately after Foundational
  - US2 (P1): Requires US1 for voice profile + needs at least one story (US3 or US4)
  - US3 (P2): Can start after Foundational
  - US4 (P2): Can start after Foundational
  - US5 (P1): Best after US2 but can work with any story
  - US6 (P2): Requires US5 for out-of-scope detection
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

| Story | Priority | Depends On | Can Start After |
|-------|----------|------------|-----------------|
| US1 - 錄製聲音 | P1 | - | Phase 2 |
| US2 - 講故事 | P1 | US1, (US3 or US4) | US1 + (US3 or US4) |
| US3 - 匯入故事 | P2 | - | Phase 2 |
| US4 - AI生成故事 | P2 | - | Phase 2 |
| US5 - 問答互動 | P1 | Story exists | Phase 2 + Story |
| US6 - 待詢問問題 | P2 | US5 | US5 |

### Within Each User Story

- Models before services (can run in parallel)
- Services before endpoints
- Backend endpoints before frontend screens
- Core implementation before integration

### Parallel Opportunities

- Phase 1: T003, T004, T005 can run in parallel
- Phase 2: T008, T009, T011 can run in parallel
- Phase 3 (US1): T014, T015, T023, T024 can run in parallel
- Phase 4 (US2): T026, T031, T032 can run in parallel
- Phase 5 (US3): T037, T038 can run in parallel
- Phase 7 (US5): T045, T046, T055, T056 can run in parallel
- Phase 8 (US6): T059, T064, T065 can run in parallel
- Phase 9: T068, T069, T071, T073 can run in parallel

---

## Parallel Example: Setup + Foundational

```bash
# Phase 1: Launch parallel setup tasks
Task: "Configure ruff for linting and formatting in pyproject.toml"
Task: "Create .env.example with required environment variables"
Task: "Initialize React Native + Expo project in app/ directory"

# Phase 2: Launch parallel foundational tasks
Task: "Implement database repository with aiosqlite in src/db/repository.py"
Task: "Create shared Pydantic base models and enums in src/models/__init__.py"
Task: "Create Parent model in src/models/parent.py"
```

## Parallel Example: User Story 1

```bash
# Launch parallel model creation
Task: "Create VoiceProfile model in src/models/voice.py"
Task: "Create VoiceAudio model in src/models/voice.py"

# Launch parallel frontend work (after models ready)
Task: "Create RecordVoiceScreen in app/src/screens/RecordVoiceScreen.tsx"
Task: "Create useAudioRecorder hook in app/src/hooks/useAudioRecorder.ts"
```

---

## Implementation Strategy

### MVP First (US1 + US3 + US2 + US5)

Minimal path to working demo:

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: US1 - 錄製聲音 (voice recording)
4. Complete Phase 5: US3 - 匯入故事 (story import - provides content)
5. Complete Phase 4: US2 - 講故事 (story playback with cloned voice)
6. Complete Phase 7: US5 - 問答互動 (Q&A after story)
7. **STOP and VALIDATE**: Test core loop independently
8. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (錄製聲音) → Test independently → Demo voice cloning
3. Add US3 (匯入故事) → Test independently → Demo story list
4. Add US2 (講故事) → Test independently → Demo full story playback
5. Add US5 (問答互動) → Test independently → Demo Q&A flow
6. Add US4 (AI生成故事) → Test independently → Demo AI story generation
7. Add US6 (待詢問問題) → Test independently → Demo parent answer flow
8. Polish → Production ready

---

## Summary

| Phase | User Story | Priority | Task Count |
|-------|------------|----------|------------|
| 1 | Setup | - | 5 |
| 2 | Foundational | - | 8 |
| 3 | US1 - 錄製聲音 | P1 | 12 |
| 4 | US2 - 講故事 | P1 | 9 |
| 5 | US3 - 匯入故事 | P2 | 5 |
| 6 | US4 - AI生成故事 | P2 | 5 |
| 7 | US5 - 問答互動 | P1 | 14 |
| 8 | US6 - 待詢問問題 | P2 | 9 |
| 9 | Polish | - | 7 |
| **Total** | | | **74** |

**MVP Scope**: Phase 1-2 (13 tasks) + US1 (12) + US3 (5) + US2 (9) + US5 (14) = **53 tasks**

**Parallel Opportunities**: 27 tasks marked [P] can run in parallel within their phases

**Independent Test Criteria**:
- US1: Parent can record voice, upload, and hear preview
- US2: Story plays with cloned parent voice
- US3: Imported story appears in list and can be selected
- US4: AI generates story from keywords
- US5: Child asks question, gets audio answer
- US6: Out-of-scope question appears in parent's list

---

## Notes

- [P] tasks = different files, no dependencies within phase
- [USx] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All file paths are relative to repository root
