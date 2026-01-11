import logging
from typing import Any

from elevenlabs import VoiceSettings
from elevenlabs.client import ElevenLabs

from src.config import get_settings
from src.models.voice import Gender
from src.models.voice import TTSProvider as TTSProviderEnum
from src.services.tts.base import TTSProvider
from src.services.tts.cache import TTSCache


class ElevenLabsProvider(TTSProvider):
    def __init__(self):
        self.logger = logging.getLogger("storybuddy.services.tts.elevenlabs")
        self.settings = get_settings()
        self.cache = TTSCache()

        if self.settings.elevenlabs_api_key:
            self.client = ElevenLabs(api_key=self.settings.elevenlabs_api_key)
        else:
            self.logger.warning("ELEVENLABS_API_KEY not set. ElevenLabs TTS disabled.")
            self.client = None

    @property
    def provider_type(self) -> TTSProviderEnum:
        return TTSProviderEnum.ELEVENLABS

    async def validate_credentials(self) -> bool:
        if not self.client:
            return False
        try:
            # Check model info to validate key
            self.client.models.get_all()
            return True
        except Exception as e:
            self.logger.error(f"ElevenLabs validation failed: {e}")
            return False

    async def synthesize(
        self, text: str, voice_id: str, options: dict[str, Any] | None = None
    ) -> bytes:
        if not self.client:
            raise RuntimeError("ElevenLabs client is not initialized.")

        options = options or {}

        # Check cache
        cached = self.cache.get(text, voice_id, options)
        if cached:
            self.logger.info(
                f"Returning cached audio for {voice_id}",
                extra={"voice_id": voice_id, "cached": True},
            )
            return cached

        # Model selection (Multilingual v2 for Chinese support)
        # Allows override via options
        model_id = options.get("model_id", "eleven_multilingual_v2")

        self.logger.info(f"Synthesizing with ElevenLabs: {voice_id} (Model: {model_id})")

        try:
            # ElevenLabs generate returns a generator of bytes (stream)
            # We consume it all for now.
            audio_generator = self.client.generate(
                text=text,
                voice=voice_id,
                model=model_id,
                voice_settings=VoiceSettings(
                    stability=options.get("stability", 0.5),
                    similarity_boost=options.get("similarity_boost", 0.75),
                    style=options.get("style", 0.0),
                    use_speaker_boost=True,
                ),
            )

            # consume generator
            audio_data = b"".join(audio_generator)

            # Save to cache
            self.cache.set(text, voice_id, options, audio_data)

            return audio_data

        except Exception as e:
            self.logger.error(f"ElevenLabs synthesis failed: {e}")
            raise RuntimeError(f"ElevenLabs synthesis failed: {e}")

    async def get_voices(self) -> list[dict[str, Any]]:
        if not self.client:
            return []

        try:
            response = self.client.voices.get_all()
            # response.voices is a list of Voice objects
            voices = []
            for voice in response.voices:
                # We can filter or return all. Let's return all.
                # ElevenLabs voice object has name, voice_id, labels, etc.
                gender_str = "neutral"
                if voice.labels and "gender" in voice.labels:
                    gender_str = voice.labels["gender"]

                voices.append(
                    {
                        "id": voice.voice_id,
                        "name": voice.name,
                        "gender": self._map_gender(gender_str),
                        "language": "multilingual",  # ElevenLabs voices are often multilingual
                    }
                )
            return voices
        except Exception as e:
            self.logger.error(f"Failed to list ElevenLabs voices: {e}")
            return []

    def _map_gender(self, gender_str: str) -> Gender:
        g = gender_str.lower()
        if "female" in g:
            return Gender.FEMALE
        elif "male" in g:
            return Gender.MALE
        return Gender.NEUTRAL
