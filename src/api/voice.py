"""Voice profile API routes for StoryBuddy."""

import logging
from uuid import UUID

import aiofiles
from fastapi import APIRouter, BackgroundTasks, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse

from src.config import get_settings
from src.db.repository import ParentRepository, VoiceAudioRepository, VoiceProfileRepository
from src.models import VoiceProfileStatus
from src.models.voice import (
    VoiceAudioCreate,
    VoicePreviewRequest,
    VoiceProfile,
    VoiceProfileCreate,
    VoiceProfileResponse,
    VoiceProfileUpdate,
)
from src.services.voice_cloning import (
    VoiceCloningError,
    generate_preview_audio,
    process_voice_cloning,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voice-profiles", tags=["Voice"])
settings = get_settings()

# Allowed audio formats
ALLOWED_FORMATS = {"wav", "mp3", "m4a"}
ALLOWED_CONTENT_TYPES = {
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/mp4": "m4a",
    "audio/x-m4a": "m4a",
    "audio/m4a": "m4a",
}


def get_audio_format(content_type: str | None, filename: str | None) -> str | None:
    """Determine audio format from content type or filename."""
    if content_type and content_type in ALLOWED_CONTENT_TYPES:
        return ALLOWED_CONTENT_TYPES[content_type]

    if filename:
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext in ALLOWED_FORMATS:
            return ext

    return None


@router.post(
    "",
    response_model=VoiceProfileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new voice profile",
)
async def create_voice_profile(data: VoiceProfileCreate) -> VoiceProfile:
    """Create a new voice profile for a parent.

    The profile starts in 'pending' status until a voice sample is uploaded.
    """
    # Verify parent exists
    parent = await ParentRepository.get_by_id(data.parent_id)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Parent {data.parent_id} not found",
        )

    return await VoiceProfileRepository.create(data)


@router.get(
    "/{profile_id}",
    response_model=VoiceProfileResponse,
    summary="Get voice profile by ID",
)
async def get_voice_profile(profile_id: UUID) -> VoiceProfile:
    """Get a voice profile by its ID."""
    profile = await VoiceProfileRepository.get_by_id(profile_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Voice profile {profile_id} not found",
        )
    return profile


@router.get(
    "",
    response_model=list[VoiceProfileResponse],
    summary="List voice profiles",
)
async def list_voice_profiles(parent_id: UUID) -> list[VoiceProfile]:
    """List all voice profiles for a parent."""
    return await VoiceProfileRepository.get_by_parent_id(parent_id)


@router.delete(
    "/{profile_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a voice profile",
)
async def delete_voice_profile(profile_id: UUID) -> None:
    """Delete a voice profile and all associated audio files."""
    deleted = await VoiceProfileRepository.delete(profile_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Voice profile {profile_id} not found",
        )


@router.post(
    "/{profile_id}/upload",
    response_model=VoiceProfileResponse,
    summary="Upload voice sample",
)
async def upload_voice_sample(
    profile_id: UUID,
    background_tasks: BackgroundTasks,
    audio: UploadFile = File(..., description="Audio file (WAV, MP3, or M4A)"),
) -> VoiceProfile:
    """Upload a voice sample for cloning.

    The audio must be 30-180 seconds long.
    Supported formats: WAV, MP3, M4A.
    """
    # Get profile
    profile = await VoiceProfileRepository.get_by_id(profile_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Voice profile {profile_id} not found",
        )

    # Validate format
    audio_format = get_audio_format(audio.content_type, audio.filename)
    if audio_format is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format. Allowed: {', '.join(ALLOWED_FORMATS)}",
        )

    # Read file content
    content = await audio.read()
    file_size = len(content)

    # Basic size validation (rough estimate: 1MB ≈ 60s for compressed audio)
    max_size = 50 * 1024 * 1024  # 50MB max
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 50MB.",
        )

    # Save file
    profile_dir = settings.voice_samples_dir / str(profile_id)
    profile_dir.mkdir(parents=True, exist_ok=True)

    filename = f"sample.{audio_format}"
    file_path = profile_dir / filename

    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    # Create audio record
    # Note: Duration calculation would require audio processing library
    # For MVP, we'll estimate based on file size or accept duration from client
    estimated_duration = 60  # Placeholder - should use actual audio analysis

    audio_create = VoiceAudioCreate(
        voice_profile_id=profile_id,
        file_path=str(file_path),
        file_size_bytes=file_size,
        duration_seconds=estimated_duration,
        format=audio_format,  # type: ignore[arg-type]
    )
    await VoiceAudioRepository.create(audio_create)

    # Update profile status to processing
    update_data = VoiceProfileUpdate(
        name=None,
        elevenlabs_voice_id=None,
        status=VoiceProfileStatus.PROCESSING,
        sample_duration_seconds=estimated_duration,
    )
    updated_profile = await VoiceProfileRepository.update(profile_id, update_data)

    if updated_profile is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update profile",
        )

    # Trigger async voice cloning with ElevenLabs
    background_tasks.add_task(
        process_voice_cloning,
        profile_id,
        str(file_path),
        profile.name,
    )
    logger.info(f"Voice cloning task queued for profile {profile_id}")

    return updated_profile


@router.post(
    "/{profile_id}/preview",
    summary="Preview voice with text",
)
async def preview_voice(
    profile_id: UUID,
    request: VoicePreviewRequest,
) -> FileResponse:
    """Generate a preview audio using the cloned voice.

    The voice profile must be in 'ready' status.
    Returns the audio file as audio/mpeg content.
    """
    profile = await VoiceProfileRepository.get_by_id(profile_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Voice profile {profile_id} not found",
        )

    if profile.status != VoiceProfileStatus.READY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Voice profile is not ready. Current status: {profile.status.value}",
        )

    if not profile.elevenlabs_voice_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Voice profile does not have a valid voice ID",
        )

    try:
        audio_path = await generate_preview_audio(
            voice_id=profile.elevenlabs_voice_id,
            profile_id=profile_id,
            text=request.text,
        )

        return FileResponse(
            path=audio_path,
            media_type="audio/mpeg",
            filename=f"preview_{profile_id}.mp3",
        )

    except VoiceCloningError as e:
        logger.error(f"Preview generation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Preview generation failed: {e}",
        )
