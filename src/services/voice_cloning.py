"""Voice cloning service using ElevenLabs API.

This service handles:
- Voice cloning from audio samples
- Text-to-speech with cloned voices
- Voice profile status management
"""

import asyncio
import logging
from pathlib import Path
from uuid import UUID

import httpx

from src.config import get_settings
from src.db.repository import VoiceProfileRepository
from src.models import VoiceProfileStatus
from src.models.voice import VoiceProfileUpdate

logger = logging.getLogger(__name__)
settings = get_settings()

# ElevenLabs API endpoints
ELEVENLABS_API_BASE = "https://api.elevenlabs.io/v1"


class VoiceCloningError(Exception):
    """Exception raised for voice cloning errors."""

    pass


class VoiceCloningService:
    """Service for voice cloning and TTS using ElevenLabs."""

    def __init__(self, api_key: str | None = None):
        """Initialize the voice cloning service.

        Args:
            api_key: ElevenLabs API key. If not provided, uses settings.
        """
        self.api_key = api_key or settings.elevenlabs_api_key
        if not self.api_key:
            logger.warning("ElevenLabs API key not configured")

    def _get_headers(self) -> dict[str, str]:
        """Get HTTP headers for API requests."""
        return {
            "xi-api-key": self.api_key,
            "Accept": "application/json",
        }

    async def clone_voice(
        self,
        audio_file_path: str,
        name: str,
        description: str = "StoryBuddy cloned voice",
    ) -> str:
        """Clone a voice from an audio sample using ElevenLabs.

        Args:
            audio_file_path: Path to the audio sample file
            name: Name for the cloned voice
            description: Description of the voice

        Returns:
            ElevenLabs voice ID

        Raises:
            VoiceCloningError: If cloning fails
        """
        if not self.api_key:
            raise VoiceCloningError("ElevenLabs API key not configured")

        audio_path = Path(audio_file_path)
        if not audio_path.exists():
            raise VoiceCloningError(f"Audio file not found: {audio_file_path}")

        try:
            async with httpx.AsyncClient(timeout=120.0) as client:
                # Read the audio file
                with open(audio_path, "rb") as f:
                    audio_data = f.read()

                # Prepare multipart form data
                files = {
                    "files": (audio_path.name, audio_data, "audio/mpeg"),
                }
                data = {
                    "name": name,
                    "description": description,
                }

                # Send request to ElevenLabs
                response = await client.post(
                    f"{ELEVENLABS_API_BASE}/voices/add",
                    headers=self._get_headers(),
                    files=files,
                    data=data,
                )

                if response.status_code == 200:
                    result = response.json()
                    voice_id = result.get("voice_id")
                    logger.info(f"Voice cloned successfully: {voice_id}")
                    return voice_id
                else:
                    error_detail = response.text
                    logger.error(f"ElevenLabs API error: {response.status_code} - {error_detail}")
                    raise VoiceCloningError(f"Voice cloning failed: {error_detail}")

        except httpx.RequestError as e:
            logger.error(f"Request error during voice cloning: {e}")
            raise VoiceCloningError(f"Network error during voice cloning: {e}") from e

    async def generate_speech(
        self,
        voice_id: str,
        text: str,
        output_path: Path,
        model_id: str = "eleven_multilingual_v2",
        stability: float = 0.5,
        similarity_boost: float = 0.75,
    ) -> Path:
        """Generate speech from text using a cloned voice.

        Args:
            voice_id: ElevenLabs voice ID
            text: Text to convert to speech
            output_path: Path to save the audio file
            model_id: ElevenLabs model to use
            stability: Voice stability (0-1)
            similarity_boost: Similarity boost (0-1)

        Returns:
            Path to the generated audio file

        Raises:
            VoiceCloningError: If TTS fails
        """
        if not self.api_key:
            raise VoiceCloningError("ElevenLabs API key not configured")

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{ELEVENLABS_API_BASE}/text-to-speech/{voice_id}",
                    headers={
                        **self._get_headers(),
                        "Content-Type": "application/json",
                    },
                    json={
                        "text": text,
                        "model_id": model_id,
                        "voice_settings": {
                            "stability": stability,
                            "similarity_boost": similarity_boost,
                        },
                    },
                )

                if response.status_code == 200:
                    # Ensure output directory exists
                    output_path.parent.mkdir(parents=True, exist_ok=True)

                    # Save audio file
                    with open(output_path, "wb") as f:
                        f.write(response.content)

                    logger.info(f"Speech generated successfully: {output_path}")
                    return output_path
                else:
                    error_detail = response.text
                    logger.error(f"ElevenLabs TTS error: {response.status_code} - {error_detail}")
                    raise VoiceCloningError(f"TTS generation failed: {error_detail}")

        except httpx.RequestError as e:
            logger.error(f"Request error during TTS: {e}")
            raise VoiceCloningError(f"Network error during TTS: {e}") from e

    async def delete_voice(self, voice_id: str) -> bool:
        """Delete a cloned voice from ElevenLabs.

        Args:
            voice_id: ElevenLabs voice ID

        Returns:
            True if deletion was successful
        """
        if not self.api_key:
            logger.warning("Cannot delete voice: API key not configured")
            return False

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.delete(
                    f"{ELEVENLABS_API_BASE}/voices/{voice_id}",
                    headers=self._get_headers(),
                )

                if response.status_code == 200:
                    logger.info(f"Voice deleted successfully: {voice_id}")
                    return True
                else:
                    logger.warning(f"Failed to delete voice {voice_id}: {response.status_code}")
                    return False

        except httpx.RequestError as e:
            logger.error(f"Request error deleting voice: {e}")
            return False

    async def get_voice_info(self, voice_id: str) -> dict[str, object] | None:
        """Get information about a voice from ElevenLabs.

        Args:
            voice_id: ElevenLabs voice ID

        Returns:
            Voice information dict or None if not found
        """
        if not self.api_key:
            return None

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{ELEVENLABS_API_BASE}/voices/{voice_id}",
                    headers=self._get_headers(),
                )

                if response.status_code == 200:
                    return response.json()
                else:
                    return None

        except httpx.RequestError as e:
            logger.error(f"Request error getting voice info: {e}")
            return None


