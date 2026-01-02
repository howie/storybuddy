# Tasks: StoryBuddy MVP

**Input**: Design documents from `/docs/features/000-StoryBuddy-mvp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml

**Tests**: Tests follow TDD per Constitution v1.0.0 - write tests first, ensure they fail, then implement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Include exact file paths in descriptions

## Path Conventions

- **Backend API**: `src/` (Python FastAPI)
- **Mobile App**: `app/` (React Native + Expo)
- **Tests**: `tests/` (pytest)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create backend project structure per plan.md in src/
- [ ] T002 Initialize Python project with pyproject.toml and dependencies (fastapi, uvicorn, pydantic, aiosqlite, anthropic, elevenlabs, azure-cognitiveservices-speech)
- [ ] T003 [P] Configure ruff for linting in pyproject.toml
- [ ] T004 [P] Configure mypy for type checking in pyproject.toml
- [ ] T005 [P] Create .env.example with required environment variables (ELEVENLABS_API_KEY, AZURE_SPEECH_KEY, ANTHROPIC_API_KEY)
- [ ] T006 Create data directories structure (data/db/, data/audio/voice_samples/, data/audio/stories/, data/audio/qa_responses/, data/audio/parent_answers/)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T007 Create SQLite database schema in src/db/init.py (all tables from data-model.md)
- [ ] T008 [P] Implement config management in src/config.py (Settings class with pydantic-settings)
- [ ] T009 [P] Create FastAPI application entry point in src/main.py
- [ ] T010 [P] Implement base Pydantic models (enums) in src/models/__init__.py
- [ ] T011 Create Parent model in src/models/parent.py (shared by all stories)
- [ ] T012 Implement database repository base in src/db/repository.py (CRUD operations for Parent)
- [ ] T013 [P] Configure structured logging in src/main.py (JSON format per Constitution)
- [ ] T014 [P] Setup error handling middleware in src/main.py

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 家長錄製聲音樣本 (Priority: P1) 🎯 MVP

**Goal**: Parent can record voice sample (30-180 sec), preview, and save for voice cloning

**Independent Test**: POST voice sample → GET voice profile shows status → Preview audio plays back

### Tests for User Story 1

- [ ] T015 [P] [US1] Contract test for POST /api/v1/voice-profiles in tests/contract/test_voice_api.py
- [ ] T016 [P] [US1] Contract test for POST /api/v1/voice-profiles/{id}/upload in tests/contract/test_voice_api.py
- [ ] T017 [P] [US1] Contract test for POST /api/v1/voice-profiles/{id}/preview in tests/contract/test_voice_api.py
- [ ] T018 [P] [US1] Integration test for voice recording flow in tests/integration/test_voice_flow.py

### Implementation for User Story 1

- [ ] T019 [P] [US1] Create VoiceProfile model in src/models/voice.py
- [ ] T020 [P] [US1] Create VoiceAudio model in src/models/voice.py
- [ ] T021 [US1] Implement VoiceProfile repository in src/db/repository.py
- [ ] T022 [US1] Implement ElevenLabs voice cloning service in src/services/voice_cloning.py
- [ ] T023 [US1] Implement voice API routes in src/api/voice.py (create, list, get, delete profile)
- [ ] T024 [US1] Implement voice sample upload endpoint in src/api/voice.py (POST /upload)
- [ ] T025 [US1] Implement voice preview endpoint in src/api/voice.py (POST /preview)
- [ ] T026 [US1] Add audio file validation (duration 30-180 sec, format wav/mp3/m4a) in src/api/voice.py
- [ ] T027 [US1] Add voice cloning status polling mechanism in src/services/voice_cloning.py

**Checkpoint**: Voice recording and cloning functional - can demo independently

---

## Phase 4: User Story 2 - AI 用家長聲音講故事 (Priority: P1) 🎯 MVP

**Goal**: AI reads story aloud using cloned parent voice

**Independent Test**: GET story audio → Audio plays with cloned voice

**Dependencies**: Requires US1 (voice profile) to be complete

### Tests for User Story 2

- [ ] T028 [P] [US2] Contract test for POST /api/v1/stories/{id}/audio in tests/contract/test_story_audio_api.py
- [ ] T029 [P] [US2] Contract test for GET /api/v1/stories/{id}/audio in tests/contract/test_story_audio_api.py
- [ ] T030 [P] [US2] Integration test for story audio generation in tests/integration/test_story_audio_flow.py

### Implementation for User Story 2

- [ ] T031 [P] [US2] Create Story model in src/models/story.py
- [ ] T032 [US2] Implement Story repository in src/db/repository.py
- [ ] T033 [US2] Implement story audio generation using ElevenLabs TTS in src/services/voice_cloning.py
- [ ] T034 [US2] Implement story audio endpoints in src/api/stories.py (POST /audio, GET /audio)
- [ ] T035 [US2] Add audio file caching/storage in data/audio/stories/
- [ ] T036 [US2] Add playback controls metadata (duration, word_count) in Story model

**Checkpoint**: Story playback with cloned voice functional

---

## Phase 5: User Story 3 - 匯入外部故事 (Priority: P2)

**Goal**: Parent can import story text and save to story list

**Independent Test**: POST story with content → GET story list shows new story

### Tests for User Story 3

- [ ] T037 [P] [US3] Contract test for POST /api/v1/stories in tests/contract/test_story_api.py
- [ ] T038 [P] [US3] Contract test for GET /api/v1/stories in tests/contract/test_story_api.py
- [ ] T039 [P] [US3] Integration test for story import flow in tests/integration/test_story_import_flow.py

### Implementation for User Story 3

- [ ] T040 [US3] Implement story CRUD endpoints in src/api/stories.py (create, list, get, update, delete)
- [ ] T041 [US3] Add word count validation (max 5000) in src/api/stories.py
- [ ] T042 [US3] Add estimated_duration_minutes calculation in src/models/story.py
- [ ] T043 [US3] Add pagination support for story list in src/api/stories.py

**Checkpoint**: Story import functional

---

## Phase 6: User Story 4 - AI 編寫故事 (Priority: P2)

**Goal**: AI generates child-appropriate story from keywords

**Independent Test**: POST keywords → GET generated story with content

### Tests for User Story 4

- [ ] T044 [P] [US4] Contract test for POST /api/v1/stories/generate in tests/contract/test_story_generate_api.py
- [ ] T045 [P] [US4] Integration test for story generation flow in tests/integration/test_story_generate_flow.py

### Implementation for User Story 4

- [ ] T046 [US4] Implement Claude story generation service in src/services/story_generator.py
- [ ] T047 [US4] Add story generation prompt with child safety guidelines in src/services/story_generator.py
- [ ] T048 [US4] Implement generate story endpoint in src/api/stories.py (POST /generate)
- [ ] T049 [US4] Add content filtering for child-appropriate content in src/services/story_generator.py
- [ ] T050 [US4] Add regeneration support (multiple attempts) in src/api/stories.py

**Checkpoint**: AI story generation functional

---

## Phase 7: User Story 5 - 故事後問答互動 (Priority: P1) 🎯 MVP

**Goal**: Child can ask questions about story, AI responds with voice

**Independent Test**: POST question → GET AI response (text + audio) in child-friendly language

**Dependencies**: Requires US2 (story with audio) for context

### Tests for User Story 5

- [ ] T051 [P] [US5] Contract test for POST /api/v1/qa/sessions in tests/contract/test_qa_api.py
- [ ] T052 [P] [US5] Contract test for POST /api/v1/qa/sessions/{id}/messages in tests/contract/test_qa_api.py
- [ ] T053 [P] [US5] Integration test for Q&A flow in tests/integration/test_qa_flow.py

### Implementation for User Story 5

- [ ] T054 [P] [US5] Create QASession model in src/models/qa.py
- [ ] T055 [P] [US5] Create QAMessage model in src/models/qa.py
- [ ] T056 [US5] Implement QASession repository in src/db/repository.py
- [ ] T057 [US5] Implement Azure Speech recognition service in src/services/speech_recognition.py
- [ ] T058 [US5] Implement Claude Q&A handler in src/services/qa_handler.py
- [ ] T059 [US5] Add out-of-scope question detection in src/services/qa_handler.py
- [ ] T060 [US5] Implement Q&A session endpoints in src/api/qa.py (start, get, end session)
- [ ] T061 [US5] Implement message endpoint in src/api/qa.py (POST message with text or audio)
- [ ] T062 [US5] Add TTS response generation for AI answers in src/services/qa_handler.py
- [ ] T063 [US5] Add message count limit (max 10) enforcement in src/api/qa.py

**Checkpoint**: Q&A interaction functional

---

## Phase 8: User Story 6 - 記錄待詢問問題 (Priority: P2)

**Goal**: Out-of-scope questions saved for parent to answer later

**Independent Test**: Ask out-of-scope question → Question appears in pending list → Parent answers → AI can use parent answer

**Dependencies**: Requires US5 (Q&A) for out-of-scope detection

### Tests for User Story 6

- [ ] T064 [P] [US6] Contract test for GET /api/v1/questions in tests/contract/test_questions_api.py
- [ ] T065 [P] [US6] Contract test for POST /api/v1/questions/{id}/answer in tests/contract/test_questions_api.py
- [ ] T066 [P] [US6] Integration test for pending questions flow in tests/integration/test_pending_questions_flow.py

### Implementation for User Story 6

- [ ] T067 [P] [US6] Create PendingQuestion model in src/models/question.py
- [ ] T068 [US6] Implement PendingQuestion repository in src/db/repository.py
- [ ] T069 [US6] Implement questions endpoints in src/api/questions.py (list, get, answer)
- [ ] T070 [US6] Integrate out-of-scope detection with pending question creation in src/services/qa_handler.py
- [ ] T071 [US6] Add parent answer recording (text or audio) in src/api/questions.py
- [ ] T072 [US6] Add answered question lookup for future Q&A in src/services/qa_handler.py

**Checkpoint**: Pending questions workflow functional

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T073 [P] Update CLAUDE.md with final project structure
- [ ] T074 [P] Add API documentation generation (FastAPI auto-docs)
- [ ] T075 [P] Add request/response logging middleware in src/main.py
- [ ] T076 Run quickstart.md validation (manual test of all setup steps)
- [ ] T077 Security review: ensure API keys not in code, voice data handling compliant
- [ ] T078 Performance optimization: add caching for frequently accessed stories

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational
  - US1 (Voice Recording): Independent
  - US2 (Story Playback): Depends on US1 (needs voice profile)
  - US3 (Import Story): Independent (story CRUD)
  - US4 (Generate Story): Independent (uses Claude, not voice)
  - US5 (Q&A): Depends on US2 (needs story context)
  - US6 (Pending Questions): Depends on US5 (out-of-scope detection)
- **Polish (Phase 9)**: Depends on all user stories

### User Story Dependencies Graph

```
Phase 2 (Foundational)
    ├── US1 (Voice Recording) ──► US2 (Story Playback) ──► US5 (Q&A) ──► US6 (Pending Questions)
    ├── US3 (Import Story) ──────────────────────────────────────┘ (provides story content)
    └── US4 (Generate Story) ────────────────────────────────────┘ (provides story content)
