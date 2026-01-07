"""Q&A session models for StoryBuddy."""

from datetime import datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

from src.models import MessageRole, QASessionStatus


class QASessionCreate(BaseModel):
    """Model for creating a new Q&A session."""

    story_id: UUID = Field(..., description="Story ID to discuss")


class QASessionUpdate(BaseModel):
    """Model for updating a Q&A session."""

    status: QASessionStatus | None = None
    ended_at: datetime | None = None


class QASession(BaseModel):
    """Full Q&A session model."""

    id: UUID = Field(default_factory=uuid4, description="Unique identifier")
    story_id: UUID = Field(..., description="Story being discussed")
    started_at: datetime = Field(default_factory=datetime.utcnow, description="Session start time")
    ended_at: datetime | None = Field(None, description="Session end time")
    message_count: int = Field(default=0, le=10, description="Number of messages in session")
    status: QASessionStatus = Field(default=QASessionStatus.ACTIVE, description="Session status")

    model_config = {"from_attributes": True}


class QASessionResponse(QASession):
    """Q&A session response model for API."""

    pass


class QASessionWithMessages(QASession):
    """Q&A session with messages included."""

    messages: list["QAMessageResponse"] = Field(default_factory=list)


class QAMessageCreate(BaseModel):
    """Model for creating a new Q&A message."""

    session_id: UUID = Field(..., description="Session this message belongs to")
    role: MessageRole = Field(..., description="Message sender role")
    content: str = Field(..., max_length=500, description="Message content")
    is_in_scope: bool | None = Field(None, description="Whether question is in story scope")
    audio_input_path: str | None = Field(None, description="Path to input audio")
    audio_output_path: str | None = Field(None, description="Path to output audio")
    sequence: int = Field(..., description="Message sequence number")


class QAMessage(BaseModel):
    """Full Q&A message model."""

    id: UUID = Field(default_factory=uuid4, description="Unique identifier")
    session_id: UUID = Field(..., description="Session this message belongs to")
    role: MessageRole = Field(..., description="Message sender role")
    content: str = Field(..., description="Message content")
    is_in_scope: bool | None = Field(None, description="Whether question is in story scope")
    audio_input_path: str | None = Field(None, description="Path to input audio")
    audio_output_path: str | None = Field(None, description="Path to output audio")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation time")
    sequence: int = Field(..., description="Message sequence number")

    model_config = {"from_attributes": True}


class QAMessageResponse(QAMessage):
    """Q&A message response model for API."""

    pass


class SendMessageRequest(BaseModel):
    """Request model for sending a Q&A message."""

    content: str = Field(..., max_length=500, description="Question text")


class SendMessageResponse(BaseModel):
    """Response model for Q&A message exchange."""

    user_message: QAMessageResponse
    assistant_message: QAMessageResponse
    is_in_scope: bool
    audio_url: str | None = None


class EndSessionRequest(BaseModel):
    """Request model for ending a Q&A session."""

    status: QASessionStatus = Field(..., description="Final status (completed or timeout)")
