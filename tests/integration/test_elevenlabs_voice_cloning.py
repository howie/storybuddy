"""Integration tests for ElevenLabs voice cloning service.

These tests require a valid ElevenLabs API key with voices_write permission.
Set ELEVENLABS_API_KEY environment variable to run these tests.

Run with:
    # Run all ElevenLabs tests (requires API key)
    pytest tests/integration/test_elevenlabs_voice_cloning.py -v

    # Skip tests that require paid subscription
    pytest tests/integration/test_elevenlabs_voice_cloning.py -v -m "not elevenlabs_paid"

    # Run only paid subscription tests
    pytest tests/integration/test_elevenlabs_voice_cloning.py -v -m "elevenlabs_paid"
"""

import struct
import tempfile
import wave
from pathlib import Path

import pytest

from src.config import get_settings
from src.services.voice_cloning import VoiceCloningError, VoiceCloningService

settings = get_settings()

# Skip all tests if API key is not configured
pytestmark = pytest.mark.skipif(
    not settings.elevenlabs_api_key,
    reason="ELEVENLABS_API_KEY not configured",
)

# Custom marker for tests requiring paid ElevenLabs subscription
elevenlabs_paid = pytest.mark.elevenlabs_paid


def create_test_wav_file(duration_seconds: float = 30.0, sample_rate: int = 44100) -> Path:
    """Create a temporary WAV file for testing.

    Args:
        duration_seconds: Duration of the audio
        sample_rate: Sample rate in Hz

    Returns:
        Path to the temporary WAV file
    """
    num_samples = int(sample_rate * duration_seconds)
    # Generate simple sine wave tone (more realistic than silence)
    import math

    frequency = 440.0  # A4 note
    audio_data = []
    for i in range(num_samples):
        sample = int(32767 * 0.3 * math.sin(2 * math.pi * frequency * i / sample_rate))
        audio_data.append(sample)

    audio_bytes = struct.pack("<" + "h" * num_samples, *audio_data)

    # Create temp file
    temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    with wave.open(temp_file.name, "wb") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_bytes)

    return Path(temp_file.name)


@pytest.fixture
def test_audio_file() -> Path:
    """Create a test audio file and clean up after test."""
    audio_path = create_test_wav_file(duration_seconds=30.0)
    yield audio_path
    # Cleanup
    if audio_path.exists():
        audio_path.unlink()


@pytest.fixture
def voice_cloning_service() -> VoiceCloningService:
    """Create a VoiceCloningService instance."""
    return VoiceCloningService()


@pytest.mark.asyncio
class TestElevenLabsVoiceCloning:
    """Integration tests for ElevenLabs voice cloning."""

    async def test_api_key_configured(self, voice_cloning_service: VoiceCloningService) -> None:
        """Test that API key is properly configured."""
        assert voice_cloning_service.api_key
        assert len(voice_cloning_service.api_key) > 0

    @elevenlabs_paid
    async def test_clone_voice_and_delete(
        self,
        voice_cloning_service: VoiceCloningService,
        test_audio_file: Path,
    ) -> None:
        """Test complete voice cloning flow: clone -> verify -> delete.

        This test creates a cloned voice on ElevenLabs and then deletes it.
        Requires ElevenLabs Creator subscription or higher.
        """
        voice_id = None
        try:
            # Clone the voice
            voice_id = await voice_cloning_service.clone_voice(
                audio_file_path=str(test_audio_file),
                name="StoryBuddy Integration Test Voice",
                description="Test voice - will be deleted after test",
            )

            # Verify voice was created
            assert voice_id is not None
            assert isinstance(voice_id, str)
            assert len(voice_id) > 0

            # Verify we can get voice info
            voice_info = await voice_cloning_service.get_voice_info(voice_id)
            assert voice_info is not None
            assert voice_info.get("voice_id") == voice_id
            assert "StoryBuddy Integration Test Voice" in voice_info.get("name", "")

        finally:
            # Always clean up: delete the cloned voice
            if voice_id:
                deleted = await voice_cloning_service.delete_voice(voice_id)
                assert deleted, f"Failed to delete test voice {voice_id}"

    async def test_clone_voice_file_not_found(
        self,
        voice_cloning_service: VoiceCloningService,
    ) -> None:
        """Test that cloning fails gracefully for non-existent file."""
        with pytest.raises(VoiceCloningError) as exc_info:
            await voice_cloning_service.clone_voice(
                audio_file_path="/nonexistent/path/audio.wav",
                name="Test Voice",
            )
        assert "not found" in str(exc_info.value).lower()

    async def test_clone_voice_without_api_key(self) -> None:
        """Test that cloning fails without API key.

        Note: VoiceCloningService uses `api_key or settings.elevenlabs_api_key`,
        so passing empty string falls back to settings. We test with explicit None.
        """
        # Create service that explicitly bypasses settings
        service = VoiceCloningService.__new__(VoiceCloningService)
        service.api_key = None  # Explicitly set to None

        with pytest.raises(VoiceCloningError) as exc_info:
            await service.clone_voice(
                audio_file_path="/tmp/test.wav",
                name="Test Voice",
            )
        assert "not configured" in str(exc_info.value).lower()


