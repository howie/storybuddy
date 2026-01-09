# Implementation Plan: Full App UI Flow

**Branch**: `002-full-app-ui-flow` | **Date**: 2026-01-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/002-full-app-ui-flow/spec.md`

## Summary

補齊 StoryBuddy 行動應用程式的 UI 導航流程，讓所有已實作的功能頁面（錄製聲音、設定、待答問題）都可以從主介面存取。同時在故事詳情頁面加入「生成語音」按鈕，連接錄音和播放功能。

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (latest stable)
**Primary Dependencies**: flutter_riverpod, go_router, dio, just_audio, record, drift
**Storage**: SQLite (Drift) for local data, flutter_secure_storage for sensitive data
**Testing**: flutter_test, mocktail, integration_test
**Target Platform**: iOS 14+, Android 8+ (API 26), macOS (development)
**Project Type**: Mobile app with backend API
**Performance Goals**: Navigation transitions under 300ms, audio generation progress updates every 500ms
**Constraints**: Offline-capable for cached content, network required for audio generation
**Scale/Scope**: Single-family use, ~10 screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First | ✅ PASS | Will write widget tests before implementing Drawer and audio generation button |
| II. Modular Design | ✅ PASS | Using existing layer separation (features/, core/, shared/) |
| III. Security & Privacy | ✅ PASS | No new sensitive data handling; voice profile status uses existing secure APIs |
| IV. Observability | ✅ PASS | Navigation events logged via go_router; audio generation progress tracked |
| V. Simplicity | ✅ PASS | Using Flutter's built-in Drawer widget; minimal new code |
| Children's Safety | ✅ PASS | No content changes; navigation only |
| Privacy Requirements | ✅ PASS | No new data collection |

**Gate Result**: PASS - All principles satisfied

## Project Structure

### Documentation (this feature)

```text
docs/features/002-full-app-ui-flow/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no new APIs)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
mobile/
├── lib/
│   ├── app/
│   │   ├── router.dart           # Existing - no changes needed
│   │   └── theme.dart            # Existing
│   ├── core/
│   │   └── ...                   # Existing infrastructure
│   ├── features/
│   │   ├── stories/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── story_list_page.dart    # MODIFY: Add Drawer
│   │   │       │   └── story_detail_page.dart  # MODIFY: Add generate audio FAB
│   │   │       └── widgets/
│   │   │           └── app_drawer.dart         # NEW: Navigation drawer
│   │   ├── playback/
│   │   │   └── presentation/
│   │   │       └── providers/
│   │   │           └── playback_provider.dart  # MODIFY: Expose generateAudio
│   │   ├── voice_profile/
│   │   │   └── presentation/
│   │   │       └── providers/
│   │   │           └── voice_profile_provider.dart  # Use existing
│   │   ├── settings/              # Existing - accessed via drawer
│   │   └── pending_questions/     # Existing - accessed via drawer
│   └── shared/
│       └── widgets/
│           └── voice_status_indicator.dart  # NEW: Status badge widget
└── test/
    ├── features/
    │   └── stories/
    │       └── presentation/
    │           ├── widgets/
    │           │   └── app_drawer_test.dart       # NEW
    │           └── pages/
    │               └── story_detail_page_test.dart # MODIFY
    └── shared/
        └── widgets/
            └── voice_status_indicator_test.dart   # NEW
```

**Structure Decision**: Using existing feature-based structure. New widgets added to appropriate feature modules. Shared `VoiceStatusIndicator` widget in `shared/widgets/` for reuse.

## Complexity Tracking

No violations - all implementations use standard Flutter patterns and existing infrastructure.
