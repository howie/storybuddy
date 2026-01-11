"""Interactive Story Mode Services.

This package provides services for real-time voice interaction during story playback:
- VADService: Voice Activity Detection using webrtcvad
- StreamingSTTService: Real-time speech-to-text using Google Cloud Speech
- SessionManager: Manages interaction session lifecycle
- AIResponder: AI response generation with child safety
- ContentFilter: Content filtering for child safety
- RecordingService: Audio recording with privacy controls
- RetentionService: Automated cleanup of expired recordings
"""

from src.services.interaction.vad_service import (
    VADService,
    VADConfig,
    CalibrationResult,
    VADEvent,
)
from src.services.interaction.streaming_stt import (
    StreamingSTTService,
    StreamingSTTConfig,
    TranscriptionResult,
)
from src.services.interaction.session_manager import (
    SessionManager,
    SessionState,
    SessionEvent,
)
from src.services.interaction.ai_responder import (
    AIResponder,
    AIResponderConfig,
    ResponseContext,
    AIResponse,
    TriggerType,
)
from src.services.interaction.content_filter import (
    ContentFilter,
    ContentFilterConfig,
    FilterResult,
    ContentCategory,
)
from src.services.interaction.recording_service import (
    RecordingService,
    RecordingServiceConfig,
    Recording,
    RecordingStatus,
    get_recording_service,
)
from src.services.interaction.retention_service import (
    RetentionService,
    RetentionServiceConfig,
    get_retention_service,
    start_retention_service,
    stop_retention_service,
)

__all__ = [
    # VAD Service
    "VADService",
    "VADConfig",
    "CalibrationResult",
    "VADEvent",
    # STT Service
    "StreamingSTTService",
    "StreamingSTTConfig",
    "TranscriptionResult",
    # Session Manager
    "SessionManager",
    "SessionState",
    "SessionEvent",
    # AI Responder
    "AIResponder",
    "AIResponderConfig",
    "ResponseContext",
    "AIResponse",
    "TriggerType",
    # Content Filter
    "ContentFilter",
    "ContentFilterConfig",
    "FilterResult",
    "ContentCategory",
    # Recording Service
    "RecordingService",
    "RecordingServiceConfig",
    "Recording",
    "RecordingStatus",
    "get_recording_service",
    # Retention Service
    "RetentionService",
    "RetentionServiceConfig",
    "get_retention_service",
    "start_retention_service",
    "stop_retention_service",
]
