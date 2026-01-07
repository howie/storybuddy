# Implementation Plan: Selectable Voice Kit

**Branch**: `003-selectable-voice-kit` | **Date**: 2026-01-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/003-selectable-voice-kit/spec.md`

## Summary

Implement a selectable voice kit feature that allows children to choose from multiple character voices for story narration. Primary approach uses Microsoft Azure TTS with SSML role-play for child voices, supplemented by a plugin architecture for future TTS provider expansion.

## Technical Context

**Language/Version**: Python 3.11 (backend), Dart 3.x / Flutter 3.x (mobile)
**Primary Dependencies**: Azure Cognitive Services Speech SDK, FastAPI, Flutter just_audio
**Storage**: SQLite (voice preferences), Cloud Storage (cached audio)
**Testing**: pytest (backend), flutter_test (mobile)
**Target Platform**: iOS 14+, Android 8+ (API 26), Linux server (backend)
**Project Type**: Mobile + API
**Performance Goals**: Voice preview <1s, story generation start <2s
**Constraints**: Must work offline for cached content
**Scale/Scope**: 6 built-in voices, expandable to downloadable voice packs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First | PASS | TDD for all new components |
| II. Modular Design | PASS | TTSProvider abstraction layer |
| III. Security & Privacy | PASS | API keys server-side only, no PII in voice requests |
| IV. Observability | PASS | Structured logging for TTS calls |
| V. Simplicity | PASS | 6 built-in voices, no over-engineering |
| Children's Safety | PASS | Original character voices, no IP infringement |
| Privacy Requirements | PASS | Voice preferences local-first |

## Project Structure

### Documentation (this feature)

```text
docs/features/003-selectable-voice-kit/
├── plan.md              # This file
├── research.md          # TTS provider research (complete)
├── data-model.md        # Voice entities
├── quickstart.md        # Integration guide
├── contracts/           # API contracts
│   └── voice-api.yaml   # OpenAPI spec
└── tasks.md             # Implementation tasks (from /speckit.tasks)
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
│   │   ├── azure_tts.py      # Azure implementation
│   │   ├── google_tts.py     # Google Cloud implementation (future)
│   │   └── elevenlabs_tts.py # ElevenLabs implementation (future)
│   └── voice_kit_service.py  # Voice kit business logic
└── api/
    └── voice_routes.py       # Voice API endpoints

tests/
├── unit/
│   └── services/
│       └── test_voice_kit_service.py
├── integration/
│   └── test_azure_tts.py
└── contract/
    └── test_voice_api_contract.py

# Flutter additions
lib/
├── models/
│   └── voice_kit.dart        # Voice models
├── services/
│   └── voice_service.dart    # Voice API client
├── providers/
│   └── voice_provider.dart   # State management
└── screens/
    └── voice_selection_screen.dart
```

**Structure Decision**: Mobile + API pattern, extending existing StoryBuddy backend and Flutter app.

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

    @abstractmethod
    async def synthesize_stream(
        self,
        text: str,
        voice_id: str,
        options: dict | None = None
    ) -> AsyncGenerator[bytes, None]:
        """Stream speech audio generation."""
        pass

    @abstractmethod
    async def get_preview(self, voice_id: str) -> bytes:
        """Get voice preview audio."""
        pass
```

### Built-in Voice Configuration

```python
BUILT_IN_VOICES = [
    VoiceCharacter(
        id="narrator-female",
        name="故事姐姐",
        provider="azure",
        provider_voice_id="zh-TW-HsiaoChenNeural",
        ssml_options=None,
        gender="female",
        age_group="adult",
        style="narrator",
        preview_text="大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！"
    ),
    VoiceCharacter(
        id="narrator-male",
        name="故事哥哥",
        provider="azure",
        provider_voice_id="zh-TW-YunJheNeural",
        ssml_options=None,
        gender="male",
        age_group="adult",
        style="narrator",
        preview_text="嗨！我是故事哥哥，準備好聽故事了嗎？"
    ),
    VoiceCharacter(
        id="child-girl",
        name="小美",
        provider="azure",
        provider_voice_id="zh-TW-HsiaoChenNeural",
        ssml_options={"role": "Girl", "style": "cheerful"},
        gender="female",
        age_group="child",
        style="character",
        preview_text="哈囉！我是小美，我們一起來冒險吧！"
    ),
    VoiceCharacter(
        id="child-boy",
        name="小明",
        provider="azure",
        provider_voice_id="zh-TW-YunJheNeural",
        ssml_options={"role": "Boy", "style": "cheerful"},
        gender="male",
        age_group="child",
        style="character",
        preview_text="嘿！我是小明，今天會發生什麼有趣的事呢？"
    ),
    VoiceCharacter(
        id="elder-female",
        name="故事阿嬤",
        provider="azure",
        provider_voice_id="zh-TW-HsiaoChenNeural",
        ssml_options={"role": "SeniorFemale", "style": "gentle"},
        gender="female",
        age_group="senior",
        style="narrator",
        preview_text="乖孫，阿嬤來講古早的故事給你聽..."
    ),
    VoiceCharacter(
        id="elder-male",
        name="故事阿公",
        provider="azure",
        provider_voice_id="zh-TW-YunJheNeural",
        ssml_options={"role": "SeniorMale", "style": "calm"},
        gender="male",
        age_group="senior",
        style="narrator",
        preview_text="來，阿公說一個很久很久以前的故事..."
    ),
]
```

### Azure SSML Generation

```python
def generate_ssml(text: str, voice_id: str, options: dict | None) -> str:
    voice_config = get_voice_config(voice_id)

    if options and "role" in options:
        return f'''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="zh-TW">
    <voice name="{voice_config.provider_voice_id}">
        <mstts:express-as role="{options['role']}" style="{options.get('style', 'general')}">
            {text}
        </mstts:express-as>
    </voice>
</speak>'''

    return f'''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-TW">
    <voice name="{voice_config.provider_voice_id}">
        {text}
    </voice>
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
| Azure SSML role quality inconsistent | Test all role combinations, fallback to base voice |
| API rate limits | Implement caching, queue long requests |
| Network latency | Pre-generate popular story audio, cache aggressively |
| Cost overruns | Monitor usage, set alerts, implement quotas |
