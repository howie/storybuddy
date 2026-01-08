from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


from src.models import VoiceProfileStatus


class Gender(str, Enum):
    MALE = "male"
    FEMALE = "female"
    NEUTRAL = "neutral"


class AgeGroup(str, Enum):
    CHILD = "child"
    ADULT = "adult"
    SENIOR = "senior"


class VoiceStyle(str, Enum):
    NARRATOR = "narrator"    # For story narration
    CHARACTER = "character"  # For character dialogue
    BOTH = "both"           # Can be used for both


class TTSProvider(str, Enum):
    AZURE = "azure"
    GOOGLE = "google"
    ELEVENLABS = "elevenlabs"
    AMAZON = "amazon"


class VoiceProfileBase(BaseModel):
    """Base voice profile model with common fields."""

    name: str = Field(..., max_length=100, description="Voice profile name (e.g., '爸爸', '媽媽')")


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
    elevenlabs_voice_id: str | None = Field(None, description="ElevenLabs Voice ID after cloning")
    status: VoiceProfileStatus = Field(
        default=VoiceProfileStatus.PENDING, description="Voice cloning status"
    )
    sample_duration_seconds: int | None = Field(
        None, ge=30, le=180, description="Total sample duration in seconds"
    )
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
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


class VoiceCharacter(BaseModel):
    """Individual voice/character within a kit."""
    
    id: str = Field(..., description="Unique identifier")
    kit_id: str = Field(..., description="Parent kit ID")
    name: str = Field(..., max_length=50, description="Character name")
    provider_voice_id: str = Field(..., description="Provider's voice ID")
    ssml_options: Optional[Dict[str, Any]] = Field(None, description="SSML customization options")
    gender: Gender
    age_group: AgeGroup
    style: VoiceStyle
    preview_url: Optional[str] = Field(None, description="URL to preview audio")
    preview_text: Optional[str] = Field(None, max_length=200, description="Text used for preview")


class VoiceKit(BaseModel):
    """Collection of related voices."""
    
    id: str = Field(..., description="Unique identifier")
    name: str = Field(..., max_length=100, description="Display name")
    description: Optional[str] = Field(None, max_length=500, description="Kit description")
    provider: TTSProvider 
    version: str = Field(..., description="Kit version")
    download_size: int = Field(0, ge=0, description="Size in bytes")
    is_builtin: bool = Field(True, description="Whether kit is included by default")
    is_downloaded: bool = Field(False, description="Whether kit is downloaded locally")
    voices: List[VoiceCharacter] = Field(default_factory=list, description="Voices in this kit")
    created_at: datetime = Field(default_factory=datetime.utcnow)
