import logging
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.services.tts.azure_tts import AzureTTSProvider
from src.services.voice_kit_service import VoiceKitService


@pytest.fixture
def mock_azure_provider():
    with patch("src.services.voice_kit_service.AzureTTSProvider") as MockProvider:
        provider_instance = MockProvider.return_value
        provider_instance.synthesize = AsyncMock(return_value=b"audio_data")
        yield provider_instance


@pytest.mark.asyncio
async def test_download_kit_logging(caplog, mock_azure_provider):
    """Test that download_kit logs start and completion."""
    service = VoiceKitService()
    service.azure_provider = mock_azure_provider

    # Configure logging to capture
    caplog.set_level(logging.INFO, logger="storybuddy")

    await service.download_kit("holiday-v1")

    assert "Downloading voice kit" in caplog.text
    # Verify extra fields
    rec = next(r for r in caplog.records if "Downloading voice kit" in r.message)
    assert rec.kit_id == "holiday-v1"


@pytest.mark.asyncio
async def test_azure_tts_logging(caplog):
    """Test that Azure TTS synthesize logs interactions."""
    # We need to test AzureTTSProvider directly, but it relies on settings.
    # We'll mock the settings or just check if it logs.

    with (
        patch("src.services.tts.azure_tts.get_settings") as mock_settings,
        patch("src.services.tts.azure_tts.TTSCache") as MockCache,
    ):
        mock_settings.return_value.azure_speech_key = "fake-key"
        mock_settings.return_value.azure_speech_region = "fake-region"

        # Setup mock cache
        mock_cache_instance = MockCache.return_value
        mock_cache_instance.get.return_value = None  # Cache miss

        provider = AzureTTSProvider()

        # Mock speechsdk
        with patch("src.services.tts.azure_tts.speechsdk") as mock_sdk:
            mock_result = MagicMock()
            mock_result.reason = mock_sdk.ResultReason.SynthesizingAudioCompleted
            mock_result.audio_data = b"fake-audio"

            mock_synthesizer = mock_sdk.SpeechSynthesizer.return_value
            mock_synthesizer.speak_ssml_async.return_value.get.return_value = mock_result

            caplog.set_level(logging.INFO, logger="storybuddy")

            await provider.synthesize("test text", "voice-id")

            # Check records for structured data (extra fields)

            start_record = next(r for r in caplog.records if "Synthesizing text" in r.message)
            assert start_record.voice_id == "voice-id"
            assert start_record.text_length == 9
            assert start_record.cached is False

            end_record = next(r for r in caplog.records if "Synthesis completed" in r.message)
            assert end_record.voice_id == "voice-id"

            # Verify cache was set
            mock_cache_instance.set.assert_called_once()
