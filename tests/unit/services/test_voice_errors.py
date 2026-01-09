import pytest
import azure.cognitiveservices.speech as speechsdk
from unittest.mock import MagicMock, patch
from src.services.voice_kit_service import VoiceKitService
from src.services.tts.azure_tts import AzureTTSProvider

@pytest.mark.asyncio
async def test_azure_tts_cancellation_error():
    """Test that Azure cancellation raises RuntimeError with details."""
    with patch("src.services.tts.azure_tts.get_settings") as mock_settings, \
         patch("src.services.tts.azure_tts.TTSCache") as MockCache: 
        
        mock_settings.return_value.azure_speech_key = "fake-key"
        mock_settings.return_value.azure_speech_region = "fake-region"
        
        MockCache.return_value.get.return_value = None # Ensure cache miss
        
        provider = AzureTTSProvider()
        
        with patch("src.services.tts.azure_tts.speechsdk") as mock_sdk:
            mock_result = MagicMock()
            mock_result.reason = mock_sdk.ResultReason.Canceled
            mock_result.cancellation_details.reason = mock_sdk.CancellationReason.Error
            mock_result.cancellation_details.error_details = "Auth Failed"
            
            mock_synthesizer = mock_sdk.SpeechSynthesizer.return_value
            mock_synthesizer.speak_ssml_async.return_value.get.return_value = mock_result
            
            with pytest.raises(RuntimeError, match="Auth Failed"):
                await provider.synthesize("text", "voice-id")

@pytest.mark.asyncio
async def test_voice_kit_service_handles_provider_error():
    """Test that service propagates errors."""
    service = VoiceKitService()
    service.azure_provider = MagicMock()
    service.azure_provider.synthesize.side_effect = RuntimeError("Provider Error")
    
    # Mock get_voice to return a voice so validation passes
    with patch.object(service, "get_voice", return_value=MagicMock(provider_voice_id="pid", ssml_options={})):
        with pytest.raises(RuntimeError, match="Provider Error"):
            await service.generate_story_audio("story-id", "voice-id")
