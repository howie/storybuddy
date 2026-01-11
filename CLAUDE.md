# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StoryBuddy is a Python project currently in its initial setup phase. No source code exists yet.

## Development Setup

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install dependencies (when requirements exist)
pip install -r requirements.txt  # or use pyproject.toml with pip install -e .
```

## Commands

Commands will be added as the project develops. Expected tools based on .gitignore:
- **Testing:** `pytest`
- **Linting:** `ruff check .` or `ruff format .`
- **Type checking:** `mypy`

## Coding Conventions

- **Database Queries:** 不要直接寫 raw SQL，應使用 Query Builder（Python: SQLAlchemy, Flutter: Drift）

## License

Apache License 2.0

## Active Technologies
- Python 3.11 (000-StoryBuddy-mvp)
- SQLite（本地）+ Cloud Storage（語音檔案） (000-StoryBuddy-mvp)
- Dart 3.x / Flutter 3.x (latest stable) (001-flutter-mobile-app)
- Dart 3.x / Flutter 3.x (latest stable) + flutter_riverpod, go_router, dio, just_audio, audio_service, record, drift, flutter_secure_storage (001-flutter-mobile-app)
- SQLite (Drift) for local data, encrypted file cache for audio (001-flutter-mobile-app)
- Dart 3.x / Flutter 3.x (latest stable) + flutter_riverpod, go_router, dio, just_audio, record, drift (002-full-app-ui-flow)
- SQLite (Drift) for local data, flutter_secure_storage for sensitive data (002-full-app-ui-flow)
- Python 3.11 + FastAPI WebSocket, google-cloud-speech, anthropic, webrtcvad, jinja2 (006-interactive-story-mode)
- Dart 3.x / Flutter 3.x + web_socket_channel, opus_flutter, record (006-interactive-story-mode)

## 006-interactive-story-mode Feature Details

### Backend Services
- **WebSocket API** (`src/api/interaction.py`): Real-time bidirectional communication
- **VAD Service** (`src/services/interaction/vad_service.py`): Voice Activity Detection using webrtcvad
- **Streaming STT** (`src/services/interaction/streaming_stt.py`): Google Cloud Speech-to-Text
- **AI Responder** (`src/services/interaction/ai_responder.py`): Claude API for child-safe responses
- **Session Manager** (`src/services/interaction/session_manager.py`): Session lifecycle management
- **Transcript Generator** (`src/services/transcript/generator.py`): Generate session transcripts
- **Email Sender** (`src/services/transcript/email_sender.py`): SMTP email with Jinja2 templates

### Flutter Components
- **Audio Streamer** (`mobile/lib/core/audio/audio_streamer.dart`): Opus encoding and VAD integration
- **VAD Service** (`mobile/lib/core/audio/vad_service.dart`): Client-side voice activity detection
- **WebSocket Client** (`mobile/lib/core/network/websocket_client.dart`): Reconnection with exponential backoff
- **Noise Calibration** (`mobile/lib/features/interaction/data/services/noise_calibration_service.dart`): Ambient noise calibration
- **Interaction Provider** (`mobile/lib/features/interaction/presentation/providers/interaction_provider.dart`): State management with Riverpod

### Key Patterns
- TDD approach: Tests written before implementation
- Clean Architecture: Domain/Data/Presentation layers
- Freezed for immutable models in Flutter
- Structured logging for backend events

## Recent Changes
- 000-StoryBuddy-mvp: Added Python 3.11
- 006-interactive-story-mode: Implemented interactive story mode with:
  - Real-time audio streaming with Opus encoding
  - Voice Activity Detection (VAD) with noise calibration
  - AI-powered child-safe responses
  - Recording privacy controls
  - Transcript generation and email sharing
  - WebSocket reconnection with 60s idle timeout