async def process_voice_cloning(
    profile_id: UUID,
    audio_file_path: str,
    profile_name: str,
) -> None:
    """Background task to process voice cloning.

    This function is meant to be run as a background task after
    a voice sample is uploaded.

    Args:
        profile_id: Voice profile ID
        audio_file_path: Path to the uploaded audio file
        profile_name: Name of the voice profile
    """
    service = VoiceCloningService()

    try:
        # Clone the voice
        voice_id = await service.clone_voice(
            audio_file_path=audio_file_path,
            name=f"StoryBuddy - {profile_name}",
        )

        # Update profile with success
        await VoiceProfileRepository.update(
            profile_id,
            VoiceProfileUpdate(
                elevenlabs_voice_id=voice_id,
                status=VoiceProfileStatus.READY,
            ),
        )
        logger.info(f"Voice profile {profile_id} cloning completed")

    except VoiceCloningError as e:
        # Update profile with failure
        await VoiceProfileRepository.update(
            profile_id,
            VoiceProfileUpdate(status=VoiceProfileStatus.FAILED),
        )
        logger.error(f"Voice profile {profile_id} cloning failed: {e}")

    except Exception as e:
        # Unexpected error
        await VoiceProfileRepository.update(
            profile_id,
            VoiceProfileUpdate(status=VoiceProfileStatus.FAILED),
        )
        logger.exception(f"Unexpected error cloning voice profile {profile_id}: {e}")


async def generate_story_audio(
    voice_id: str,
    story_id: UUID,
    story_content: str,
    output_dir: Path | None = None,
) -> Path:
    """Generate audio for a story using a cloned voice.

    Args:
        voice_id: ElevenLabs voice ID
        story_id: Story ID
        story_content: Story text content
        output_dir: Output directory for audio file

    Returns:
        Path to the generated audio file
    """
    service = VoiceCloningService()

    if output_dir is None:
        output_dir = settings.stories_audio_dir

    output_path = output_dir / f"{story_id}.mp3"

    return await service.generate_speech(
        voice_id=voice_id,
        text=story_content,
        output_path=output_path,
    )


async def generate_preview_audio(
    voice_id: str,
    profile_id: UUID,
    text: str,
) -> Path:
    """Generate a preview audio for a voice profile.

    Args:
        voice_id: ElevenLabs voice ID
        profile_id: Voice profile ID
        text: Text to convert to speech

    Returns:
        Path to the generated audio file
    """
    service = VoiceCloningService()

    output_dir = settings.voice_samples_dir / str(profile_id)
    output_path = output_dir / "preview.mp3"

    return await service.generate_speech(
        voice_id=voice_id,
        text=text,
        output_path=output_path,
    )


async def poll_voice_cloning_status(
    profile_id: UUID,
    max_attempts: int = 30,
    interval_seconds: float = 2.0,
) -> VoiceProfileStatus:
    """Poll the voice cloning status until complete or timeout.

    Args:
        profile_id: Voice profile ID
        max_attempts: Maximum polling attempts
        interval_seconds: Seconds between polling attempts

    Returns:
        Final voice profile status
    """
    for _ in range(max_attempts):
        profile = await VoiceProfileRepository.get_by_id(profile_id)
        if profile is None:
            return VoiceProfileStatus.FAILED

        if profile.status in (VoiceProfileStatus.READY, VoiceProfileStatus.FAILED):
            return profile.status

        await asyncio.sleep(interval_seconds)

    # Timeout - mark as failed
    await VoiceProfileRepository.update(
        profile_id,
        VoiceProfileUpdate(status=VoiceProfileStatus.FAILED),
    )
    return VoiceProfileStatus.FAILED
