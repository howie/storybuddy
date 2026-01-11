"""REST API for Interaction Settings and Transcripts.

T060 [US3] Implement settings REST endpoints (GET/PUT).
T076 [US4] Implement transcripts REST endpoints.
Provides endpoints for managing interaction settings and transcripts.
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from uuid import UUID
from pydantic import BaseModel, Field, field_validator, EmailStr
import logging

from fastapi import APIRouter, Depends, HTTPException, Header, Query, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from src.db.repository import Repository
from src.services.interaction.recording_service import get_recording_service
from src.services.transcript.generator import TranscriptGenerator
from src.services.transcript.email_sender import EmailSender, EmailSenderConfig

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/interaction", tags=["interaction-settings"])
security = HTTPBearer()


# Request/Response Models

class InteractionSettingsResponse(BaseModel):
    """Response model for interaction settings."""

    recording_enabled: bool = Field(
        default=False,
        alias="recordingEnabled",
        description="Whether audio recording is enabled",
    )
    auto_transcribe: bool = Field(
        default=True,
        alias="autoTranscribe",
        description="Whether to automatically transcribe recordings",
    )
    retention_days: int = Field(
        default=30,
        alias="retentionDays",
        description="Number of days to retain recordings",
    )

    class Config:
        populate_by_name = True


class InteractionSettingsUpdateRequest(BaseModel):
    """Request model for updating interaction settings."""

    recording_enabled: Optional[bool] = Field(
        default=None,
        alias="recordingEnabled",
    )
    auto_transcribe: Optional[bool] = Field(
        default=None,
        alias="autoTranscribe",
    )
    retention_days: Optional[int] = Field(
        default=None,
        alias="retentionDays",
        ge=1,
        le=365,
    )

    @field_validator('retention_days')
    @classmethod
    def validate_retention_days(cls, v):
        if v is not None and (v < 1 or v > 365):
            raise ValueError('retentionDays must be between 1 and 365')
        return v

    class Config:
        populate_by_name = True


class UpdateSettingsResponse(BaseModel):
    """Response model for settings update."""

    success: bool
    settings: Optional[InteractionSettingsResponse] = None


class StorageUsageResponse(BaseModel):
    """Response model for storage usage."""

    total_recordings: int = Field(alias="totalRecordings")
    total_size_bytes: int = Field(alias="totalSizeBytes")
    total_size_mb: float = Field(alias="totalSizeMB")
    total_duration_ms: int = Field(alias="totalDurationMs")
    total_duration_seconds: float = Field(alias="totalDurationSeconds")

    class Config:
        populate_by_name = True


class TranscriptResponse(BaseModel):
    """Response model for a transcript."""

    transcript_id: str = Field(alias="transcriptId")
    session_id: str = Field(alias="sessionId")
    story_id: str = Field(alias="storyId")
    parent_id: str = Field(alias="parentId")
    total_turns: int = Field(alias="totalTurns")
    duration_ms: int = Field(alias="durationMs")
    created_at: str = Field(alias="createdAt")

    class Config:
        populate_by_name = True


class TranscriptListResponse(BaseModel):
    """Response model for transcript list."""

    transcripts: List[TranscriptResponse]
    total: int
    page: int
    page_size: int = Field(alias="pageSize")

    class Config:
        populate_by_name = True


# Dependencies

_repository: Optional[Repository] = None


def get_repository() -> Repository:
    """Get the repository instance."""
    global _repository
    if _repository is None:
        _repository = Repository()
    return _repository


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, str]:
    """Verify JWT token and return user info.

    Args:
        credentials: Bearer token credentials.

    Returns:
        User info dict with parent_id and user_id.

    Raises:
        HTTPException: If token is invalid.
    """
    token = credentials.credentials

    # TODO: Implement actual JWT verification
    if not token or token == "invalid-token":
        raise HTTPException(status_code=401, detail="Invalid token")

    # For now, return mock user info
    return {
        "parent_id": "parent-123",
        "user_id": "user-123",
    }


# Endpoints

@router.get(
    "/settings",
    response_model=InteractionSettingsResponse,
    summary="Get interaction settings",
    description="Get the current user's interaction settings including recording preferences.",
)
async def get_settings(
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> InteractionSettingsResponse:
    """Get interaction settings for the current user."""
    parent_id = user_info["parent_id"]

    settings = await repo.get_interaction_settings(parent_id)

    if settings is None:
        # Return defaults
        return InteractionSettingsResponse(
            recording_enabled=False,
            auto_transcribe=True,
            retention_days=30,
        )

    return InteractionSettingsResponse(
        recording_enabled=settings.get("recording_enabled", False),
        auto_transcribe=settings.get("auto_transcribe", True),
        retention_days=settings.get("retention_days", 30),
    )


@router.put(
    "/settings",
    response_model=UpdateSettingsResponse,
    summary="Update interaction settings",
    description="Update the current user's interaction settings.",
)
async def update_settings(
    request: InteractionSettingsUpdateRequest,
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> UpdateSettingsResponse:
    """Update interaction settings for the current user."""
    parent_id = user_info["parent_id"]

    # Build update dict with only provided fields
    update_data = {}
    if request.recording_enabled is not None:
        update_data["recording_enabled"] = request.recording_enabled
    if request.auto_transcribe is not None:
        update_data["auto_transcribe"] = request.auto_transcribe
    if request.retention_days is not None:
        update_data["retention_days"] = request.retention_days

    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    success = await repo.update_interaction_settings(parent_id, update_data)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to update settings")

    # Get updated settings
    updated = await repo.get_interaction_settings(parent_id)

    return UpdateSettingsResponse(
        success=True,
        settings=InteractionSettingsResponse(
            recording_enabled=updated.get("recording_enabled", False),
            auto_transcribe=updated.get("auto_transcribe", True),
            retention_days=updated.get("retention_days", 30),
        ) if updated else None,
    )


@router.get(
    "/storage",
    response_model=StorageUsageResponse,
    summary="Get storage usage",
    description="Get storage usage statistics for recordings.",
)
async def get_storage_usage(
    session_id: Optional[str] = Query(None, alias="sessionId"),
    user_info: Dict[str, str] = Depends(verify_token),
) -> StorageUsageResponse:
    """Get storage usage statistics."""
    recording_service = get_recording_service()
    usage = await recording_service.get_storage_usage(session_id)

    return StorageUsageResponse(
        total_recordings=usage["totalRecordings"],
        total_size_bytes=usage["totalSizeBytes"],
        total_size_mb=usage["totalSizeMB"],
        total_duration_ms=usage["totalDurationMs"],
        total_duration_seconds=usage["totalDurationSeconds"],
    )


@router.delete(
    "/recordings",
    summary="Delete all recordings",
    description="Delete all recordings for a session or all sessions.",
)
async def delete_recordings(
    session_id: Optional[str] = Query(None, alias="sessionId"),
    user_info: Dict[str, str] = Depends(verify_token),
) -> Dict[str, Any]:
    """Delete recordings."""
    recording_service = get_recording_service()

    if session_id:
        deleted = await recording_service.delete_session_recordings(session_id)
    else:
        # Delete all (dangerous - should require additional confirmation)
        raise HTTPException(
            status_code=400,
            detail="sessionId is required. Use DELETE /recordings/all for bulk delete.",
        )

    return {
        "success": True,
        "deletedCount": deleted,
    }


@router.get(
    "/transcripts",
    response_model=TranscriptListResponse,
    summary="List transcripts",
    description="Get a list of interaction transcripts for the current user.",
)
async def list_transcripts(
    story_id: Optional[str] = Query(None, alias="storyId"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100, alias="pageSize"),
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> TranscriptListResponse:
    """List transcripts for the current user."""
    parent_id = user_info["parent_id"]

    transcripts, total = await repo.list_transcripts(
        parent_id=parent_id,
        story_id=story_id,
        page=page,
        page_size=page_size,
    )

    return TranscriptListResponse(
        transcripts=[
            TranscriptResponse(
                transcript_id=t["transcript_id"],
                session_id=t["session_id"],
                story_id=t["story_id"],
                parent_id=t["parent_id"],
                total_turns=t["total_turns"],
                duration_ms=t["duration_ms"],
                created_at=t["created_at"],
            )
            for t in transcripts
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/transcripts/{transcript_id}",
    response_model=Dict[str, Any],
    summary="Get transcript",
    description="Get a specific transcript with all turns.",
)
async def get_transcript(
    transcript_id: str,
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> Dict[str, Any]:
    """Get a specific transcript."""
    parent_id = user_info["parent_id"]

    transcript = await repo.get_transcript(transcript_id)

    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")

    # Verify ownership
    if transcript.get("parent_id") != parent_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    return transcript


@router.delete(
    "/transcripts/{transcript_id}",
    summary="Delete transcript",
    description="Delete a specific transcript and associated recordings.",
)
async def delete_transcript(
    transcript_id: str,
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> Dict[str, Any]:
    """Delete a transcript."""
    parent_id = user_info["parent_id"]

    # Verify ownership
    transcript = await repo.get_transcript(transcript_id)
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    if transcript.get("parent_id") != parent_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Delete transcript
    success = await repo.delete_transcript(transcript_id)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to delete transcript")

    # Delete associated recordings
    recording_service = get_recording_service()
    session_id = transcript.get("session_id")
    if session_id:
        await recording_service.delete_session_recordings(session_id)

    return {
        "success": True,
        "transcriptId": transcript_id,
    }


# T076 [US4] Additional transcript endpoints

class GenerateTranscriptRequest(BaseModel):
    """Request model for generating a transcript."""

    session_id: str = Field(alias="sessionId")

    class Config:
        populate_by_name = True


class GenerateTranscriptResponse(BaseModel):
    """Response model for generated transcript."""

    id: str
    session_id: str = Field(alias="sessionId")
    plain_text: str = Field(alias="plainText")
    html_content: str = Field(alias="htmlContent")
    turn_count: int = Field(alias="turnCount")
    total_duration_ms: int = Field(alias="totalDurationMs")
    created_at: str = Field(alias="createdAt")

    class Config:
        populate_by_name = True


class SendTranscriptRequest(BaseModel):
    """Request model for sending transcript email."""

    email: EmailStr


class SendTranscriptResponse(BaseModel):
    """Response model for email send result."""

    success: bool
    message_id: Optional[str] = Field(None, alias="messageId")
    error: Optional[str] = None

    class Config:
        populate_by_name = True


# Global instances for services
_transcript_generator: Optional[TranscriptGenerator] = None
_email_sender: Optional[EmailSender] = None


def get_transcript_generator() -> TranscriptGenerator:
    """Get or create transcript generator instance."""
    global _transcript_generator
    if _transcript_generator is None:
        _transcript_generator = TranscriptGenerator()
    return _transcript_generator


def get_email_sender() -> Optional[EmailSender]:
    """Get email sender instance if configured."""
    global _email_sender
    # Would be configured via environment variables in production
    return _email_sender


def configure_email_sender(config: EmailSenderConfig) -> None:
    """Configure the email sender with SMTP settings."""
    global _email_sender
    _email_sender = EmailSender(config)


@router.post(
    "/transcripts/generate",
    response_model=GenerateTranscriptResponse,
    status_code=201,
    summary="Generate transcript",
    description="Generate a transcript for an interaction session.",
)
async def generate_transcript(
    request: GenerateTranscriptRequest,
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> GenerateTranscriptResponse:
    """Generate a transcript from session data."""
    parent_id = user_info["parent_id"]
    session_id = request.session_id

    # Get session
    session = await repo.get_interaction_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Verify ownership
    if session.get("parent_id") != parent_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Get voice segments and AI responses
    voice_segments = await repo.get_voice_segments(session_id)
    ai_responses = await repo.get_ai_responses(session_id)

    # Get story title
    story_id = session.get("story_id")
    story = await repo.get_story(story_id) if story_id else None
    story_title = story.get("title", "互動故事") if story else "互動故事"

    # Generate transcript
    generator = get_transcript_generator()

    # Convert dict data to model objects for generator
    from src.models.interaction import (
        InteractionSession,
        VoiceSegment,
        AIResponse,
    )

    session_model = InteractionSession(**session)
    segment_models = [VoiceSegment(**s) for s in voice_segments]
    response_models = [AIResponse(**r) for r in ai_responses]

    transcript = generator.generate(
        session=session_model,
        voice_segments=segment_models,
        ai_responses=response_models,
        story_title=story_title,
    )

    # Save transcript
    saved = await repo.save_transcript(
        transcript_id=str(transcript.id),
        session_id=session_id,
        parent_id=parent_id,
        story_id=story_id,
        plain_text=transcript.plain_text,
        html_content=transcript.html_content,
        turn_count=transcript.turn_count,
        total_duration_ms=transcript.total_duration_ms,
    )

    if not saved:
        raise HTTPException(status_code=500, detail="Failed to save transcript")

    return GenerateTranscriptResponse(
        id=str(transcript.id),
        session_id=session_id,
        plain_text=transcript.plain_text,
        html_content=transcript.html_content,
        turn_count=transcript.turn_count,
        total_duration_ms=transcript.total_duration_ms,
        created_at=transcript.created_at.isoformat(),
    )


@router.post(
    "/transcripts/{transcript_id}/send",
    response_model=SendTranscriptResponse,
    summary="Send transcript email",
    description="Send a transcript to the specified email address.",
)
async def send_transcript_email(
    transcript_id: str,
    request: SendTranscriptRequest,
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> SendTranscriptResponse:
    """Send transcript via email."""
    parent_id = user_info["parent_id"]

    # Get transcript
    transcript = await repo.get_transcript(transcript_id)
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")

    # Verify ownership
    if transcript.get("parent_id") != parent_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Get email sender
    email_sender = get_email_sender()
    if not email_sender:
        raise HTTPException(
            status_code=503,
            detail="Email service not configured",
        )

    # Get story title
    story_id = transcript.get("story_id")
    story = await repo.get_story(story_id) if story_id else None
    story_title = story.get("title", "互動故事") if story else "互動故事"

    # Create transcript model
    from src.models.transcript import InteractionTranscript

    transcript_model = InteractionTranscript(
        id=transcript_id,
        session_id=transcript["session_id"],
        plain_text=transcript["plain_text"],
        html_content=transcript["html_content"],
        turn_count=transcript["turn_count"],
        total_duration_ms=transcript["total_duration_ms"],
        created_at=datetime.fromisoformat(transcript["created_at"]),
    )

    # Send email
    result = await email_sender.send_transcript_email(
        to_email=request.email,
        transcript=transcript_model,
        story_title=story_title,
    )

    if result.success:
        # Update transcript with email sent timestamp
        await repo.update_transcript_email_sent(transcript_id)

    return SendTranscriptResponse(
        success=result.success,
        message_id=result.message_id,
        error=result.error,
    )


@router.get(
    "/transcripts/{transcript_id}/export",
    summary="Export transcript",
    description="Export transcript in the specified format.",
)
async def export_transcript(
    transcript_id: str,
    format: str = Query("html", enum=["html", "txt", "pdf"]),
    user_info: Dict[str, str] = Depends(verify_token),
    repo: Repository = Depends(get_repository),
) -> Response:
    """Export transcript in various formats."""
    parent_id = user_info["parent_id"]

    # Get transcript
    transcript = await repo.get_transcript(transcript_id)
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")

    # Verify ownership
    if transcript.get("parent_id") != parent_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Get story title for filename
    story_id = transcript.get("story_id")
    story = await repo.get_story(story_id) if story_id else None
    story_title = story.get("title", "transcript") if story else "transcript"

    # Export based on format
    if format == "html":
        content = transcript["html_content"]
        media_type = "text/html"
        filename = f"{story_title}_transcript.html"
    elif format == "txt":
        content = transcript["plain_text"]
        media_type = "text/plain"
        filename = f"{story_title}_transcript.txt"
    elif format == "pdf":
        raise HTTPException(
            status_code=501,
            detail="PDF export not yet implemented",
        )
    else:
        raise HTTPException(status_code=400, detail="Invalid format")

    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )
