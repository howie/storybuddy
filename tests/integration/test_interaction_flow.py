"""Integration tests for complete interaction flow.

T027 [P] [US1] Integration test for interaction flow.
Tests the end-to-end interaction flow from speech to AI response.
"""

import math
import struct
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.models.enums import SessionMode, SessionStatus

# These imports will fail until the services are implemented
from src.services.interaction.session_manager import SessionManager


class TestInteractionFlowIntegration:
    """Integration tests for the complete interaction flow."""

    @pytest.fixture
    async def setup_services(self):
        """Setup all required services for integration testing."""
        # These would be real service instances in integration tests
        # For now, use configured mocks
        with patch.multiple(
            "src.services.interaction",
            VADService=MagicMock,
            StreamingSTTService=MagicMock,
        ):
            session_manager = SessionManager()
            yield session_manager

    @pytest.fixture
    def generate_speech_audio(self):
        """Generate simulated speech audio for testing."""

        def _generate(duration_ms=2000, sample_rate=16000):
            """Generate sine wave audio simulating speech."""
            num_samples = int(sample_rate * duration_ms / 1000)
            samples = []
            for i in range(num_samples):
                # 300Hz sine wave with some variation
                freq = 300 + 50 * math.sin(2 * math.pi * 2 * i / sample_rate)
                sample = int(16000 * math.sin(2 * math.pi * freq * i / sample_rate))
                samples.append(sample)

            # Convert to 20ms frames
            frames = []
            frame_samples = int(sample_rate * 0.02)  # 320 samples per frame
            for i in range(0, len(samples), frame_samples):
                frame = samples[i : i + frame_samples]
                if len(frame) == frame_samples:
                    frames.append(struct.pack("<" + "h" * frame_samples, *frame))
            return frames

        return _generate

    @pytest.fixture
    def generate_silence_audio(self):
        """Generate silence audio for testing."""

        def _generate(duration_ms=1000, sample_rate=16000):
            """Generate silent audio frames."""
            num_frames = int(duration_ms / 20)  # 20ms per frame
            frame_size = int(sample_rate * 0.02 * 2)  # bytes per frame
            return [bytes(frame_size) for _ in range(num_frames)]

        return _generate

    @pytest.mark.asyncio
    async def test_complete_interaction_cycle(
        self, setup_services, generate_speech_audio, generate_silence_audio
    ):
        """Test complete cycle: calibration -> speech -> transcription -> AI response."""
        session_manager = setup_services

        # 1. Create session
        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )
        assert session.session_id is not None

        # 2. Calibration phase
        calibration_frames = generate_silence_audio(duration_ms=2000)
        for frame in calibration_frames:
            await session_manager.process_calibration_audio(session.session_id, frame)

        calibration_result = await session_manager.complete_calibration(session.session_id)
        assert calibration_result is not None
        assert "noise_floor_db" in calibration_result

        # 3. Activate session
        await session_manager.activate_session(session.session_id)
        state = session_manager.get_state(session.session_id)
        assert state.status == SessionStatus.ACTIVE

        # 4. Simulate child speaking
        speech_frames = generate_speech_audio(duration_ms=2000)

        # First frame should trigger speech_started
        events = []
        for frame in speech_frames:
            event = await session_manager.process_audio(session.session_id, frame)
            if event:
                events.append(event)

        # Should have detected speech
        assert any(e.get("type") == "speech_started" for e in events)

        # 5. End speech with silence
        silence_frames = generate_silence_audio(duration_ms=1500)
        for frame in silence_frames:
            event = await session_manager.process_audio(session.session_id, frame)
            if event:
                events.append(event)

        # Should have detected speech_ended
        assert any(e.get("type") == "speech_ended" for e in events)

        # 6. End session
        result = await session_manager.end_session(session.session_id)
        assert result is not None

    @pytest.mark.asyncio
    async def test_multiple_speech_segments(
        self, setup_services, generate_speech_audio, generate_silence_audio
    ):
        """Test handling multiple speech segments in one session."""
        session_manager = setup_services

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        # Skip calibration for brevity
        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        speech_segments = 0

        # Simulate 3 separate speech segments
        for _ in range(3):
            # Speech
            for frame in generate_speech_audio(duration_ms=1500):
                event = await session_manager.process_audio(session.session_id, frame)
                if event and event.get("type") == "speech_started":
                    speech_segments += 1

            # Silence between segments
            for frame in generate_silence_audio(duration_ms=2000):
                await session_manager.process_audio(session.session_id, frame)

        assert speech_segments == 3

        await session_manager.end_session(session.session_id)

    @pytest.mark.asyncio
    async def test_session_pause_resume(
        self, setup_services, generate_speech_audio, generate_silence_audio
    ):
        """Test pausing and resuming session during interaction."""
        session_manager = setup_services

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Start speaking
        for frame in generate_speech_audio(duration_ms=500):
            await session_manager.process_audio(session.session_id, frame)

        # Pause session
        await session_manager.pause_session(session.session_id)
        state = session_manager.get_state(session.session_id)
        assert state.status == SessionStatus.PAUSED

        # Audio during pause should be ignored
        for frame in generate_speech_audio(duration_ms=500):
            await session_manager.process_audio(session.session_id, frame)

        # Resume session
        await session_manager.resume_session(session.session_id)
        state = session_manager.get_state(session.session_id)
        assert state.status == SessionStatus.ACTIVE

        await session_manager.end_session(session.session_id)

    @pytest.mark.asyncio
    async def test_mode_switching_mid_playback(self, setup_services, generate_speech_audio):
        """Test switching between interactive and passive modes (FR-013)."""
        session_manager = setup_services

        # Start in interactive mode
        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Process some audio
        for frame in generate_speech_audio(duration_ms=500):
            await session_manager.process_audio(session.session_id, frame)

        # Switch to passive mode
        await session_manager.switch_mode(session.session_id, SessionMode.PASSIVE)
        state = session_manager.get_state(session.session_id)
        assert state.mode == SessionMode.PASSIVE

        # Audio should not be processed in passive mode
        events = []
        for frame in generate_speech_audio(duration_ms=500):
            event = await session_manager.process_audio(session.session_id, frame)
            if event:
                events.append(event)

        # Should not have speech events in passive mode
        assert not any(e.get("type") == "speech_started" for e in events)

        # Switch back to interactive
        await session_manager.switch_mode(session.session_id, SessionMode.INTERACTIVE)
        state = session_manager.get_state(session.session_id)
        assert state.mode == SessionMode.INTERACTIVE
        # Should require recalibration
        assert state.status == SessionStatus.CALIBRATING

        await session_manager.end_session(session.session_id)


