"""
Transcript Services.

This package provides services for generating and sharing interaction transcripts.

T073-T077 [US4] Transcript generation, email sending, and scheduling.
"""

from src.services.transcript.email_sender import (
    EmailSender,
    EmailSenderConfig,
    EmailSendResult,
)
from src.services.transcript.generator import TranscriptGenerator, TranscriptEntry
from src.services.transcript.scheduler import (
    TranscriptScheduler,
    SchedulerConfig,
    PendingTranscript,
    get_scheduler,
    start_transcript_scheduler,
    stop_transcript_scheduler,
)

__all__ = [
    # Email sender
    "EmailSender",
    "EmailSenderConfig",
    "EmailSendResult",
    # Generator
    "TranscriptGenerator",
    "TranscriptEntry",
    # Scheduler
    "TranscriptScheduler",
    "SchedulerConfig",
    "PendingTranscript",
    "get_scheduler",
    "start_transcript_scheduler",
    "stop_transcript_scheduler",
]
