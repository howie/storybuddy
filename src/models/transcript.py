"""
Transcript models for interactive story mode.

Feature: 006-interactive-story-mode
"""

from datetime import datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


class InteractionTranscriptBase(BaseModel):
    """Base schema for InteractionTranscript."""

    session_id: UUID


class InteractionTranscriptCreate(InteractionTranscriptBase):
    """Schema for creating an InteractionTranscript."""

    plain_text: str
    html_content: str
    turn_count: int = Field(ge=0)
    total_duration_ms: int = Field(ge=0)


class InteractionTranscript(InteractionTranscriptBase):
    """Complete interaction transcript for a session."""

    id: UUID = Field(default_factory=uuid4)
    plain_text: str
    html_content: str
    turn_count: int = Field(ge=0)
    total_duration_ms: int = Field(ge=0)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    email_sent_at: datetime | None = None

    @field_validator("plain_text", "html_content")
    @classmethod
    def content_must_not_be_empty(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Content must not be empty")
        return v

    class Config:
        from_attributes = True


class TranscriptSummary(BaseModel):
    """Summary view of a transcript for listing."""

    id: UUID
    session_id: UUID
    turn_count: int
    total_duration_ms: int
    created_at: datetime
    email_sent_at: datetime | None = None

    class Config:
        from_attributes = True