class TestInteractionFlowWithSTT:
    """Integration tests with actual STT service (mocked)."""

    @pytest.fixture
    async def setup_with_stt(self):
        """Setup services with mocked STT."""
        mock_stt = MagicMock()
        mock_stt.start_session = AsyncMock()
        mock_stt.stop_session = AsyncMock()
        mock_stt.send_audio = AsyncMock()
        mock_stt.get_results = AsyncMock(
            return_value=iter(
                [
                    MagicMock(
                        text="小兔子會不會遇到大野狼",
                        is_final=True,
                        confidence=0.95,
                    )
                ]
            )
        )

        with patch(
            "src.services.interaction.streaming_stt.StreamingSTTService", return_value=mock_stt
        ):
            session_manager = SessionManager(stt_service=mock_stt)
            yield session_manager, mock_stt

    @pytest.mark.asyncio
    async def test_transcription_returned_after_speech(self, setup_with_stt):
        """Test that transcription is returned after speech ends."""
        session_manager, mock_stt = setup_with_stt

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Simulate speech
        await session_manager.handle_speech_started(session.session_id)

        # Send audio
        for _ in range(10):
            await session_manager.send_audio(session.session_id, bytes(640))

        # End speech
        transcription = await session_manager.handle_speech_ended(
            session.session_id,
            duration_ms=2000,
        )

        assert transcription is not None
        assert "小兔子" in transcription.text

        await session_manager.end_session(session.session_id)


class TestInteractionFlowErrorHandling:
    """Tests for error handling during interaction."""

    @pytest.fixture
    async def setup_services(self):
        """Setup services for error testing."""
        session_manager = SessionManager()
        yield session_manager

    @pytest.mark.asyncio
    async def test_handle_stt_service_error(self, setup_services):
        """Should handle STT service errors gracefully."""
        session_manager = setup_services

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Simulate STT error
        with patch.object(
            session_manager._stt_service,
            "get_results",
            side_effect=Exception("STT service unavailable"),
        ):
            await session_manager.handle_speech_started(session.session_id)

            error = await session_manager.handle_speech_ended(
                session.session_id,
                duration_ms=2000,
            )

            # Should return error instead of crashing
            assert (
                error is not None
                or session_manager.get_state(session.session_id).status != SessionStatus.ERROR
            )

    @pytest.mark.asyncio
    async def test_handle_network_disconnection(self, setup_services):
        """Should handle network disconnection during streaming."""
        session_manager = setup_services

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Simulate network error during audio send
        with patch.object(
            session_manager._stt_service,
            "send_audio",
            side_effect=ConnectionError("Network disconnected"),
        ):
            result = await session_manager.send_audio(session.session_id, bytes(640))

            # Should handle gracefully
            assert result is None or "error" in str(result).lower()

    @pytest.mark.asyncio
    async def test_session_recovery_after_error(self, setup_services):
        """Should allow session recovery after recoverable error."""
        session_manager = setup_services

        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Simulate temporary error
        await session_manager.handle_error(
            session.session_id,
            error=Exception("Temporary error"),
            recoverable=True,
        )

        # Session should be recoverable
        state = session_manager.get_state(session.session_id)
        assert state is not None
        assert state.status != SessionStatus.ERROR

        # Should be able to continue
        await session_manager.send_audio(session.session_id, bytes(640))
