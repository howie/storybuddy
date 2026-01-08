"""Pending Question models for StoryBuddy."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from src.models import PendingQuestionStatus


class PendingQuestion(BaseModel):
    """A pending question from a child that needs parent answer."""

    id: UUID
    parent_id: UUID
    story_id: UUID | None = None
    qa_session_id: UUID | None = None
    question: str
    asked_at: datetime
    answer: str | None = None
    answer_audio_path: str | None = None
    answered_at: datetime | None = None
    status: PendingQuestionStatus = PendingQuestionStatus.PENDING


class PendingQuestionCreate(BaseModel):
    """Data required to create a pending question."""

    parent_id: UUID
    story_id: UUID | None = None
    qa_session_id: UUID | None = None
    question: str = Field(..., max_length=500)


class PendingQuestionAnswer(BaseModel):
    """Data for answering a pending question."""

    answer: str = Field(..., max_length=2000)


class PendingQuestionResponse(BaseModel):
    """Response model for pending question."""

    id: UUID
    parent_id: UUID
    story_id: UUID | None = None
    question: str
    asked_at: datetime
    answer: str | None = None
    answer_audio_path: str | None = None
    answered_at: datetime | None = None
    status: PendingQuestionStatus
