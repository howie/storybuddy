"""
Enum definitions for interactive story mode.

Feature: 006-interactive-story-mode
"""

from enum import Enum


class SessionMode(str, Enum):
    """Story playback mode."""

    INTERACTIVE = "interactive"
    PASSIVE = "passive"


class SessionStatus(str, Enum):
    """Interaction session status."""

    CALIBRATING = "calibrating"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    ERROR = "error"


class TriggerType(str, Enum):
    """What triggered an AI response."""

    CHILD_SPEECH = "child_speech"
    STORY_PROMPT = "story_prompt"  # Future: template-based prompts
    TIMEOUT = "timeout"


class NotificationFrequency(str, Enum):
    """Frequency of transcript email notifications."""

    INSTANT = "instant"
    DAILY = "daily"
    WEEKLY = "weekly"
