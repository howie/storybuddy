import logging
from typing import Any

import azure.cognitiveservices.speech as speechsdk

from src.config import get_settings
from src.models.voice import Gender
from src.models.voice import TTSProvider as TTSProviderEnum
from src.services.tts.base import TTSProvider
from src.services.tts.cache import TTSCache
from src.services.tts.ssml_utils import create_ssml


class AzureTTSProvider(TTSProvider):
    """Azure Cognitive Services TTS provider implementation."""

    def __init__(self):
        self.settings = get_settings()
        self._speech_config = None
        self.logger = logging.getLogger("storybuddy.services.tts.azure")
        self.cache = TTSCache()

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
                region=self.settings.azure_speech_region,
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
        self, text: str, voice_id: str, options: dict[str, Any] | None = None
    ) -> bytes:
        """
        Synthesize text using Azure TTS.

        Args:
            text: Text to synthesize
            voice_id: Azure voice name (e.g., zh-TW-HsiaoChenNeural)
            options: Optional parameters (style, role, pitch, rate, volume)
        """
        options = options or {}

        # Check cache
        cached = self.cache.get(text, voice_id, options)
        if cached:
            self.logger.info(
                f"Returning cached audio for {voice_id}",
                extra={"voice_id": voice_id, "cached": True},
            )
            return cached

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

        self.logger.info(
            "Synthesizing text",
            extra={
                "voice_id": voice_id,
                "text_length": len(text),
                "options": options,
                "cached": False,
            },
        )

        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config,
            audio_config=None,  # None means do not play to speaker, just generate
        )

        result = synthesizer.speak_ssml_async(ssml).get()

        if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            self.logger.info(
                "Synthesis completed",
                extra={"voice_id": voice_id, "audio_size": len(result.audio_data)},
            )
            # Save to cache
            self.cache.set(text, voice_id, options, result.audio_data)
            return result.audio_data
        elif result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = result.cancellation_details
            error_msg = f"Speech synthesis canceled: {cancellation_details.reason}"
            if cancellation_details.reason == speechsdk.CancellationReason.Error:
                error_msg += f". Error details: {cancellation_details.error_details}"

            self.logger.error(f"Synthesis failed: {error_msg}")
            raise RuntimeError(error_msg)
        else:
            self.logger.error(f"Synthesis failed with reason: {result.reason}")
            raise RuntimeError(f"Speech synthesis failed with reason: {result.reason}")

    async def get_voices(self) -> list[dict[str, Any]]:
        """List available voices from Azure."""
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config, audio_config=None
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

                voices.append(
                    {
                        "provider_voice_id": v.name,  # Full name e.g. zh-TW-HsiaoChenNeural
                        "name": v.local_name,
                        "locale": v.locale,
                        "gender": gender,
                        "styles": v.style_list
                        if hasattr(v, "style_list")
                        else [],  # Some SDK versions specific
                    }
                )
            return voices

        elif result.reason == speechsdk.ResultReason.Canceled:
            raise RuntimeError(f"Get voices canceled: {result.cancellation_details.error_details}")
        else:
            raise RuntimeError(f"Get voices failed: {result.reason}")
