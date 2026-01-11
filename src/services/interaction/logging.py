"""T098 [P] Structured logging for interaction events.

Provides structured logging utilities for interaction session events,
making it easier to analyze and debug interaction flows.
"""

import json
import logging
import time
from datetime import datetime
from enum import Enum
from functools import wraps
from typing import Any


class InteractionEventType(str, Enum):
    """Types of interaction events for logging."""

    # Session lifecycle
    SESSION_CREATED = "session_created"
    SESSION_ACTIVATED = "session_activated"
    SESSION_PAUSED = "session_paused"
    SESSION_RESUMED = "session_resumed"
    SESSION_ENDED = "session_ended"
    SESSION_ERROR = "session_error"

    # Calibration
    CALIBRATION_STARTED = "calibration_started"
    CALIBRATION_COMPLETED = "calibration_completed"
    CALIBRATION_FAILED = "calibration_failed"

    # Speech detection
    SPEECH_STARTED = "speech_started"
    SPEECH_ENDED = "speech_ended"
    VAD_EVENT = "vad_event"

    # Transcription
    TRANSCRIPTION_STARTED = "transcription_started"
    TRANSCRIPTION_PROGRESS = "transcription_progress"
    TRANSCRIPTION_COMPLETED = "transcription_completed"
    TRANSCRIPTION_FAILED = "transcription_failed"

    # AI response
    AI_PROCESSING_STARTED = "ai_processing_started"
    AI_RESPONSE_GENERATED = "ai_response_generated"
    AI_RESPONSE_REDIRECTED = "ai_response_redirected"
    AI_RESPONSE_FALLBACK = "ai_response_fallback"
    AI_INTERRUPTED = "ai_interrupted"

    # WebSocket
    WS_CONNECTED = "ws_connected"
    WS_DISCONNECTED = "ws_disconnected"
    WS_MESSAGE_RECEIVED = "ws_message_received"
    WS_MESSAGE_SENT = "ws_message_sent"
    WS_ERROR = "ws_error"

    # Performance
    LATENCY_MEASURED = "latency_measured"
    AUDIO_FRAME_PROCESSED = "audio_frame_processed"


