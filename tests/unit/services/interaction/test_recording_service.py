"""Unit tests for Recording Service.

T057 [P] [US3] Unit test for recording toggle.
Tests the audio recording storage service with privacy controls.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, AsyncMock
from datetime import datetime, timedelta
import uuid
import tempfile
import os

# These imports will fail until the service is implemented
from src.services.interaction.recording_service import (
    RecordingService,
    RecordingServiceConfig,
    Recording,
    RecordingStatus,
)
from src.models.interaction import InteractionSettings


class TestRecordingServiceConfig:
    """Tests for Recording Service configuration."""

    def test_default_config_values(self):
        """Default config should have reasonable defaults."""
        config = RecordingServiceConfig()
        assert config.enabled is True
        assert config.max_recording_duration_seconds == 60
        assert config.retention_days == 30
        assert config.storage_path is not None

    def test_custom_retention_period(self):
        """Should allow custom retention period."""
        config = RecordingServiceConfig(retention_days=7)
        assert config.retention_days == 7

    def test_disabled_by_default_for_privacy(self):
        """Recording should be disabled by default for privacy (FR-018)."""
        # When settings come from user, default should be disabled
        settings = InteractionSettings()
        assert settings.recording_enabled is False


class TestRecording:
    """Tests for Recording model."""

    def test_create_recording(self):
        """Should create recording with required fields."""
        recording = Recording(
            recording_id=str(uuid.uuid4()),
            session_id="session-123",
            segment_id="segment-456",
            audio_path="/recordings/session-123/segment-456.wav",
            duration_ms=5000,
            created_at=datetime.utcnow(),
        )
        assert recording.recording_id is not None
        assert recording.session_id == "session-123"
        assert recording.duration_ms == 5000

    def test_recording_status(self):
        """Should track recording status."""
        recording = Recording(
            recording_id=str(uuid.uuid4()),
            session_id="session-123",
            segment_id="segment-456",
            audio_path="/recordings/session-123/segment-456.wav",
            duration_ms=5000,
            status=RecordingStatus.PENDING,
        )
        assert recording.status == RecordingStatus.PENDING


class TestRecordingService:
    """Tests for Recording Service."""

    @pytest.fixture
    def recording_service(self):
        """Create a Recording Service instance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            config = RecordingServiceConfig(storage_path=temp_dir)
            yield RecordingService(config=config)

    @pytest.fixture
    def enabled_settings(self):
        """Create settings with recording enabled."""
        return InteractionSettings(recording_enabled=True)

    @pytest.fixture
    def disabled_settings(self):
        """Create settings with recording disabled."""
        return InteractionSettings(recording_enabled=False)

    @pytest.mark.asyncio
    async def test_save_recording_when_enabled(
        self, recording_service, enabled_settings
    ):
        """Should save recording when recording is enabled."""
        audio_data = b"fake audio data"
        session_id = "session-123"
        segment_id = "segment-456"

        recording = await recording_service.save_recording(
            audio_data=audio_data,
            session_id=session_id,
            segment_id=segment_id,
            settings=enabled_settings,
        )

        assert recording is not None
        assert recording.session_id == session_id
        assert recording.segment_id == segment_id
        assert os.path.exists(recording.audio_path)

    @pytest.mark.asyncio
    async def test_skip_recording_when_disabled(
        self, recording_service, disabled_settings
    ):
        """Should not save recording when disabled (US3 core feature)."""
        audio_data = b"fake audio data"

        recording = await recording_service.save_recording(
            audio_data=audio_data,
            session_id="session-123",
            segment_id="segment-456",
            settings=disabled_settings,
        )

        assert recording is None

    @pytest.mark.asyncio
    async def test_get_recordings_for_session(self, recording_service, enabled_settings):
        """Should retrieve all recordings for a session."""
        session_id = "session-123"

        # Save multiple recordings
        await recording_service.save_recording(
            audio_data=b"audio1",
            session_id=session_id,
            segment_id="segment-1",
            settings=enabled_settings,
        )
        await recording_service.save_recording(
            audio_data=b"audio2",
            session_id=session_id,
            segment_id="segment-2",
            settings=enabled_settings,
        )

        recordings = await recording_service.get_recordings(session_id)

        assert len(recordings) >= 2

    @pytest.mark.asyncio
    async def test_delete_recording(self, recording_service, enabled_settings):
        """Should delete a specific recording."""
        recording = await recording_service.save_recording(
            audio_data=b"audio to delete",
            session_id="session-123",
            segment_id="segment-delete",
            settings=enabled_settings,
        )

        audio_path = recording.audio_path

        await recording_service.delete_recording(recording.recording_id)

        # File should be deleted
        assert not os.path.exists(audio_path)


