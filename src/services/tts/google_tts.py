import logging
import os
from typing import Any

from google.cloud import texttospeech

from src.models.voice import Gender
from src.models.voice import TTSProvider as TTSProviderEnum
from src.services.tts.base import TTSProvider
from src.services.tts.cache import TTSCache


class GoogleTTSProvider(TTSProvider):
    def __init__(self) -> None:
        self.logger = logging.getLogger("storybuddy.services.tts.google")
        self.cache = TTSCache()
        self._credentials_setup = False
        self.client = None

        # Check credentials existence before initializing client to avoid crash
        # Actually initializing client might look for env var.
        try:
            # We delay actual client usage or check env var broadly
            if os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or os.getenv("GOOGLE_API_KEY"):
                self.client = texttospeech.TextToSpeechClient()
                self._credentials_setup = True
            else:
                self.logger.warning("GOOGLE_APPLICATION_CREDENTIALS not set. Google TTS disabled.")
        except Exception as e:
            self.logger.warning(f"Failed to initialize Google TTS client: {e}")

    @property
    def provider_type(self) -> TTSProviderEnum:
        return TTSProviderEnum.GOOGLE

    async def validate_credentials(self) -> bool:
        if not self._credentials_setup or not self.client:
            return False
        try:
            self.client.list_voices(language_code="en-US")
            return True
        except Exception as e:
            self.logger.error(f"Google TTS validation failed: {e}")
            return False

    async def synthesize(
        self, text: str, voice_id: str, options: dict[str, Any] | None = None
    ) -> bytes:
        if not self.client:
            raise RuntimeError("Google TTS client is not initialized.")

        options = options or {}

        # Check cache
        cached = self.cache.get(text, voice_id, options)
        if cached:
            self.logger.info(
                f"Returning cached audio for {voice_id}",
                extra={"voice_id": voice_id, "cached": True},
            )
            return cached

        # Prepare Input
        synthesis_input = texttospeech.SynthesisInput(text=text)

        # Prepare Voice
        # Note: Google Voice Selection usually requires language_code AND name
        # We assume voice_id is the full name e.g. "cmn-TW-Wavenet-A"
        # We can deduce language from name prefix usually "cmn-TW..."
        language_code = "zh-TW"  # Default
        if voice_id.startswith("cmn-TW"):
            language_code = "cmn-TW"
        elif voice_id.startswith("en-US"):
            language_code = "en-US"

        voice_params = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_id)

        # Prepare Audio Config
        # Handle simple prosody via SSML would be better, but sticking to text for MVP
        # unless `options` has pitch/rate.
        # If options has pitch/rate, we should use SSML input.

        # Google expects semitones or double for pitch.
        # Azure uses "0st", Google uses double 0.0 or semitones string in SSML.
        # AudioConfig in Google API allows `pitch` (double, -20.0 to 20.0) and `speaking_rate` (0.25 to 4.0)

        # Conversion attempt (simplified)
        google_pitch = 0.0
        google_rate = 1.0

        # Parse rate "1.0" -> 1.0
        try:
            if "rate" in options:
                google_rate = float(options["rate"])
        except (ValueError, TypeError):
            pass

        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=google_rate,
            pitch=google_pitch,
        )

        # Exec
        self.logger.info(f"Synthesizing with Google TTS: {voice_id}")

        try:
            response = self.client.synthesize_speech(
                input=synthesis_input, voice=voice_params, audio_config=audio_config
            )

            # Save to cache
            self.cache.set(text, voice_id, options, response.audio_content)

            return response.audio_content

        except Exception as e:
            self.logger.error(f"Google TTS synthesis failed: {e}")
            raise RuntimeError(f"Google TTS synthesis failed: {e}")

    async def get_voices(self) -> list[dict[str, Any]]:
        if not self.client:
            return []

        try:
            response = self.client.list_voices(language_code="zh-TW")
            voices = []
            for voice in response.voices:
                # Filter for just Mandarin for now
                if "cmn-TW" in voice.language_codes:
                    voices.append(
                        {
                            "id": voice.name,
                            "name": f"Google {voice.name.split('-')[-1]}",  # e.g. Google A
                            "gender": self._map_gender(voice.ssml_gender),
                            "language": "zh-TW",
                        }
                    )
            return voices
        except Exception as e:
            self.logger.error(f"Failed to list Google voices: {e}")
            return []

    def _map_gender(self, google_gender: texttospeech.SsmlVoiceGender) -> Gender:
        # Map to our Enum
        if google_gender == texttospeech.SsmlVoiceGender.MALE:
            return Gender.MALE
        elif google_gender == texttospeech.SsmlVoiceGender.FEMALE:
            return Gender.FEMALE
        return Gender.NEUTRAL
