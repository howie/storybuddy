# Quick Start: Interactive Story Mode

**Feature**: 006-interactive-story-mode
**Date**: 2026-01-11 (Updated)

## Prerequisites

### Backend
- Python 3.11+
- Google Cloud Speech-to-Text API credentials
- Anthropic Claude API key (for AI responses)
- Azure Speech Services key (for TTS)
- SMTP credentials for email sending (optional, for transcript sharing)

### Frontend (Flutter)
- Flutter 3.x (latest stable)
- Dart 3.x
- iOS 15+ / Android 10+
- Microphone permissions

---

## Backend Setup

### 1. Install Dependencies

```bash
cd /path/to/storybuddy

# Add new dependencies to pyproject.toml
pip install google-cloud-speech webrtcvad jinja2 aiosmtplib

# Or if using requirements.txt
pip install -r requirements.txt
```

### 2. Environment Variables

Add to `.env`:
```bash
# Google Speech-to-Text
GOOGLE_APPLICATION_CREDENTIALS=/path/to/google-credentials.json

# Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-xxx

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM=StoryBuddy <noreply@storybuddy.app>
```

### 3. Database Migration

```bash
# Using Alembic
alembic revision --autogenerate -m "Add interaction tables"
alembic upgrade head
```

### 4. Verify Setup

```bash
# Run backend
uvicorn src.main:app --reload

# Test WebSocket endpoint
websocat ws://localhost:8000/v1/ws/interaction/test-session
```

---

## Frontend Setup

### 1. Add Dependencies

Update `mobile/pubspec.yaml`:
```yaml
dependencies:
  # Existing dependencies...

  # New for interaction mode
  web_socket_channel: ^3.0.0
  opus_flutter: ^3.0.3
  opus_dart: ^3.0.0  # Required by opus_flutter for codec operations
  share_plus: ^12.0.1  # For transcript sharing
  battery_plus: ^6.0.0  # For battery monitoring
```

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. iOS Configuration

Update `ios/Runner/Info.plist`:
```xml
<!-- Microphone permission (should already exist) -->
<key>NSMicrophoneUsageDescription</key>
<string>StoryBuddy needs microphone access for interactive storytelling</string>
```

### 3. Android Configuration

Update `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Should already exist -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### 4. Run App

```bash
flutter run
```

---

## Quick Test

### Test Interactive Mode Flow

1. **Start Backend**
```bash
uvicorn src.main:app --reload --port 8000
```

2. **Create Test Session**
```bash
curl -X POST http://localhost:8000/v1/interactions/sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"storyId": "test-story-uuid", "mode": "interactive"}'
```

3. **Connect WebSocket**
```bash
websocat "ws://localhost:8000/v1/ws/interaction/SESSION_ID?token=YOUR_JWT_TOKEN"
```

4. **Send Test Audio**
Use the Flutter app or a test script to send Opus-encoded audio.

---

## Key Files Created

### Backend

| File | Description |
|------|-------------|
| `src/api/interaction.py` | WebSocket endpoint with message handlers |
| `src/api/transcripts.py` | REST endpoints for transcripts |
| `src/models/interaction.py` | SQLAlchemy models |
| `src/models/transcript.py` | Transcript models |
| `src/services/interaction/session_manager.py` | Session lifecycle |
| `src/services/interaction/vad_service.py` | Voice activity detection |
| `src/services/interaction/streaming_stt.py` | Google STT integration |
| `src/services/interaction/ai_response_handler.py` | Claude integration with safety filtering |
| `src/services/interaction/logging.py` | Structured event logging |
| `src/services/transcript/generator.py` | Transcript generation |
| `src/services/transcript/email_sender.py` | Email service |

### Frontend

| File | Description |
|------|-------------|
| `mobile/lib/core/audio/audio_streamer.dart` | Audio streaming with Opus encoding and VAD |
| `mobile/lib/core/audio/vad_service.dart` | Client-side Voice Activity Detection |
| `mobile/lib/core/network/websocket_client.dart` | WebSocket with reconnection and timeout |
| `mobile/lib/core/monitoring/battery_monitor.dart` | Battery usage tracking |
| `mobile/lib/features/interaction/data/services/noise_calibration_service.dart` | Noise calibration |
| `mobile/lib/features/interaction/presentation/providers/interaction_provider.dart` | State management |
| `mobile/lib/features/interaction/presentation/pages/interactive_playback_page.dart` | Main UI page |
| `mobile/lib/features/interaction/presentation/widgets/` | Reusable widgets |

---

## Development Workflow

### TDD Approach (Required by Constitution)

1. **Write Test First**
```python
# tests/unit/services/interaction/test_vad_service.py
def test_is_speech_detects_voice():
    vad = VADService()
    voice_audio = load_test_audio("voice_sample.opus")
    assert vad.is_speech(voice_audio) == True

def test_is_speech_ignores_silence():
    vad = VADService()
    silence_audio = load_test_audio("silence.opus")
    assert vad.is_speech(silence_audio) == False
```

2. **Run Test (Should Fail)**
```bash
pytest tests/unit/services/interaction/test_vad_service.py -v
# FAILED - No implementation yet
```

3. **Implement Minimal Code**
```python
# src/services/interaction/vad_service.py
import webrtcvad

class VADService:
    def __init__(self, mode: int = 2):
        self._vad = webrtcvad.Vad(mode)

    def is_speech(self, audio_frame: bytes, sample_rate: int = 16000) -> bool:
        return self._vad.is_speech(audio_frame, sample_rate)
```

4. **Run Test (Should Pass)**
```bash
pytest tests/unit/services/interaction/test_vad_service.py -v
# PASSED
```

5. **Refactor if Needed**

---

## Common Issues

### 1. WebSocket Connection Fails
- Check JWT token is valid
- Verify session ID exists
- Ensure backend WebSocket endpoint is running

### 2. Audio Not Being Recognized
- Verify Opus encoding is correct (16kHz, mono)
- Check Google Cloud credentials are set
- Ensure audio chunks are 20ms each

### 3. AI Response Timeout
- Check Anthropic API key
- Verify network connectivity
- Claude Haiku timeout is 30 seconds by default

### 4. Email Not Sending
- Verify SMTP credentials
- Check spam folder
- Ensure notification_email is valid

---

## Key Features Implemented

### User Story 1: Real-time Voice Interaction
- WebSocket-based bidirectional communication
- Opus audio encoding (16kHz, mono, 20ms frames)
- Client-side Voice Activity Detection (VAD)
- Noise calibration for optimal speech detection

### User Story 2: AI Safety and Response
- Content filtering for age-appropriate responses
- Story context-aware AI responses using Claude
- Response redirection for off-topic questions
- Fallback responses for sensitive topics

### User Story 3: Recording Privacy
- Privacy consent management
- Recording toggle in interaction settings
- Auto-delete policy configuration
- Secure storage with encryption

### User Story 4: Transcript and Sharing
- Automatic conversation transcript generation
- Email sharing with formatted transcripts
- Export to PDF functionality
- Transcript history management

### User Story 5: VAD Optimization
- Adaptive noise floor calibration
- Energy-based speech detection
- Silent frame filtering to reduce bandwidth
- Real-time VAD event streaming

### Phase 8 Polish
- WebSocket reconnection with exponential backoff
- 60-second idle timeout handling
- Structured logging for debugging
- Battery usage monitoring
- Loading states and error UI

## Next Steps

After setup is complete:
1. Run tests to verify implementation: `pytest tests/` and `flutter test`
2. Review the code following TDD workflow
3. Submit PR with passing tests
