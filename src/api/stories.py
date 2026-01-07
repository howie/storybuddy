"""Story API routes for StoryBuddy."""

from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Query, status
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from src.config import get_settings
from src.db.repository import ParentRepository, StoryRepository, VoiceProfileRepository
from src.models import StorySource, VoiceProfileStatus
from src.models.story import (
    Story,
    StoryCreate,
    StoryListResponse,
    StoryResponse,
    StoryUpdate,
)

settings = get_settings()


class GenerateAudioRequest(BaseModel):
    """Request model for generating story audio."""

    voice_profile_id: UUID


class GenerateAudioResponse(BaseModel):
    """Response model for audio generation request."""

    story_id: UUID
    status: str = "processing"


class ImportStoryRequest(BaseModel):
    """Request model for importing a story."""

    title: str = Field(..., max_length=200)
    content: str = Field(..., max_length=5000)


class GenerateStoryRequest(BaseModel):
    """Request model for generating a story with AI."""

    keywords: list[str] = Field(..., min_length=1, max_length=5)


router = APIRouter(prefix="/stories", tags=["stories"])


@router.post("", response_model=StoryResponse, status_code=status.HTTP_201_CREATED)
async def create_story(data: StoryCreate) -> Story:
    """Create a new story.

    - **parent_id**: UUID of the parent who owns this story
    - **title**: Story title (max 200 characters)
    - **content**: Story text content (max 5000 characters)
    - **source**: "imported" for external stories, "ai_generated" for AI-created
    - **keywords**: Optional list of keywords (for AI-generated stories)
    """
    # Verify parent exists
    parent = await ParentRepository.get_by_id(data.parent_id)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Parent not found",
        )

    story = await StoryRepository.create(data)
    return story


@router.get("", response_model=StoryListResponse)
async def list_stories(
    parent_id: UUID | None = Query(None, description="Parent ID to filter stories"),
    source: StorySource | None = Query(None, description="Filter by source"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of items"),
    offset: int = Query(0, ge=0, description="Number of items to skip"),
    x_parent_id: str | None = Header(None, alias="X-Parent-ID"),
) -> StoryListResponse:
    """List all stories for a parent with pagination.

    - **parent_id**: Parent ID to filter stories (query param or X-Parent-ID header)
    - **source**: Optional filter by "imported" or "ai_generated"
    - **limit**: Maximum items per page (1-100, default 20)
    - **offset**: Number of items to skip for pagination
    """
    # Use query param if provided, otherwise use header
    effective_parent_id = parent_id
    if effective_parent_id is None and x_parent_id:
        try:
            effective_parent_id = UUID(x_parent_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid X-Parent-ID header format",
            )

    if effective_parent_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="parent_id query parameter or X-Parent-ID header is required",
        )

    stories, total = await StoryRepository.get_by_parent_id(
        parent_id=effective_parent_id,
        source=source,
        limit=limit,
        offset=offset,
    )

    return StoryListResponse(
        items=[StoryResponse.model_validate(s.model_dump()) for s in stories],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post("/import", response_model=StoryResponse, status_code=status.HTTP_201_CREATED)
async def import_story(
    data: ImportStoryRequest,
    x_parent_id: str | None = Header(None, alias="X-Parent-ID"),
) -> Story:
    """Import a story from user-provided text.

    - **title**: Story title (max 200 characters)
    - **content**: Story text content (max 5000 characters)

    Requires X-Parent-ID header for authentication.
    """
    if not x_parent_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Parent-ID header is required",
        )

    try:
        parent_id = UUID(x_parent_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-Parent-ID header format",
        )

    # Verify parent exists
    parent = await ParentRepository.get_by_id(parent_id)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Parent not found",
        )

    story_data = StoryCreate(
        parent_id=parent_id,
        title=data.title,
        content=data.content,
        source=StorySource.IMPORTED,
    )

    story = await StoryRepository.create(story_data)
    return story