class InteractionLogger:
    """Structured logger for interaction events.

    Usage:
        logger = InteractionLogger("session-123")
        logger.log_event(InteractionEventType.SPEECH_STARTED, {"duration_ms": 1500})
    """

    def __init__(
        self,
        session_id: str,
        logger_name: str = "interaction",
        include_timestamp: bool = True,
    ):
        """Initialize the interaction logger.

        Args:
            session_id: Session ID for all logged events.
            logger_name: Name of the Python logger to use.
            include_timestamp: Whether to include ISO timestamp in logs.
        """
        self.session_id = session_id
        self.logger = logging.getLogger(logger_name)
        self.include_timestamp = include_timestamp
        self._start_time = datetime.utcnow()

    def log_event(
        self,
        event_type: InteractionEventType,
        data: dict[str, Any] | None = None,
        level: int = logging.INFO,
    ) -> None:
        """Log a structured interaction event.

        Args:
            event_type: Type of event being logged.
            data: Additional event data.
            level: Logging level (default INFO).
        """
        event = {
            "event": event_type.value,
            "session_id": self.session_id,
            "elapsed_ms": self._get_elapsed_ms(),
        }

        if self.include_timestamp:
            event["timestamp"] = datetime.utcnow().isoformat() + "Z"

        if data:
            event["data"] = data

        # Log as JSON for structured parsing
        self.logger.log(level, json.dumps(event))

    def _get_elapsed_ms(self) -> int:
        """Get milliseconds elapsed since logger creation."""
        delta = datetime.utcnow() - self._start_time
        return int(delta.total_seconds() * 1000)

    # Convenience methods for common events

    def log_session_created(self, story_id: str, parent_id: str, mode: str) -> None:
        """Log session creation."""
        self.log_event(
            InteractionEventType.SESSION_CREATED,
            {"story_id": story_id, "parent_id": parent_id, "mode": mode},
        )

    def log_calibration_completed(self, noise_floor_db: float, sample_count: int) -> None:
        """Log calibration completion."""
        self.log_event(
            InteractionEventType.CALIBRATION_COMPLETED,
            {"noise_floor_db": round(noise_floor_db, 1), "sample_count": sample_count},
        )

    def log_speech_started(self, segment_id: str) -> None:
        """Log speech start detection."""
        self.log_event(
            InteractionEventType.SPEECH_STARTED,
            {"segment_id": segment_id},
        )

    def log_speech_ended(self, segment_id: str, duration_ms: int) -> None:
        """Log speech end detection."""
        self.log_event(
            InteractionEventType.SPEECH_ENDED,
            {"segment_id": segment_id, "duration_ms": duration_ms},
        )

    def log_transcription_completed(self, text: str, confidence: float, latency_ms: int) -> None:
        """Log transcription completion."""
        self.log_event(
            InteractionEventType.TRANSCRIPTION_COMPLETED,
            {
                "text_length": len(text),
                "confidence": round(confidence, 3),
                "latency_ms": latency_ms,
            },
        )

    def log_ai_response(
        self,
        response_id: str,
        was_redirected: bool,
        is_fallback: bool,
        latency_ms: int,
    ) -> None:
        """Log AI response generation."""
        event_type = InteractionEventType.AI_RESPONSE_GENERATED
        if was_redirected:
            event_type = InteractionEventType.AI_RESPONSE_REDIRECTED
        elif is_fallback:
            event_type = InteractionEventType.AI_RESPONSE_FALLBACK

        self.log_event(
            event_type,
            {
                "response_id": response_id,
                "was_redirected": was_redirected,
                "is_fallback": is_fallback,
                "latency_ms": latency_ms,
            },
        )

    def log_session_ended(self, duration_ms: int, turn_count: int) -> None:
        """Log session end."""
        self.log_event(
            InteractionEventType.SESSION_ENDED,
            {"duration_ms": duration_ms, "turn_count": turn_count},
        )

    def log_error(self, error_code: str, message: str, recoverable: bool = True) -> None:
        """Log an error event."""
        self.log_event(
            InteractionEventType.SESSION_ERROR,
            {
                "error_code": error_code,
                "message": message,
                "recoverable": recoverable,
            },
            level=logging.ERROR,
        )

    def log_ws_connected(self) -> None:
        """Log WebSocket connection."""
        self.log_event(InteractionEventType.WS_CONNECTED)

    def log_ws_disconnected(self, reason: str = "normal") -> None:
        """Log WebSocket disconnection."""
        self.log_event(
            InteractionEventType.WS_DISCONNECTED,
            {"reason": reason},
        )

    def log_latency(self, operation: str, latency_ms: int) -> None:
        """Log a latency measurement."""
        self.log_event(
            InteractionEventType.LATENCY_MEASURED,
            {"operation": operation, "latency_ms": latency_ms},
        )


def measure_latency(logger: InteractionLogger, operation: str):
    """Decorator to measure and log function latency.

    Args:
        logger: InteractionLogger instance.
        operation: Name of the operation being measured.
    """

    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.perf_counter()
            result = await func(*args, **kwargs)
            latency_ms = int((time.perf_counter() - start) * 1000)
            logger.log_latency(operation, latency_ms)
            return result

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            start = time.perf_counter()
            result = func(*args, **kwargs)
            latency_ms = int((time.perf_counter() - start) * 1000)
            logger.log_latency(operation, latency_ms)
            return result

        import asyncio

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    return decorator


# Module-level loggers registry
_session_loggers: dict[str, InteractionLogger] = {}


def get_logger(session_id: str) -> InteractionLogger:
    """Get or create an InteractionLogger for a session.

    Args:
        session_id: Session ID.

    Returns:
        InteractionLogger instance.
    """
    if session_id not in _session_loggers:
        _session_loggers[session_id] = InteractionLogger(session_id)
    return _session_loggers[session_id]


def cleanup_logger(session_id: str) -> None:
    """Remove a session logger when session ends.

    Args:
        session_id: Session ID to clean up.
    """
    if session_id in _session_loggers:
        del _session_loggers[session_id]
