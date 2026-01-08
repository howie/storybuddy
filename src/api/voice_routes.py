from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, Response

from src.models.voice import VoiceCharacter, VoiceKit
from src.services.voice_kit_service import VoiceKitService

router = APIRouter(tags=["System Voices"])
service = VoiceKitService()


@router.get("/voices", response_model=List[VoiceCharacter])
async def list_voices() -> List[VoiceCharacter]:
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
    text: Optional[str] = Query(
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
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {e}")


@router.get("/kits", response_model=List[VoiceKit])
async def list_kits() -> List[VoiceKit]:
    """List all available voice kits."""
    return await service.list_kits()


@router.post("/kits/{kit_id}/download", response_model=VoiceKit)
async def download_kit(kit_id: str) -> VoiceKit:
    """Download a specific voice kit."""
    kit = await service.download_kit(kit_id)
    if not kit:
        raise HTTPException(status_code=404, detail="Kit not found")
    return kit
