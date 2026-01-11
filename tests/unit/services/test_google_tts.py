from unittest.mock import MagicMock, patch

import pytest

from src.models.voice import Gender
from src.services.tts.google_tts import GoogleTTSProvider


@pytest.mark.asyncio
async def test_google_tts_init_no_credentials():
    """Test initialization handles missing credentials gracefully."""
    with patch("src.services.tts.google_tts.os.environ.get", return_value=None):
        provider = GoogleTTSProvider()
        assert provider.client is None
        assert await provider.validate_credentials() is False


@pytest.mark.asyncio
async def test_google_tts_synthesize():
    """Test synthesis with mocked client."""
    with (
        patch("src.services.tts.google_tts.os.environ.get", return_value="fake-path"),
        patch("src.services.tts.google_tts.texttospeech") as mock_tts,
    ):
        provider = GoogleTTSProvider()

        # Mock client
        mock_client = mock_tts.TextToSpeechClient.return_value
        mock_response = MagicMock()
        mock_response.audio_content = b"fake-audio"
        mock_client.synthesize_speech.return_value = mock_response

        # Mock Cache
        provider.cache = MagicMock()
        provider.cache.get.return_value = None

        audio = await provider.synthesize("test", "cmn-TW-Wavenet-A")
        assert audio == b"fake-audio"

        # Verify call args
        # Verify input construction
        mock_tts.SynthesisInput.assert_called_once_with(text="test")

        # Verify synthesize call
        mock_client.synthesize_speech.assert_called_once()
        call_kwargs = mock_client.synthesize_speech.call_args[1]

        # We can't easily check attributes of input/voice/audio_config if they are mocks created inside
        # But we can verify matching types or just trust usage derived from input construction check above.
        assert "input" in call_kwargs
        assert "voice" in call_kwargs
        assert "audio_config" in call_kwargs

        # Check voice params construction
        mock_tts.VoiceSelectionParams.assert_called_once()
        assert mock_tts.VoiceSelectionParams.call_args[1]["language_code"] == "cmn-TW"


@pytest.mark.asyncio
async def test_google_tts_get_voices():
    """Test getting voices."""
    with (
        patch("src.services.tts.google_tts.os.environ.get", return_value="fake-path"),
        patch("src.services.tts.google_tts.texttospeech") as mock_tts,
    ):
        provider = GoogleTTSProvider()
        mock_client = mock_tts.TextToSpeechClient.return_value

        mock_voice = MagicMock()
        mock_voice.name = "cmn-TW-Wavenet-A"
        mock_voice.language_codes = ["cmn-TW"]
        mock_voice.ssml_gender = mock_tts.SsmlVoiceGender.FEMALE

        mock_client.list_voices.return_value.voices = [mock_voice]

        voices = await provider.get_voices()
        assert len(voices) == 1
        assert voices[0]["id"] == "cmn-TW-Wavenet-A"
        assert voices[0]["gender"] == Gender.FEMALE
