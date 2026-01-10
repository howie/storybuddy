# Tasks: Full App UI Flow

**Input**: Design documents from `/docs/features/002-full-app-ui-flow/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Included per Constitution requirement (Test-First / TDD approach)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile**: `mobile/lib/` for source, `mobile/test/` for tests
- Based on plan.md structure

---

## Phase 1: Setup

**Purpose**: No new project structure needed - using existing Flutter app

- [x] T001 Verify branch 002-full-app-ui-flow is checked out
- [x] T002 Run `flutter pub get` in mobile/ directory
- [x] T003 [P] Create shared widgets directory if not exists: mobile/lib/shared/widgets/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared widget that multiple user stories depend on

**⚠️ CRITICAL**: VoiceStatusIndicator is used by US1 and US5

### Test First

- [x] T004 [P] Write test for VoiceStatusIndicator widget in mobile/test/shared/widgets/voice_status_indicator_test.dart

### Implementation

- [x] T005 Create VoiceStatusIndicator widget in mobile/lib/shared/widgets/voice_status_indicator.dart
- [x] T006 Verify T004 test passes with VoiceStatusIndicator implementation

**Checkpoint**: Foundation ready - VoiceStatusIndicator available for all stories

---

## Phase 3: User Story 1 - 家長進入聲音錄製功能 (Priority: P1) 🎯 MVP

**Goal**: 家長可從導航選單進入聲音錄製頁面

**Independent Test**: 從故事列表頁面，透過 Drawer 進入聲音錄製頁面

### Tests for User Story 1

- [x] T007 [P] [US1] Write widget test for AppDrawer in mobile/test/features/stories/presentation/widgets/app_drawer_test.dart

### Implementation for User Story 1

- [x] T008 [US1] Create AppDrawer widget in mobile/lib/features/stories/presentation/widgets/app_drawer.dart
- [x] T009 [US1] Verify T007 test passes with AppDrawer implementation
- [x] T010 [US1] Modify StoryListPage to add Drawer in mobile/lib/features/stories/presentation/pages/story_list_page.dart
- [x] T011 [US1] Add hamburger menu icon to AppBar in story_list_page.dart
- [x] T012 [US1] Implement navigation to /voice-profile from drawer item

**Checkpoint**: User Story 1 complete - 家長可透過 Drawer 進入錄音頁面

---

## Phase 4: User Story 2 - 家長為故事生成語音 (Priority: P1)

**Goal**: 故事詳情頁面顯示「生成語音」按鈕，可觸發語音生成

**Independent Test**: 進入故事詳情頁，點擊「生成語音」按鈕，看到進度顯示

### Tests for User Story 2

- [x] T013 [P] [US2] Write/update widget test for StoryDetailPage FAB logic in mobile/test/features/stories/presentation/pages/story_detail_page_test.dart

### Implementation for User Story 2

- [x] T014 [US2] Add voiceProfileListProvider watcher in mobile/lib/features/stories/presentation/pages/story_detail_page.dart
- [x] T015 [US2] Implement FAB state logic (hasAudio ? play : hasVoice ? generate : record) in story_detail_page.dart
- [x] T016 [US2] Add generateAudio method call from FAB in story_detail_page.dart
- [x] T017 [US2] Implement audio generation progress indicator (SnackBar or overlay) in story_detail_page.dart
- [x] T018 [US2] Handle no voice profile case - navigate to /voice-profile with prompt
- [x] T019 [US2] Verify T013 test passes with updated StoryDetailPage

**Checkpoint**: User Story 2 complete - 家長可從故事詳情生成語音

---

## Phase 5: User Story 3 - 家長存取設定頁面 (Priority: P2)

**Goal**: 家長可從導航選單進入設定頁面

**Independent Test**: 從 Drawer 點擊「設定」，進入設定頁面

### Implementation for User Story 3

- [x] T020 [US3] Add 設定 ListTile to AppDrawer with navigation to /settings in mobile/lib/features/stories/presentation/widgets/app_drawer.dart
- [x] T021 [US3] Update AppDrawer test to verify settings navigation in mobile/test/features/stories/presentation/widgets/app_drawer_test.dart

**Checkpoint**: User Story 3 complete - 設定頁面可從 Drawer 進入

---

## Phase 6: User Story 4 - 家長查看待答問題 (Priority: P2)

**Goal**: 家長可從導航選單進入待答問題頁面

**Independent Test**: 從 Drawer 點擊「待答問題」，進入待答問題頁面

### Implementation for User Story 4

- [x] T022 [US4] Add 待答問題 ListTile to AppDrawer with navigation to /pending-questions in mobile/lib/features/stories/presentation/widgets/app_drawer.dart
- [x] T023 [US4] Add pending question count badge to drawer item (optional enhancement)
- [x] T024 [US4] Update AppDrawer test to verify pending questions navigation in mobile/test/features/stories/presentation/widgets/app_drawer_test.dart

**Checkpoint**: User Story 4 complete - 待答問題頁面可從 Drawer 進入

---

## Phase 7: User Story 5 - 導航選單顯示聲音狀態 (Priority: P3)

**Goal**: Drawer 中的錄製聲音選項顯示當前聲音模型狀態

**Independent Test**: 查看 Drawer 中聲音狀態顯示（尚未錄製/處理中/已就緒）

### Implementation for User Story 5

- [x] T025 [US5] Add voiceProfileListProvider watcher to AppDrawer in mobile/lib/features/stories/presentation/widgets/app_drawer.dart
- [x] T026 [US5] Integrate VoiceStatusIndicator into 錄製聲音 ListTile in app_drawer.dart
- [x] T027 [US5] Update AppDrawer test for voice status display in mobile/test/features/stories/presentation/widgets/app_drawer_test.dart

**Checkpoint**: User Story 5 complete - 聲音狀態正確顯示在 Drawer

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [x] T028 Run all tests: `flutter test` in mobile/ (229 passed, 1 skipped)
- [x] T029 Run manual test per quickstart.md checklist - PASSED on Android emulator
- [x] T030 [P] Update any code comments or documentation
- [ ] T031 Verify navigation works on iOS simulator (if available) - SKIPPED (no iOS simulator available)
- [x] T032 Verify navigation works on Android emulator - PASSED

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS US1 and US5 (VoiceStatusIndicator)
- **User Story 1 (Phase 3)**: Depends on Foundational (VoiceStatusIndicator used in Drawer)
- **User Story 2 (Phase 4)**: Depends on Setup only - can run parallel with US1
- **User Story 3 (Phase 5)**: Depends on US1 (Drawer must exist)
- **User Story 4 (Phase 6)**: Depends on US1 (Drawer must exist)
- **User Story 5 (Phase 7)**: Depends on US1 + Foundational (Drawer + VoiceStatusIndicator)
- **Polish (Phase 8)**: Depends on all stories complete

### User Story Dependencies

```
Setup (Phase 1)
    │
    ▼
