from typing import Any

from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import BaseModel

from src.models.voice import VoiceCharacter, VoiceKit
from src.services.voice_kit_service import VoiceKitService

router = APIRouter(tags=["System Voices"])
service = VoiceKitService()


class VoicePreferenceRequest(BaseModel):
    user_id: str
    default_voice_id: str


class StoryVoiceMapRequest(BaseModel):
    user_id: str
    role: str
    voice_id: str


@router.get("/voices", response_model=list[VoiceCharacter])
async def list_voices() -> list[VoiceCharacter]:
    """List all available system voices."""
    return await service.list_voices()


@router.get("/voices/{voice_id}", response_model=VoiceCharacter)
async def get_voice(voice_id: str) -> VoiceCharacter:
    """Get details of a specific system voice."""
    voice = await service.get_voice(voice_id)
    if not voice:
        raise HTTPException(status_code=404, detail="Voice not found")
    return voice


@router.get("/voices/{voice_id}/preview")
async def get_voice_preview(
    voice_id: str,
    text: str | None = Query(
        None, description="Text to preview (defaults to voice's preview text)"
    ),
) -> Response:
    """Get audio preview for a system voice."""
    try:
        audio = await service.get_voice_preview(voice_id, text)
        return Response(content=audio, media_type="audio/wav")
    except ValueError:
        raise HTTPException(status_code=404, detail="Voice not found")
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {e}")


@router.get("/kits", response_model=list[VoiceKit])
async def list_kits() -> list[VoiceKit]:
    """List all available voice kits."""
    return await service.list_kits()


@router.post("/kits/{kit_id}/download", response_model=VoiceKit)
async def download_kit(kit_id: str) -> VoiceKit:
    """Download a specific voice kit."""
    kit = await service.download_kit(kit_id)
    if not kit:
        raise HTTPException(status_code=404, detail="Kit not found")
    return kit


# -- Voice Preferences --


@router.get("/voices/preferences")
async def get_user_preferences(user_id: str) -> dict[str, Any]:
    """Get user voice preferences."""
    return await service.get_user_preferences(user_id)


@router.post("/voices/preferences")
async def update_user_preferences(request: VoicePreferenceRequest) -> dict[str, Any]:
    """Update user voice preferences."""
    try:
        return await service.update_default_voice(request.user_id, request.default_voice_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# -- Story Voice Mappings --


@router.get("/stories/{story_id}/voices")
async def get_story_voice_mappings(story_id: str, user_id: str) -> list[dict[str, Any]]:
    """Get voice mappings for a specific story."""
    return await service.get_story_voice_mappings(user_id, story_id)


@router.post("/stories/{story_id}/voices")
async def update_story_voice_mapping(
    story_id: str, request: StoryVoiceMapRequest
) -> dict[str, Any]:
    """Update voice mapping for a specific story role."""
    try:
        return await service.update_story_voice_mapping(
            request.user_id, story_id, request.role, request.voice_id
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
