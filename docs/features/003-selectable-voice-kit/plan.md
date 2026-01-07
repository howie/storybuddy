# Implementation Plan: Selectable Voice Kit

**Branch**: `003-selectable-voice-kit` | **Date**: 2026-01-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/003-selectable-voice-kit/spec.md`

## Summary

Implement a selectable voice kit feature that allows children to choose from multiple character voices for story narration. **MVP Strategy**: Due to budget constraints and generous free tier limits, we will use **Google Cloud TTS** as the primary provider. We will simulate different character roles (Child, Elder) by manipulating SSML pitch and rate parameters on standard Traditional Chinese voices, deferring premium Azure/ElevenLabs integration to later phases.

## Technical Context

**Language/Version**: Python 3.11 (backend), Dart 3.x / Flutter 3.x (mobile)
**Primary Dependencies**: `google-cloud-texttospeech`, FastAPI, Flutter just_audio
**Storage**: SQLite (voice preferences), Cloud Storage (cached audio)
**Testing**: pytest (backend), flutter_test (mobile)
**Target Platform**: iOS 14+, Android 8+ (API 26), Linux server (backend)
**Project Type**: Mobile + API
**Performance Goals**: Voice preview <1s, story generation start <2s
**Constraints**: Must work offline for cached content
**Scale/Scope**: 6 built-in voices (simulated via SSML), expandable structure

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First | PASS | TDD for all new components |
| II. Modular Design | PASS | TTSProvider abstraction layer (critical for switching back to Azure later) |
| III. Security & Privacy | PASS | API keys server-side only |
| IV. Observability | PASS | Structured logging for TTS calls |
| V. Simplicity | PASS | Using SSML tweaks instead of multiple expensive models |
| Children's Safety | PASS | Generic voices, safe content |
| Privacy Requirements | PASS | Voice preferences local-first |

## Project Structure

### Documentation (this feature)

```text
docs/features/003-selectable-voice-kit/
├── plan.md              # This file
├── research.md          # TTS provider research
├── data-model.md        # Voice entities
├── quickstart.md        # Integration guide (Google updated)
├── contracts/           # API contracts
│   └── voice-api.yaml   # OpenAPI spec
└── tasks.md             # Implementation tasks
```

### Source Code (repository root)

```text
# Backend additions
src/
├── models/
│   └── voice.py              # VoiceKit, VoiceCharacter, VoicePreference
├── services/
│   ├── tts/
│   │   ├── __init__.py
│   │   ├── base.py           # TTSProvider abstract base
│   │   ├── google_tts.py     # Google implementation (MVP)
│   │   ├── azure_tts.py      # Azure implementation (Future)
│   │   └── elevenlabs_tts.py # ElevenLabs implementation (Future)
│   └── voice_kit_service.py  # Voice kit business logic
└── api/
    └── voice_routes.py       # Voice API endpoints
```

## Complexity Tracking

No constitution violations requiring justification.

## Technical Design

### TTSProvider Abstraction

```python
from abc import ABC, abstractmethod
from typing import AsyncGenerator

class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        options: dict | None = None
    ) -> bytes:
        """Generate speech audio from text."""
        pass
```

### Built-in Voice Configuration (Google MVP)

We use `cmn-TW-Wavenet-A` (Female) and `cmn-TW-Wavenet-B` (Male) as bases, modifying pitch/rate to create personas.

```python
BUILT_IN_VOICES = [
    VoiceCharacter(
        id="narrator-female",
        name="故事姐姐",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-A",
        ssml_options={"pitch": "0st", "rate": "1.0"},
        gender="female",
        age_group="adult",
        style="narrator",
        preview_text="大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！"
    ),
    VoiceCharacter(
        id="narrator-male",
        name="故事哥哥",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-B",
        ssml_options={"pitch": "0st", "rate": "1.0"},
        gender="male",
        age_group="adult",
        style="narrator",
        preview_text="嗨！我是故事哥哥，準備好聽故事了嗎？"
    ),
    VoiceCharacter(
        id="child-girl",
        name="小美",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-A",
        ssml_options={"pitch": "+4st", "rate": "1.05"},
        gender="female",
        age_group="child",
        style="character",
        preview_text="哈囉！我是小美，我們一起來冒險吧！"
    ),
    VoiceCharacter(
        id="child-boy",
        name="小明",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-B",
        ssml_options={"pitch": "+4st", "rate": "1.05"},
        gender="male",
        age_group="child",
        style="character",
        preview_text="嘿！我是小明，今天會發生什麼有趣的事呢？"
    ),
    VoiceCharacter(
        id="elder-female",
        name="故事阿嬤",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-A",
        ssml_options={"pitch": "-3st", "rate": "0.9"},
        gender="female",
        age_group="senior",
        style="narrator",
        preview_text="乖孫，阿嬤來講古早的故事給你聽..."
    ),
    VoiceCharacter(
        id="elder-male",
        name="故事阿公",
        provider="google",
        provider_voice_id="cmn-TW-Wavenet-B",
        ssml_options={"pitch": "-3st", "rate": "0.9"},
        gender="male",
        age_group="senior",
        style="narrator",
        preview_text="來，阿公說一個很久很久以前的故事..."
    ),
]
```

### Google SSML Generation

```python
def generate_ssml(text: str, voice_id: str, options: dict | None) -> str:
    # Google uses 'voice' tag but pitch/rate are handled via 'prosody'
    pitch = options.get("pitch", "0st")
    rate = options.get("rate", "1.0")
    
    return f'''
    <speak>
        <prosody pitch="{pitch}" rate="{rate}">
            {text}
        </prosody>
    </speak>'''
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/voices` | List available voices |
| GET | `/api/voices/{voice_id}` | Get voice details |
| GET | `/api/voices/{voice_id}/preview` | Get voice preview audio |
| POST | `/api/stories/{story_id}/generate-audio` | Generate story audio with voice |
| GET | `/api/users/{user_id}/voice-preference` | Get user's voice preference |
| PUT | `/api/users/{user_id}/voice-preference` | Set user's voice preference |

## Phase Summary

| Phase | Output | Status |
|-------|--------|--------|
| Phase 0 | research.md | Complete |
| Phase 1 | data-model.md, contracts/, quickstart.md | In Progress |
| Phase 2 | tasks.md | Pending (/speckit.tasks) |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Google Simulated voices sound unnatural | Tune pitch/rate parameters carefully; Accept as MVP trade-off |
| API rate limits | Implement caching, queue long requests |
| Network latency | Pre-generate popular story audio, cache aggressively |
| Cost overruns | Monitor usage, set alerts, implement quotas (Google has high free tier) |