Foundational (Phase 2) ─────────────────────────┐
    │                                            │
    ▼                                            │
US1: Drawer (Phase 3) ◄──────────────────────────┘
    │         │
    │         └──────────────┬──────────────┐
    ▼                        ▼              ▼
US3: Settings    US4: Pending Questions   US5: Voice Status
(Phase 5)        (Phase 6)                 (Phase 7)

US2: Audio Generation (Phase 4) ─── Independent, parallel with US1
```

### Parallel Opportunities

**After Setup:**
- T004 (VoiceStatusIndicator test) and T007 (AppDrawer test) and T013 (StoryDetailPage test) can all run in parallel

**After US1 Drawer is created:**
- US3, US4, US5 can all proceed in parallel (different ListTiles in same widget)

**Independent track:**
- US2 (Audio Generation) is completely independent and can run parallel with all other stories

---

## Parallel Example: Tests First

```bash
# Launch all tests in parallel after Setup:
Task: "Write test for VoiceStatusIndicator" (T004)
Task: "Write widget test for AppDrawer" (T007)
Task: "Write/update widget test for StoryDetailPage" (T013)
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (VoiceStatusIndicator)
3. Complete Phase 3: User Story 1 (Drawer navigation)
4. Complete Phase 4: User Story 2 (Audio generation button)
5. **STOP and VALIDATE**: Test core flow: Drawer → 錄音 → 故事 → 生成語音 → 播放
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (Drawer) → Test navigation → MVP Demo!
3. Add User Story 2 (Audio Gen) → Test full flow → Deploy/Demo
4. Add User Stories 3, 4, 5 → Complete navigation → Final Demo

### Recommended Execution Order

For single developer:
```
T001 → T002 → T003 → T004 → T005 → T006 (Setup + Foundational)
T007 → T008 → T009 → T010 → T011 → T012 (US1 - Drawer)
T013 → T014 → T015 → T016 → T017 → T018 → T019 (US2 - Audio)
T020 → T021 (US3 - Settings)
T022 → T023 → T024 (US4 - Pending Questions)
T025 → T026 → T027 (US5 - Voice Status)
T028 → T029 → T030 → T031 → T032 (Polish)
```

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story should be independently testable
- Write tests FIRST, ensure they FAIL before implementing (TDD)
- Commit after each task or logical group
- US2 is independent and can be worked on in parallel with US1
