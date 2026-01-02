"""Story model for StoryBuddy."""

from datetime import datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator

from src.config import get_settings
from src.models import StorySource

settings = get_settings()


class StoryBase(BaseModel):
    """Base story model with common fields."""

    title: str = Field(..., max_length=200, description="Story title")
    content: str = Field(..., description="Story content text")


class StoryCreate(StoryBase):
    """Model for creating a new story."""

    parent_id: UUID = Field(..., description="Parent ID who owns this story")
    source: StorySource = Field(..., description="Story source (imported or ai_generated)")
    keywords: list[str] | None = Field(
        None, description="Keywords used to generate the story (for AI-generated)"
    )

    @field_validator("content")
    @classmethod
    def validate_word_count(cls, v: str) -> str:
        """Validate that content does not exceed max word count."""
        word_count = len(v)
        if word_count > settings.max_story_word_count:
            msg = f"Story content exceeds maximum of {settings.max_story_word_count} characters"
            raise ValueError(msg)
        return v


class StoryUpdate(BaseModel):
    """Model for updating a story."""

    title: str | None = Field(None, max_length=200)
    content: str | None = None

    @field_validator("content")
    @classmethod
    def validate_word_count(cls, v: str | None) -> str | None:
        """Validate that content does not exceed max word count."""
        if v is not None:
            word_count = len(v)
            if word_count > settings.max_story_word_count:
                msg = f"Story content exceeds maximum of {settings.max_story_word_count} characters"
                raise ValueError(msg)
        return v


class Story(StoryBase):
    """Full story model with all fields."""

    id: UUID = Field(default_factory=uuid4, description="Unique identifier")
    parent_id: UUID = Field(..., description="Parent ID who owns this story")
    source: StorySource = Field(..., description="Story source")
    keywords: list[str] | None = Field(None, description="Generation keywords")
    word_count: int = Field(..., le=settings.max_story_word_count, description="Character count")
    estimated_duration_minutes: int | None = Field(
        None, description="Estimated reading time in minutes"
    )
    audio_file_path: str | None = Field(None, description="Path to generated audio file")
    audio_generated_at: datetime | None = Field(None, description="When audio was generated")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="Update timestamp")

    model_config = {"from_attributes": True}

    @staticmethod
    def calculate_word_count(content: str) -> int:
        """Calculate the word count of content."""
        return len(content)

    @staticmethod
    def calculate_duration_minutes(word_count: int) -> int:
        """Calculate estimated reading duration in minutes.

        Assumes ~200 characters per minute for Chinese text.
        """
        chars_per_minute = settings.words_per_minute
        return max(1, round(word_count / chars_per_minute))


class StoryResponse(Story):
    """Story response model for API."""

    pass


class StoryListResponse(BaseModel):
    """Paginated story list response."""

    items: list[StoryResponse]
    total: int
    limit: int
    offset: int
