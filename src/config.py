"""Configuration management for StoryBuddy using pydantic-settings."""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Server
    debug: bool = Field(default=False, description="Enable debug mode")
    api_host: str = Field(default="0.0.0.0", description="API host")
    api_port: int = Field(default=8000, description="API port")

    # Database
    database_url: str = Field(
        default="sqlite+aiosqlite:///./data/db/storybuddy.db",
        description="Database connection URL",
    )

    # Storage
    data_dir: Path = Field(default=Path("./data"), description="Data directory path")

    # ElevenLabs (Voice Cloning TTS)
    elevenlabs_api_key: str = Field(default="", description="ElevenLabs API key")

    # Azure Speech Services (STT)
    azure_speech_key: str = Field(default="", description="Azure Speech API key")
    azure_speech_region: str = Field(default="eastasia", description="Azure Speech region")

    # Google Cloud TTS
    google_application_credentials: str | None = Field(
         default=None, description="Path to Google Cloud Service Account JSON"
    )

    # Anthropic Claude (LLM)
    anthropic_api_key: str = Field(default="", description="Anthropic API key")

    # Voice Recording Settings
    min_voice_sample_seconds: int = Field(
        default=30, description="Minimum voice sample duration in seconds"
    )
    max_voice_sample_seconds: int = Field(
        default=180, description="Maximum voice sample duration in seconds"
    )

    # Story Settings
    max_story_word_count: int = Field(default=5000, description="Maximum story word count")
    words_per_minute: int = Field(
        default=200, description="Assumed reading speed for duration estimation"
    )

    # Q&A Settings
    max_qa_messages: int = Field(default=10, description="Maximum messages per Q&A session")

    # Logging
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        default="INFO", description="Logging level"
    )
    log_format: Literal["json", "text"] = Field(default="json", description="Log output format")

    @property
    def voice_samples_dir(self) -> Path:
        """Path to voice samples directory."""
        return self.data_dir / "audio" / "voice_samples"

    @property
    def stories_audio_dir(self) -> Path:
        """Path to story audio directory."""
        return self.data_dir / "audio" / "stories"

    @property
    def qa_responses_dir(self) -> Path:
        """Path to Q&A responses directory."""
        return self.data_dir / "audio" / "qa_responses"

    @property
    def parent_answers_dir(self) -> Path:
        """Path to parent answers directory."""
        return self.data_dir / "audio" / "parent_answers"

    @property
    def db_path(self) -> Path:
        """Path to SQLite database file."""
        return self.data_dir / "db" / "storybuddy.db"

    def ensure_directories(self) -> None:
        """Create all required data directories if they don't exist."""
        directories = [
            self.data_dir / "db",
            self.voice_samples_dir,
            self.stories_audio_dir,
            self.qa_responses_dir,
            self.parent_answers_dir,
        ]
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
