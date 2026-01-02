"""Pydantic models and enums for StoryBuddy."""

from enum import Enum


class VoiceProfileStatus(str, Enum):
    """Status of a voice profile in the cloning process."""

    PENDING = "pending"  # Waiting for upload
    PROCESSING = "processing"  # Voice model being created
    READY = "ready"  # Ready to use
    FAILED = "failed"  # Creation failed


class StorySource(str, Enum):
    """Source of story content."""

    IMPORTED = "imported"  # Parent imported
    AI_GENERATED = "ai_generated"  # AI generated


class QASessionStatus(str, Enum):
    """Status of a Q&A session."""

    ACTIVE = "active"  # In progress
    COMPLETED = "completed"  # Normally ended
    TIMEOUT = "timeout"  # Timed out


class MessageRole(str, Enum):
    """Role of a message in Q&A."""

    CHILD = "child"  # Child's message
    ASSISTANT = "assistant"  # AI response


class PendingQuestionStatus(str, Enum):
    """Status of a pending question."""

    PENDING = "pending"  # Awaiting answer
    ANSWERED = "answered"  # Answered by parent


__all__ = [
    "VoiceProfileStatus",
    "StorySource",
    "QASessionStatus",
    "MessageRole",
    "PendingQuestionStatus",
]
