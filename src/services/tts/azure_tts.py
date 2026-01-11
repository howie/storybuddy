"""Azure Cognitive Services TTS provider.

T054 [US2] Extended for AI response audio generation.
"""

import azure.cognitiveservices.speech as speechsdk
from typing import Any, Dict, List, Optional
import logging

from src.config import get_settings
from src.models.voice import TTSProvider as TTSProviderEnum, Gender, AgeGroup
from src.services.tts.base import TTSProvider
from src.services.tts.ssml_utils import create_ssml

logger = logging.getLogger(__name__)

# Default voice for AI responses (Taiwan Mandarin)
DEFAULT_AI_RESPONSE_VOICE = "zh-TW-HsiaoChenNeural"

# Recommended voices for AI responses (child-friendly)
AI_RESPONSE_VOICES = {
    "zh-TW": {
        "female": "zh-TW-HsiaoChenNeural",
        "male": "zh-TW-YunJheNeural",
    },
    "en-US": {
        "female": "en-US-JennyNeural",
        "male": "en-US-GuyNeural",
    },
}


class AzureTTSProvider(TTSProvider):
    """Azure Cognitive Services TTS provider implementation."""

    def __init__(self):
        self.settings = get_settings()
        self._speech_config = None

    @property
    def provider_type(self) -> TTSProviderEnum:
        return TTSProviderEnum.AZURE

    @property
    def speech_config(self) -> speechsdk.SpeechConfig:
        """Lazy load speech config to avoid errors if keys are missing during init."""
        if self._speech_config is None:
            if not self.settings.azure_speech_key or not self.settings.azure_speech_region:
                raise ValueError("Azure Speech key or region not configured")
            
            self._speech_config = speechsdk.SpeechConfig(
                subscription=self.settings.azure_speech_key,
                region=self.settings.azure_speech_region
            )
        return self._speech_config

    async def validate_credentials(self) -> bool:
        """Validate credentials by attempting to create a synthesizer."""
        try:
            # We don't actually need to make a call, just check if config creation succeeds
            # But to be sure, we could list voices.
            # For now, just checking if key/region are present.
            return bool(self.settings.azure_speech_key and self.settings.azure_speech_region)
        except Exception:
            return False

    async def synthesize(
        self, 
        text: str, 
        voice_id: str,
        options: Optional[Dict[str, Any]] = None
    ) -> bytes:
        """
        Synthesize text using Azure TTS.
        
        Args:
            text: Text to synthesize
            voice_id: Azure voice name (e.g., zh-TW-HsiaoChenNeural)
            options: Optional parameters (style, role, pitch, rate, volume)
        """
        options = options or {}
        
        # Generate SSML
        ssml = create_ssml(
            text=text,
            voice_name=voice_id,
            language=options.get("language", "zh-TW"),
            style=options.get("style"),
            role=options.get("role"),
            pitch=options.get("pitch"),
            rate=options.get("rate"),
            volume=options.get("volume"),
        )

        # Configure synthesizer to output to memory stream (bytes)
        # We use a pull stream or allow default speaker? 
        # The goal is to return bytes.
        # speech_synthesizer.speak_ssml_async(ssml).get() returns result with audio_data
        
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config, 
            audio_config=None # None means do not play to speaker, just generate
        )
        
        result = synthesizer.speak_ssml_async(ssml).get()

        if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            return result.audio_data
        elif result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = result.cancellation_details
            error_msg = f"Speech synthesis canceled: {cancellation_details.reason}"
            if cancellation_details.reason == speechsdk.CancellationReason.Error:
                error_msg += f". Error details: {cancellation_details.error_details}"
            raise RuntimeError(error_msg)
        else:
            raise RuntimeError(f"Speech synthesis failed with reason: {result.reason}")

    async def get_voices(self) -> List[Dict[str, Any]]:
        """List available voices from Azure."""
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config, 
            audio_config=None
        )
        
        result = synthesizer.get_voices_async().get()
        
        if result.reason == speechsdk.ResultReason.VoicesListRetrieved:
            voices = []
            for v in result.voices:
                # Map Azure voice to our generic dict structure
                # We mainly filter for Chinese/Local for now or return all?
                # Returning structure close to what we need
                
                # Determine gender
                gender = Gender.NEUTRAL
                if v.gender == speechsdk.SynthesisVoiceGender.Female:
                    gender = Gender.FEMALE
                elif v.gender == speechsdk.SynthesisVoiceGender.Male:
                    gender = Gender.MALE
                
                # Map styles if available (not directly in VoiceInfo usually, requires query)
                # But for now we just return basic info
                
                voices.append({
                    "provider_voice_id": v.name, # Full name e.g. zh-TW-HsiaoChenNeural
                    "name": v.local_name,
                    "locale": v.locale,
                    "gender": gender,
                    "styles": v.style_list if hasattr(v, 'style_list') else [] # Some SDK versions specific
                })
            return voices
            
        elif result.reason == speechsdk.ResultReason.Canceled:
             raise RuntimeError(f"Get voices canceled: {result.cancellation_details.error_details}")
        else:
             raise RuntimeError(f"Get voices failed: {result.reason}")

    async def synthesize_ai_response(
        self,
        text: str,
        voice_id: Optional[str] = None,
        story_voice_id: Optional[str] = None,
        style: Optional[str] = None,
        language: str = "zh-TW",
    ) -> bytes:
        """Synthesize AI response audio (T054 [US2]).

        Generates TTS audio for AI responses in interactive mode.
        Uses the same voice as the story when available (FR-010).

        Args:
            text: AI response text to synthesize.
            voice_id: Specific voice ID to use.
            story_voice_id: Voice ID from the story (for consistency).
            style: Voice style (e.g., "friendly", "cheerful").
            language: Language code.

        Returns:
            Audio data as bytes.
        """
        # Use story voice if provided, otherwise use default AI voice
        effective_voice_id = voice_id or story_voice_id or DEFAULT_AI_RESPONSE_VOICE

        # Default to friendly style for AI responses to children
        effective_style = style or "friendly"

        logger.debug(f"Synthesizing AI response with voice {effective_voice_id}")

        try:
            audio_bytes = await self.synthesize(
                text=text,
                voice_id=effective_voice_id,
                options={
                    "language": language,
                    "style": effective_style,
                    "rate": "-5%",  # Slightly slower for children
                    "pitch": "+5%",  # Slightly higher for friendlier tone
                },
            )
            logger.info(f"AI response audio generated: {len(audio_bytes)} bytes")
            return audio_bytes

        except Exception as e:
            logger.error(f"Failed to synthesize AI response: {e}")
            raise

    @staticmethod
    def get_recommended_voice(language: str = "zh-TW", gender: str = "female") -> str:
        """Get recommended voice for AI responses.

        Args:
            language: Language code.
            gender: Preferred gender ("female" or "male").

        Returns:
            Recommended voice ID.
        """
        voices = AI_RESPONSE_VOICES.get(language, AI_RESPONSE_VOICES["zh-TW"])
        return voices.get(gender, voices["female"])