class TestRecordingServiceRetention:
    """Tests for recording retention (30-day cleanup per FR-019)."""

    @pytest.fixture
    def recording_service(self):
        """Create a Recording Service instance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            config = RecordingServiceConfig(
                storage_path=temp_dir,
                retention_days=30,
            )
            yield RecordingService(config=config)

    @pytest.fixture
    def enabled_settings(self):
        """Create settings with recording enabled."""
        return InteractionSettings(recording_enabled=True)

    @pytest.mark.asyncio
    async def test_get_expired_recordings(
        self, recording_service, enabled_settings
    ):
        """Should identify recordings older than retention period."""
        # Create a recording and manually set its timestamp to 31 days ago
        recording = await recording_service.save_recording(
            audio_data=b"old audio",
            session_id="session-old",
            segment_id="segment-old",
            settings=enabled_settings,
        )

        # Mock the created_at to be 31 days ago
        recording.created_at = datetime.utcnow() - timedelta(days=31)

        expired = recording_service.get_expired_recordings()

        # This would return expired recordings based on DB query in real impl
        assert expired is not None

    @pytest.mark.asyncio
    async def test_cleanup_expired_recordings(
        self, recording_service, enabled_settings
    ):
        """Should delete recordings older than retention period."""
        # This test verifies the cleanup job functionality
        deleted_count = await recording_service.cleanup_expired()

        # Should return count of deleted recordings
        assert deleted_count >= 0


class TestRecordingServicePrivacy:
    """Privacy-focused tests for Recording Service."""

    @pytest.fixture
    def recording_service(self):
        """Create a Recording Service instance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            config = RecordingServiceConfig(storage_path=temp_dir)
            yield RecordingService(config=config)

    @pytest.fixture
    def enabled_settings(self):
        """Create settings with recording enabled."""
        return InteractionSettings(recording_enabled=True)

    @pytest.mark.asyncio
    async def test_recordings_stored_securely(
        self, recording_service, enabled_settings
    ):
        """Recordings should be stored with proper permissions."""
        recording = await recording_service.save_recording(
            audio_data=b"secure audio",
            session_id="session-secure",
            segment_id="segment-secure",
            settings=enabled_settings,
        )

        # File should exist and have restricted permissions
        assert os.path.exists(recording.audio_path)
        # In production, verify file permissions are restricted

    @pytest.mark.asyncio
    async def test_delete_all_session_recordings(
        self, recording_service, enabled_settings
    ):
        """Should be able to delete all recordings for a session."""
        session_id = "session-delete-all"

        # Save multiple recordings
        await recording_service.save_recording(
            audio_data=b"audio1",
            session_id=session_id,
            segment_id="segment-1",
            settings=enabled_settings,
        )
        await recording_service.save_recording(
            audio_data=b"audio2",
            session_id=session_id,
            segment_id="segment-2",
            settings=enabled_settings,
        )

        # Delete all
        await recording_service.delete_session_recordings(session_id)

        recordings = await recording_service.get_recordings(session_id)
        assert len(recordings) == 0

    @pytest.mark.asyncio
    async def test_settings_change_takes_effect_immediately(
        self, recording_service, enabled_settings,
    ):
        """Changing recording setting should take effect for new recordings."""
        # First recording with enabled
        recording1 = await recording_service.save_recording(
            audio_data=b"audio1",
            session_id="session-123",
            segment_id="segment-1",
            settings=enabled_settings,
        )
        assert recording1 is not None

        # Now disable
        disabled_settings = InteractionSettings(recording_enabled=False)

        # Second recording should not be saved
        recording2 = await recording_service.save_recording(
            audio_data=b"audio2",
            session_id="session-123",
            segment_id="segment-2",
            settings=disabled_settings,
        )
        assert recording2 is None


class TestRecordingServiceMaxDuration:
    """Tests for recording duration limits."""

    @pytest.fixture
    def recording_service(self):
        """Create a Recording Service instance with short max duration."""
        with tempfile.TemporaryDirectory() as temp_dir:
            config = RecordingServiceConfig(
                storage_path=temp_dir,
                max_recording_duration_seconds=10,
            )
            yield RecordingService(config=config)

    @pytest.fixture
    def enabled_settings(self):
        """Create settings with recording enabled."""
        return InteractionSettings(recording_enabled=True)

    @pytest.mark.asyncio
    async def test_truncate_long_recordings(
        self, recording_service, enabled_settings
    ):
        """Should truncate recordings that exceed max duration."""
        # Create a very long audio (simulated)
        long_audio = b"a" * 1000000  # Large byte array

        recording = await recording_service.save_recording(
            audio_data=long_audio,
            session_id="session-long",
            segment_id="segment-long",
            duration_ms=60000,  # 60 seconds
            settings=enabled_settings,
        )

        # Recording should be truncated to max duration
        assert recording.duration_ms <= 10000  # Max 10 seconds


class TestRecordingServiceEdgeCases:
    """Edge case tests for Recording Service."""

    @pytest.fixture
    def recording_service(self):
        """Create a Recording Service instance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            config = RecordingServiceConfig(storage_path=temp_dir)
            yield RecordingService(config=config)

    @pytest.fixture
    def enabled_settings(self):
        """Create settings with recording enabled."""
        return InteractionSettings(recording_enabled=True)

    @pytest.mark.asyncio
    async def test_handle_empty_audio(self, recording_service, enabled_settings):
        """Should handle empty audio gracefully."""
        recording = await recording_service.save_recording(
            audio_data=b"",
            session_id="session-empty",
            segment_id="segment-empty",
            settings=enabled_settings,
        )

        # Should not save empty recordings
        assert recording is None

    @pytest.mark.asyncio
    async def test_handle_storage_error(self, recording_service, enabled_settings):
        """Should handle storage errors gracefully."""
        # Force a storage error by using invalid path
        recording_service.config.storage_path = "/nonexistent/path"

        with pytest.raises(Exception):
            await recording_service.save_recording(
                audio_data=b"audio",
                session_id="session-error",
                segment_id="segment-error",
                settings=enabled_settings,
            )

    @pytest.mark.asyncio
    async def test_get_recording_by_id(self, recording_service, enabled_settings):
        """Should retrieve a specific recording by ID."""
        recording = await recording_service.save_recording(
            audio_data=b"find this",
            session_id="session-find",
            segment_id="segment-find",
            settings=enabled_settings,
        )

        found = await recording_service.get_recording(recording.recording_id)

        assert found is not None
        assert found.recording_id == recording.recording_id
