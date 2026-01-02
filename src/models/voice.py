"""Voice profile and audio models for StoryBuddy."""

from datetime import datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

from src.models import VoiceProfileStatus


class VoiceProfileBase(BaseModel):
    """Base voice profile model with common fields."""

    name: str = Field(
        ..., max_length=100, description="Voice profile name (e.g., '爸爸', '媽媽')"
    )


class VoiceProfileCreate(VoiceProfileBase):
    """Model for creating a new voice profile."""

    parent_id: UUID = Field(..., description="Parent ID this voice belongs to")


class VoiceProfileUpdate(BaseModel):
    """Model for updating a voice profile."""

    name: str | None = Field(None, max_length=100)
    elevenlabs_voice_id: str | None = Field(None, max_length=100)
    status: VoiceProfileStatus | None = None
    sample_duration_seconds: int | None = Field(None, ge=30, le=180)


class VoiceProfile(VoiceProfileBase):
    """Full voice profile model with all fields."""

    id: UUID = Field(default_factory=uuid4, description="Unique identifier")
    parent_id: UUID = Field(..., description="Parent ID this voice belongs to")
    elevenlabs_voice_id: str | None = Field(
        None, description="ElevenLabs Voice ID after cloning"
    )
    status: VoiceProfileStatus = Field(
        default=VoiceProfileStatus.PENDING, description="Voice cloning status"
    )
    sample_duration_seconds: int | None = Field(
        None, ge=30, le=180, description="Total sample duration in seconds"
    )
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Creation timestamp"
    )
    updated_at: datetime = Field(
        default_factory=datetime.utcnow, description="Last update timestamp"
    )

    model_config = {"from_attributes": True}


class VoiceProfileResponse(VoiceProfile):
    """Voice profile response model for API."""

    pass


# Voice Audio models
class VoiceAudioBase(BaseModel):
    """Base voice audio model."""

    pass


class VoiceAudioCreate(VoiceAudioBase):
    """Model for creating a voice audio record."""

    voice_profile_id: UUID
    file_path: str
    file_size_bytes: int
    duration_seconds: int
    format: Literal["wav", "mp3", "m4a"]


class VoiceAudio(VoiceAudioBase):
    """Full voice audio model."""

    id: UUID = Field(default_factory=uuid4)
    voice_profile_id: UUID
    file_path: str
    file_size_bytes: int
    duration_seconds: int
    format: Literal["wav", "mp3", "m4a"]
    created_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {"from_attributes": True}


# Request/Response models for API
class VoicePreviewRequest(BaseModel):
    """Request model for voice preview."""

    text: str = Field(..., min_length=1, max_length=500, description="Text to preview")


class VoicePreviewResponse(BaseModel):
    """Response model for voice preview."""

    audio_url: str = Field(..., description="URL to preview audio file")
    duration_seconds: float = Field(..., description="Audio duration")
