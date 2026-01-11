from unittest.mock import MagicMock, patch

import pytest

from src.models.voice import Gender
from src.services.tts.elevenlabs_tts import ElevenLabsProvider


@pytest.mark.asyncio
async def test_elevenlabs_init_no_key():
    with patch("src.services.tts.elevenlabs_tts.get_settings") as mock_settings:
        mock_settings.return_value.elevenlabs_api_key = ""
        provider = ElevenLabsProvider()
        assert provider.client is None
        assert await provider.validate_credentials() is False


@pytest.mark.asyncio
async def test_elevenlabs_synthesize():
    with (
        patch("src.services.tts.elevenlabs_tts.get_settings") as mock_settings,
        patch("src.services.tts.elevenlabs_tts.ElevenLabs") as MockElevenLabs,
    ):
        mock_settings.return_value.elevenlabs_api_key = "fake-key"

        provider = ElevenLabsProvider()

        mock_client = MockElevenLabs.return_value
        # Mock generate returning bytes generator
        mock_client.generate.return_value = (b"chunk1", b"chunk2")

        # Mock Cache
        provider.cache = MagicMock()
        provider.cache.get.return_value = None

        audio = await provider.synthesize("test", "voice-123")
        assert audio == b"chunk1chunk2"

        mock_client.generate.assert_called_once()
        args = mock_client.generate.call_args[1]
        assert args["text"] == "test"
        assert args["voice"] == "voice-123"


@pytest.mark.asyncio
async def test_elevenlabs_get_voices():
    with (
        patch("src.services.tts.elevenlabs_tts.get_settings") as mock_settings,
        patch("src.services.tts.elevenlabs_tts.ElevenLabs") as MockElevenLabs,
    ):
        mock_settings.return_value.elevenlabs_api_key = "fake-key"
        provider = ElevenLabsProvider()
        mock_client = MockElevenLabs.return_value

        mock_voice = MagicMock()
        mock_voice.voice_id = "v1"
        mock_voice.name = "Rachel"
        mock_voice.labels = {"gender": "female"}

        mock_client.voices.get_all.return_value.voices = [mock_voice]

        voices = await provider.get_voices()
        assert len(voices) == 1
        assert voices[0]["id"] == "v1"
        assert voices[0]["gender"] == Gender.FEMALE