```

### MVP Scope (P1 Stories Only)

For minimum viable product:
1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete US1: Voice Recording
4. Complete US3: Import Story (simpler than US4, provides story content)
5. Complete US2: Story Playback
6. Complete US5: Q&A Interaction

### Parallel Opportunities

```bash
# Phase 1 - All setup tasks in parallel:
T003, T004, T005 can run together

# Phase 2 - Foundational parallel tasks:
T008, T009, T010, T013, T014 can run together

# US1 Tests - All in parallel:
T015, T016, T017, T018 can run together

# US1 Models - In parallel:
T019, T020 can run together

# After Foundational, independent stories in parallel:
US1, US3, US4 can start simultaneously
```

---

## Implementation Strategy

### MVP First (P1 Stories)

1. Complete Setup + Foundational → Foundation ready
2. Complete US1 (Voice Recording) → Test voice cloning works
3. Complete US3 (Import Story) → Have story content to play
4. Complete US2 (Story Playback) → Demo: story plays with parent voice
5. Complete US5 (Q&A) → Demo: child can ask questions
6. **STOP and VALIDATE**: Core MVP complete, demo to stakeholders

### Incremental Delivery

1. MVP (Setup + Foundational + US1 + US3 + US2 + US5)
2. Add US4 (AI Story Generation) → Unlimited stories
3. Add US6 (Pending Questions) → Parent involvement

---

## Task Summary

| Phase | Task Count | Parallel | Story |
|-------|------------|----------|-------|
| Setup | 6 | 3 | - |
| Foundational | 8 | 5 | - |
| US1 (Voice) | 13 | 6 | P1 MVP |
| US2 (Playback) | 9 | 3 | P1 MVP |
| US3 (Import) | 7 | 3 | P2 |
| US4 (Generate) | 7 | 2 | P2 |
| US5 (Q&A) | 13 | 4 | P1 MVP |
| US6 (Pending) | 9 | 3 | P2 |
| Polish | 6 | 3 | - |
| **Total** | **78** | **32** | - |

**MVP Scope**: 49 tasks (Setup + Foundational + US1 + US3 + US2 + US5)
