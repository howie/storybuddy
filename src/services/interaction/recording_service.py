"""Recording Service for audio storage with privacy controls.

T061 [US3] Implement audio recording storage service.
Handles saving, retrieving, and managing audio recordings with privacy settings.
"""

import asyncio
import logging
import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


class RecordingStatus(Enum):
    """Status of a recording."""

    PENDING = "pending"
    SAVED = "saved"
    PROCESSING = "processing"
    FAILED = "failed"
    DELETED = "deleted"


@dataclass
class RecordingServiceConfig:
    """Configuration for Recording Service."""

    enabled: bool = True
    storage_path: str = "./recordings"
    max_recording_duration_seconds: int = 60
    retention_days: int = 30
    file_format: str = "wav"
    sample_rate: int = 16000


@dataclass
class Recording:
    """Recording data model."""

    recording_id: str
    session_id: str
    segment_id: str
    audio_path: str
    duration_ms: int = 0
    file_size_bytes: int = 0
    status: RecordingStatus = RecordingStatus.PENDING
    created_at: datetime = field(default_factory=datetime.utcnow)
    expires_at: datetime | None = None

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "recordingId": self.recording_id,
            "sessionId": self.session_id,
            "segmentId": self.segment_id,
            "audioPath": self.audio_path,
            "durationMs": self.duration_ms,
            "fileSizeBytes": self.file_size_bytes,
            "status": self.status.value,
            "createdAt": self.created_at.isoformat() + "Z",
            "expiresAt": self.expires_at.isoformat() + "Z" if self.expires_at else None,
        }


