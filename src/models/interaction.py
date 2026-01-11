"""
Interaction models for interactive story mode.

Feature: 006-interactive-story-mode
"""

from datetime import datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator

from .enums import NotificationFrequency, SessionMode, SessionStatus, TriggerType


class InteractionSessionBase(BaseModel):
    """Base schema for InteractionSession."""

    story_id: UUID
    parent_id: UUID
    mode: SessionMode = SessionMode.INTERACTIVE


class InteractionSessionCreate(InteractionSessionBase):
    """Schema for creating an InteractionSession."""

    pass


class InteractionSession(InteractionSessionBase):
    """Represents a single interactive storytelling session."""

    id: UUID = Field(default_factory=uuid4)
    started_at: datetime = Field(default_factory=datetime.utcnow)
    ended_at: datetime | None = None
    status: SessionStatus = SessionStatus.CALIBRATING
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("ended_at")
    @classmethod
    def ended_at_must_be_after_started_at(cls, v: datetime | None, info) -> datetime | None:
        if v is not None and "started_at" in info.data:
            if v <= info.data["started_at"]:
                raise ValueError("ended_at must be after started_at")
        return v

    class Config:
        from_attributes = True


class VoiceSegmentBase(BaseModel):
    """Base schema for VoiceSegment."""

    session_id: UUID
    sequence: int = Field(ge=1)


class VoiceSegmentCreate(VoiceSegmentBase):
    """Schema for creating a VoiceSegment."""

    started_at: datetime
    ended_at: datetime
    audio_format: str = "opus"
    is_recorded: bool = False


class VoiceSegment(VoiceSegmentBase):
    """Represents a segment of child speech during interaction."""

    id: UUID = Field(default_factory=uuid4)
    started_at: datetime
    ended_at: datetime
    transcript: str | None = None
    audio_url: str | None = None
    is_recorded: bool = False
    audio_format: str = "opus"
    duration_ms: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("ended_at")
    @classmethod
    def ended_at_must_be_after_started_at(cls, v: datetime, info) -> datetime:
        if "started_at" in info.data and v <= info.data["started_at"]:
            raise ValueError("ended_at must be after started_at")
        return v

    def model_post_init(self, __context) -> None:
        """Calculate duration_ms after initialization."""
        if self.started_at and self.ended_at:
            self.duration_ms = int((self.ended_at - self.started_at).total_seconds() * 1000)

    class Config:
        from_attributes = True


class AIResponseBase(BaseModel):
    """Base schema for AIResponse."""

    session_id: UUID
    text: str
    trigger_type: TriggerType


class AIResponseCreate(AIResponseBase):
    """Schema for creating an AIResponse."""

    voice_segment_id: UUID | None = None


class AIResponse(AIResponseBase):
    """Represents an AI response during interaction."""

    id: UUID = Field(default_factory=uuid4)
    voice_segment_id: UUID | None = None
    audio_url: str | None = None
    was_interrupted: bool = False
    interrupted_at_ms: int | None = None
    response_latency_ms: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("interrupted_at_ms")
    @classmethod
    def interrupted_at_ms_required_when_interrupted(cls, v: int | None, info) -> int | None:
        if info.data.get("was_interrupted") and v is None:
            raise ValueError("interrupted_at_ms is required when was_interrupted is True")
        return v

    @field_validator("voice_segment_id")
    @classmethod
    def voice_segment_required_for_child_speech(cls, v: UUID | None, info) -> UUID | None:
        if info.data.get("trigger_type") == TriggerType.CHILD_SPEECH and v is None:
            raise ValueError("voice_segment_id is required when trigger_type is CHILD_SPEECH")
        return v

    class Config:
        from_attributes = True


class InteractionSettingsBase(BaseModel):
    """Base schema for InteractionSettings."""

    recording_enabled: bool = False
    email_notifications: bool = True
    notification_frequency: NotificationFrequency = NotificationFrequency.DAILY


class InteractionSettingsUpdate(BaseModel):
    """Schema for updating InteractionSettings."""

    recording_enabled: bool | None = None
    email_notifications: bool | None = None
    notification_email: str | None = None
    notification_frequency: NotificationFrequency | None = None
    interruption_threshold_ms: int | None = Field(default=None, ge=200, le=2000)


class InteractionSettings(InteractionSettingsBase):
    """Parent's interaction mode preferences."""

    id: UUID = Field(default_factory=uuid4)
    parent_id: UUID
    notification_email: str | None = None
    interruption_threshold_ms: int = Field(default=500, ge=200, le=2000)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        from_attributes = True


class NoiseCalibrationBase(BaseModel):
    """Base schema for NoiseCalibration."""

    session_id: UUID


class NoiseCalibrationCreate(NoiseCalibrationBase):
    """Schema for creating NoiseCalibration."""

    noise_floor_db: float
    sample_count: int = Field(ge=1)
    percentile_90: float
    calibration_duration_ms: int = Field(ge=0)


class NoiseCalibration(NoiseCalibrationBase):
    """Environment noise calibration data for a session."""

    id: UUID = Field(default_factory=uuid4)
    noise_floor_db: float = Field(ge=-60, le=-20)
    calibrated_at: datetime = Field(default_factory=datetime.utcnow)
    sample_count: int = Field(ge=1)
    percentile_90: float
    calibration_duration_ms: int = Field(ge=0)

    class Config:
        from_attributes = True