@pytest.mark.asyncio
class TestElevenLabsTTS:
    """Integration tests for ElevenLabs text-to-speech."""

    @elevenlabs_paid
    async def test_generate_speech_with_cloned_voice(
        self,
        voice_cloning_service: VoiceCloningService,
        test_audio_file: Path,
    ) -> None:
        """Test complete TTS flow: clone voice -> generate speech -> delete.

        This test creates a cloned voice, generates TTS audio, and cleans up.
        Requires ElevenLabs Creator subscription or higher.
        """
        voice_id = None
        output_path = None
        try:
            # Step 1: Clone a voice first
            voice_id = await voice_cloning_service.clone_voice(
                audio_file_path=str(test_audio_file),
                name="StoryBuddy TTS Test Voice",
                description="Test voice for TTS - will be deleted",
            )
            assert voice_id is not None

            # Step 2: Generate speech with the cloned voice
            output_path = Path(tempfile.mktemp(suffix=".mp3"))
            result_path = await voice_cloning_service.generate_speech(
                voice_id=voice_id,
                text="你好，我是 StoryBuddy 的測試聲音。這是一個語音合成測試。",
                output_path=output_path,
            )

            # Verify speech was generated
            assert result_path.exists()
            assert result_path.stat().st_size > 0  # File has content

        finally:
            # Clean up: delete voice and output file
            if voice_id:
                await voice_cloning_service.delete_voice(voice_id)
            if output_path and output_path.exists():
                output_path.unlink()

    async def test_generate_speech_invalid_voice_id(
        self,
        voice_cloning_service: VoiceCloningService,
    ) -> None:
        """Test that TTS fails gracefully for invalid voice ID."""
        output_path = Path(tempfile.mktemp(suffix=".mp3"))
        try:
            with pytest.raises(VoiceCloningError):
                await voice_cloning_service.generate_speech(
                    voice_id="invalid_voice_id_12345",
                    text="Test text",
                    output_path=output_path,
                )
        finally:
            if output_path.exists():
                output_path.unlink()


@pytest.mark.asyncio
class TestElevenLabsVoiceManagement:
    """Integration tests for voice management operations."""

    async def test_get_voice_info_invalid_id(
        self,
        voice_cloning_service: VoiceCloningService,
    ) -> None:
        """Test getting info for non-existent voice."""
        voice_info = await voice_cloning_service.get_voice_info("invalid_voice_id_99999")
        assert voice_info is None

    async def test_delete_nonexistent_voice(
        self,
        voice_cloning_service: VoiceCloningService,
    ) -> None:
        """Test deleting a non-existent voice returns False."""
        deleted = await voice_cloning_service.delete_voice("invalid_voice_id_99999")
        assert deleted is False
