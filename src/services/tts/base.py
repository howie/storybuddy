from abc import ABC, abstractmethod
from typing import Any

from src.models.voice import TTSProvider as TTSProviderEnum


class TTSProvider(ABC):
    """Abstract base class for TTS providers."""

    @property
    @abstractmethod
    def provider_type(self) -> TTSProviderEnum:
        """Return the provider type."""
        pass

    @abstractmethod
    async def synthesize(
        self, text: str, voice_id: str, options: dict[str, Any] | None = None
    ) -> bytes:
        """
        Synthesize text to audio.

        Args:
            text: Text to synthesize
            voice_id: The provider-specific voice ID to use
            options: Optional SSML or other options

        Returns:
            Audio data as bytes
        """
        pass

    @abstractmethod
    async def get_voices(self) -> list[dict[str, Any]]:
        """
        List available voices from this provider.

        Returns:
            List of voice dictionaries (to be mapped to VoiceCharacter models)
        """
        pass

    @abstractmethod
    async def validate_credentials(self) -> bool:
        """Validate provider credentials."""
        pass
