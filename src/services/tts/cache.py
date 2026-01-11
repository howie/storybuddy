import hashlib
import json
import logging
from pathlib import Path
from typing import Any


class TTSCache:
    """Simple file-based cache for TTS audio."""

    def __init__(self, cache_dir: str = ".tts_cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.logger = logging.getLogger("storybuddy.services.tts.cache")

    def _generate_key(self, text: str, voice_id: str, options: dict[str, Any] | None) -> str:
        """Generate a stable hash key for the inputs."""
        # Sort keys for stability
        options_str = json.dumps(options or {}, sort_keys=True)
        content = f"{text}|{voice_id}|{options_str}".encode()
        return hashlib.sha256(content).hexdigest()

    def get(self, text: str, voice_id: str, options: dict[str, Any] | None = None) -> bytes | None:
        """Retrieve audio from cache if exists."""
        key = self._generate_key(text, voice_id, options)
        file_path = self.cache_dir / f"{key}.mp3"  # Assuming MP3/audio for now

        if file_path.exists():
            self.logger.debug(f"Cache hit for key: {key}")
            return file_path.read_bytes()

        self.logger.debug(f"Cache miss for key: {key}")
        return None

    def set(self, text: str, voice_id: str, options: dict[str, Any] | None, data: bytes) -> None:
        """Save audio to cache."""
        key = self._generate_key(text, voice_id, options)
        file_path = self.cache_dir / f"{key}.mp3"

        try:
            file_path.write_bytes(data)
            self.logger.debug(f"Cached audio for key: {key}")
        except Exception as e:
            self.logger.error(f"Failed to write cache: {e}")