@router.post("/generate", response_model=StoryResponse, status_code=status.HTTP_201_CREATED)
async def generate_story(
    data: GenerateStoryRequest,
    x_parent_id: str | None = Header(None, alias="X-Parent-ID"),
) -> Story:
    """Generate a story using AI based on keywords.

    - **keywords**: List of keywords to inspire the story (1-5 keywords)

    Requires X-Parent-ID header for authentication.
    """
    if not x_parent_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Parent-ID header is required",
        )

    try:
        parent_id = UUID(x_parent_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-Parent-ID header format",
        )

    # Verify parent exists
    parent = await ParentRepository.get_by_id(parent_id)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Parent not found",
        )

    # Generate story using Claude
    from src.services.llm import get_claude_service

    try:
        claude = get_claude_service()
        result = await claude.generate_story(data.keywords)

        story_data = StoryCreate(
            parent_id=parent_id,
            title=result.title,
            content=result.content,
            source=StorySource.AI_GENERATED,
            keywords=data.keywords,
        )
    except ValueError as e:
        # API key not configured
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI service not configured: {e}",
        )
    except RuntimeError as e:
        # Claude API error
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI service error: {e}",
        )

    story = await StoryRepository.create(story_data)
    return story


@router.get("/{story_id}", response_model=StoryResponse)
async def get_story(story_id: UUID) -> Story:
    """Get a story by ID."""
    story = await StoryRepository.get_by_id(story_id)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )
    return story


@router.put("/{story_id}", response_model=StoryResponse)
async def update_story(story_id: UUID, data: StoryUpdate) -> Story:
    """Update a story.

    - **title**: Optional new title
    - **content**: Optional new content (will recalculate word_count and estimated_duration)
    """
    story = await StoryRepository.update(story_id, data)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )
    return story


@router.delete("/{story_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_story(story_id: UUID) -> None:
    """Delete a story by ID."""
    deleted = await StoryRepository.delete(story_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )


@router.post(
    "/{story_id}/audio",
    response_model=GenerateAudioResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def generate_story_audio(
    story_id: UUID, data: GenerateAudioRequest
) -> GenerateAudioResponse:
    """Generate audio for a story using a cloned voice.

    - **voice_profile_id**: UUID of the voice profile to use for TTS

    Returns 202 Accepted and begins processing. Poll the story endpoint
    to check if audio_file_path is populated.
    """
    # Verify story exists
    story = await StoryRepository.get_by_id(story_id)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )

    # Verify voice profile exists
    voice_profile = await VoiceProfileRepository.get_by_id(data.voice_profile_id)
    if voice_profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Voice profile not found",
        )

    # Check voice profile is ready
    if voice_profile.status != VoiceProfileStatus.READY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Voice profile is not ready for audio generation. Current status: {voice_profile.status.value}",
        )

    # TODO: Implement actual audio generation with ElevenLabs
    # For now, we just return a processing status
    # In a real implementation, this would:
    # 1. Queue an async task for audio generation
    # 2. Use ElevenLabs TTS with the cloned voice
    # 3. Save the audio file to data/audio/stories/
    # 4. Update the story with audio_file_path and audio_generated_at

    return GenerateAudioResponse(story_id=story_id, status="processing")


@router.get("/{story_id}/audio")
async def get_story_audio(story_id: UUID) -> FileResponse:
    """Get the generated audio file for a story.

    Returns the audio file as audio/mpeg content.
    """
    # Verify story exists
    story = await StoryRepository.get_by_id(story_id)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )

    # Check if audio has been generated
    if story.audio_file_path is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio has not been generated for this story",
        )

    # Verify file exists
    audio_path = Path(story.audio_file_path)
    if not audio_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio file not found on server",
        )

    return FileResponse(
        path=audio_path,
        media_type="audio/mpeg",
        filename=f"{story.title}.mp3",
    )