class RecordingService:
    """Service for managing audio recordings with privacy controls.

    Implements FR-018 (recording toggle) and FR-019 (retention period).
    """

    def __init__(self, config: RecordingServiceConfig | None = None):
        """Initialize Recording Service.

        Args:
            config: Service configuration.
        """
        self.config = config or RecordingServiceConfig()
        self._recordings: dict[str, Recording] = {}
        self._ensure_storage_path()

    def _ensure_storage_path(self) -> None:
        """Ensure storage directory exists."""
        path = Path(self.config.storage_path)
        path.mkdir(parents=True, exist_ok=True)

    async def save_recording(
        self,
        audio_data: bytes,
        session_id: str,
        segment_id: str,
        settings: Any,  # InteractionSettings
        duration_ms: int | None = None,
    ) -> Recording | None:
        """Save an audio recording if recording is enabled.

        Args:
            audio_data: Raw audio bytes.
            session_id: Session ID.
            segment_id: Segment ID within session.
            settings: User's interaction settings.
            duration_ms: Audio duration in milliseconds.

        Returns:
            Recording object if saved, None if skipped.
        """
        # Check if recording is enabled in settings
        if not getattr(settings, "recording_enabled", False):
            logger.debug(f"Recording disabled for session {session_id}")
            return None

        # Skip empty audio
        if not audio_data or len(audio_data) == 0:
            logger.debug(f"Skipping empty audio for session {session_id}")
            return None

        # Generate recording ID and path
        recording_id = str(uuid.uuid4())
        session_dir = Path(self.config.storage_path) / session_id
        session_dir.mkdir(parents=True, exist_ok=True)

        file_name = f"{segment_id}.{self.config.file_format}"
        audio_path = session_dir / file_name

        try:
            # Truncate if exceeds max duration
            max_bytes = self._calculate_max_bytes(duration_ms)
            if len(audio_data) > max_bytes:
                audio_data = audio_data[:max_bytes]
                duration_ms = self.config.max_recording_duration_seconds * 1000

            # Write audio file
            await asyncio.to_thread(self._write_file, audio_path, audio_data)

            # Calculate expiration
            expires_at = datetime.utcnow() + timedelta(days=self.config.retention_days)

            # Create recording record
            recording = Recording(
                recording_id=recording_id,
                session_id=session_id,
                segment_id=segment_id,
                audio_path=str(audio_path),
                duration_ms=duration_ms or self._estimate_duration(len(audio_data)),
                file_size_bytes=len(audio_data),
                status=RecordingStatus.SAVED,
                expires_at=expires_at,
            )

            self._recordings[recording_id] = recording
            logger.info(f"Recording saved: {recording_id} ({len(audio_data)} bytes)")

            return recording

        except Exception as e:
            logger.error(f"Failed to save recording: {e}")
            raise

    def _write_file(self, path: Path, data: bytes) -> None:
        """Write file with restricted permissions."""
        with open(path, "wb") as f:
            f.write(data)
        # Set restrictive permissions (owner read/write only)
        os.chmod(path, 0o600)

    def _calculate_max_bytes(self, duration_ms: int | None) -> int:
        """Calculate maximum bytes based on duration limit."""
        max_duration_ms = self.config.max_recording_duration_seconds * 1000
        # Assuming 16kHz mono 16-bit = 32000 bytes/second
        bytes_per_second = self.config.sample_rate * 2
        return int(bytes_per_second * max_duration_ms / 1000)

    def _estimate_duration(self, byte_length: int) -> int:
        """Estimate duration from byte length."""
        bytes_per_second = self.config.sample_rate * 2
        return int(byte_length * 1000 / bytes_per_second)

    async def get_recording(self, recording_id: str) -> Recording | None:
        """Get a specific recording by ID.

        Args:
            recording_id: Recording ID.

        Returns:
            Recording if found, None otherwise.
        """
        return self._recordings.get(recording_id)

    async def get_recordings(self, session_id: str) -> list[Recording]:
        """Get all recordings for a session.

        Args:
            session_id: Session ID.

        Returns:
            List of recordings.
        """
        return [
            r
            for r in self._recordings.values()
            if r.session_id == session_id and r.status != RecordingStatus.DELETED
        ]

    async def delete_recording(self, recording_id: str) -> bool:
        """Delete a specific recording.

        Args:
            recording_id: Recording ID.

        Returns:
            True if deleted, False otherwise.
        """
        recording = self._recordings.get(recording_id)
        if not recording:
            return False

        try:
            # Delete file
            audio_path = Path(recording.audio_path)
            if audio_path.exists():
                await asyncio.to_thread(audio_path.unlink)

            # Mark as deleted
            recording.status = RecordingStatus.DELETED
            logger.info(f"Recording deleted: {recording_id}")

            return True

        except Exception as e:
            logger.error(f"Failed to delete recording {recording_id}: {e}")
            return False

    async def delete_session_recordings(self, session_id: str) -> int:
        """Delete all recordings for a session.

        Args:
            session_id: Session ID.

        Returns:
            Number of recordings deleted.
        """
        recordings = await self.get_recordings(session_id)
        deleted = 0

        for recording in recordings:
            if await self.delete_recording(recording.recording_id):
                deleted += 1

        # Try to remove session directory if empty
        session_dir = Path(self.config.storage_path) / session_id
        try:
            if session_dir.exists() and not any(session_dir.iterdir()):
                session_dir.rmdir()
        except Exception:
            pass

        logger.info(f"Deleted {deleted} recordings for session {session_id}")
        return deleted

    def get_expired_recordings(self) -> list[Recording]:
        """Get all recordings that have exceeded retention period.

        Returns:
            List of expired recordings.
        """
        now = datetime.utcnow()
        return [
            r
            for r in self._recordings.values()
            if r.expires_at and r.expires_at < now and r.status != RecordingStatus.DELETED
        ]

    async def cleanup_expired(self) -> int:
        """Delete all expired recordings.

        Returns:
            Number of recordings deleted.
        """
        expired = self.get_expired_recordings()
        deleted = 0

        for recording in expired:
            if await self.delete_recording(recording.recording_id):
                deleted += 1

        if deleted > 0:
            logger.info(f"Cleaned up {deleted} expired recordings")

        return deleted

    async def get_storage_usage(self, session_id: str | None = None) -> dict[str, Any]:
        """Get storage usage statistics.

        Args:
            session_id: Optional session ID to filter.

        Returns:
            Storage usage statistics.
        """
        if session_id:
            recordings = await self.get_recordings(session_id)
        else:
            recordings = [
                r for r in self._recordings.values() if r.status != RecordingStatus.DELETED
            ]

        total_bytes = sum(r.file_size_bytes for r in recordings)
        total_duration_ms = sum(r.duration_ms for r in recordings)

        return {
            "totalRecordings": len(recordings),
            "totalSizeBytes": total_bytes,
            "totalSizeMB": round(total_bytes / (1024 * 1024), 2),
            "totalDurationMs": total_duration_ms,
            "totalDurationSeconds": round(total_duration_ms / 1000, 1),
        }


# Singleton instance
_recording_service: RecordingService | None = None


def get_recording_service() -> RecordingService:
    """Get or create the global recording service instance."""
    global _recording_service
    if _recording_service is None:
        _recording_service = RecordingService()
    return _recording_service
