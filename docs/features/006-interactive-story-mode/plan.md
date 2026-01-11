# Implementation Plan: Interactive Story Mode

**Branch**: `006-interactive-story-mode` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/006-interactive-story-mode/spec.md`

## Summary

實作互動式講故事模式，讓孩子可以在故事播放過程中與 AI 進行即時語音對話。系統使用 WebSocket 進行即時音訊串流，採用 Opus 16kHz 編碼，並透過 Google Speech-to-Text 進行語音辨識。AI 回應受限於兒童安全的對話範圍，家長可選擇是否錄製對話並透過郵件接收互動紀錄。

## Technical Context

**Language/Version**:
- Backend: Python 3.11
- Frontend: Dart 3.x / Flutter 3.x (latest stable)

**Primary Dependencies**:
- Backend: FastAPI, WebSocket, google-cloud-speech, anthropic (Claude)
- Frontend: flutter_riverpod, go_router, web_socket_channel, record, just_audio, opus_dart

**Storage**:
- SQLite (Drift) for local data
- Cloud Storage for audio recordings (optional)
- Backend PostgreSQL/SQLite for interaction sessions

**Testing**:
- Backend: pytest
- Frontend: flutter_test, integration_test

**Target Platform**: iOS 15+, Android 10+

**Project Type**: Mobile + API

**Performance Goals**:
- < 3 秒 AI 回應延遲 (SC-003)
- 95% 語音偵測準確率 (SC-002)

**Constraints**:
- 即時串流需穩定網路連線
- 電池消耗 < 150% 單向模式 (SC-007)
- 音訊頻寬 20-40 kbps (Opus 16kHz)

**Scale/Scope**: 單一家庭使用，MVP 階段

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First (NON-NEGOTIABLE) | ✅ PASS | 將為所有新功能編寫測試 |
| II. Modular Design | ✅ PASS | 採用 Clean Architecture，API/Service/Data 分層 |
| III. Security & Privacy | ✅ PASS | 錄音需家長同意、預設不錄音、資料保留 30 天 |
| IV. Observability | ✅ PASS | WebSocket 連線狀態、語音偵測事件將記錄日誌 |
| V. Simplicity | ✅ PASS | MVP 範圍明確，不含未來功能（template 提問點） |
| Children's Safety Standards | ✅ PASS | AI 受限於安全對話範圍、家長可查看紀錄 |
| Privacy Requirements | ✅ PASS | 同意機制、最小化資料收集、刪除權 |

## Project Structure

### Documentation (this feature)

```text
docs/features/006-interactive-story-mode/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
# Backend (Python)
src/
├── api/
│   ├── interaction.py        # NEW: WebSocket endpoint for interaction
│   └── transcripts.py        # NEW: REST endpoints for transcripts
├── models/
│   ├── interaction.py        # NEW: InteractionSession, VoiceSegment, etc.
│   └── transcript.py         # NEW: InteractionTranscript model
├── services/
│   ├── interaction/          # NEW: Interaction mode services
│   │   ├── __init__.py
│   │   ├── session_manager.py
│   │   ├── vad_service.py        # Voice Activity Detection
│   │   ├── streaming_stt.py      # Streaming Speech-to-Text
│   │   └── ai_responder.py       # Safe AI response generation
│   ├── transcript/           # NEW: Transcript services
│   │   ├── __init__.py
│   │   ├── generator.py
│   │   └── email_sender.py
│   └── tts/                  # Existing, extend for streaming
└── db/
    └── repository.py         # Extend for new entities

tests/
├── unit/
│   ├── services/
│   │   └── interaction/      # NEW: Unit tests
│   └── api/
│       └── test_interaction.py
├── integration/
│   └── test_interaction_flow.py   # NEW: E2E interaction tests
└── contract/
    └── test_interaction_api.py    # NEW: API contract tests

# Frontend (Flutter)
mobile/lib/
├── core/
│   ├── audio/
│   │   ├── audio_handler.dart       # Existing
│   │   ├── audio_streamer.dart      # NEW: WebSocket audio streaming
│   │   └── vad_service.dart         # NEW: Voice Activity Detection
│   └── network/
│       └── websocket_client.dart    # NEW: WebSocket client
├── features/
│   ├── interaction/              # NEW: Interaction mode feature
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── interaction_remote_datasource.dart
│   │   │   │   └── interaction_local_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── interaction_repository_impl.dart
│   │   │   └── models/
│   │   │       ├── interaction_session_model.dart
│   │   │       └── voice_segment_model.dart
│   │   ├── domain/
│   │   │   ├── repositories/
│   │   │   │   └── interaction_repository.dart
│   │   │   ├── entities/
│   │   │   │   ├── interaction_session.dart
│   │   │   │   ├── voice_segment.dart
│   │   │   │   └── ai_response.dart
│   │   │   └── usecases/
│   │   │       ├── start_interaction.dart
│   │   │       └── stop_interaction.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── interaction_provider.dart
│   │       ├── pages/
│   │       │   └── interactive_playback_page.dart
│   │       └── widgets/
│   │           ├── interaction_indicator.dart
│   │           ├── noise_calibration_dialog.dart
│   │           └── transcript_viewer.dart
│   ├── playback/                 # Existing, extend
│   │   └── presentation/
│   │       └── pages/
│   │           └── playback_page.dart   # Add mode toggle
│   └── settings/                 # Existing, extend
│       └── presentation/
│           └── pages/
│               └── interaction_settings_page.dart   # NEW
└── shared/
    └── widgets/
        └── mode_toggle.dart      # NEW: Single/Interactive toggle

mobile/test/
├── unit/
│   └── features/interaction/     # NEW: Unit tests
├── widget/
│   └── features/interaction/     # NEW: Widget tests
└── integration/
    └── interaction_flow_test.dart   # NEW: E2E tests
```

**Structure Decision**: Mobile + API 架構，前端採用 Clean Architecture（data/domain/presentation 分層），後端採用模組化設計（api/services/db 分層）。

## Complexity Tracking

> No violations identified. All features align with Constitution principles.

