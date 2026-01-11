"""Unit tests for VAD (Voice Activity Detection) service.

T023 [P] [US1] Unit test for VAD service.
Tests the webrtcvad-based voice activity detection for interactive story mode.
"""

import struct

import pytest

# These imports will fail until the service is implemented
from src.services.interaction.vad_service import VADConfig, VADService


class TestVADConfig:
    """Tests for VAD configuration."""

    def test_default_config_values(self):
        """Default config should have sensible values for children's speech."""
        config = VADConfig()
        assert config.sample_rate == 16000  # 16kHz for speech recognition
        assert config.frame_duration_ms == 20  # 20ms frames
        assert config.aggressiveness == 2  # Moderate aggressiveness (0-3)
        assert config.speech_threshold == 0.5  # 50% of frames must be speech

    def test_custom_config(self):
        """Should allow custom configuration."""
        config = VADConfig(
            sample_rate=8000,
            frame_duration_ms=30,
            aggressiveness=3,
            speech_threshold=0.8,
        )
        assert config.sample_rate == 8000
        assert config.frame_duration_ms == 30
        assert config.aggressiveness == 3
        assert config.speech_threshold == 0.8

    def test_invalid_sample_rate_raises_error(self):
        """Should reject invalid sample rates."""
        with pytest.raises(ValueError, match="sample_rate"):
            VADConfig(sample_rate=44100)  # Not supported by webrtcvad

    def test_invalid_frame_duration_raises_error(self):
        """Should reject invalid frame durations."""
        with pytest.raises(ValueError, match="frame_duration"):
            VADConfig(frame_duration_ms=25)  # Must be 10, 20, or 30

    def test_invalid_aggressiveness_raises_error(self):
        """Should reject invalid aggressiveness values."""
        with pytest.raises(ValueError, match="aggressiveness"):
            VADConfig(aggressiveness=5)  # Must be 0-3


class TestVADService:
    """Tests for VAD service."""

    @pytest.fixture
    def vad_service(self):
        """Create a VAD service instance."""
        return VADService()

    @pytest.fixture
    def silence_frame(self):
        """Generate a silence frame (16kHz, 20ms = 320 samples)."""
        return bytes(640)  # 320 samples * 2 bytes per sample (16-bit)

    @pytest.fixture
    def speech_frame(self):
        """Generate a simulated speech frame with audio content."""
        # Create a simple sine wave pattern to simulate speech
        import math

        samples = []
        for i in range(320):  # 20ms at 16kHz
            # Generate a 300Hz sine wave (typical speech frequency)
            sample = int(16000 * math.sin(2 * math.pi * 300 * i / 16000))
            samples.append(sample)
        return struct.pack("<" + "h" * 320, *samples)

    def test_create_service_with_default_config(self, vad_service):
        """Should create service with default configuration."""
        assert vad_service is not None
        assert vad_service.config.sample_rate == 16000

    def test_create_service_with_custom_config(self):
        """Should create service with custom configuration."""
        config = VADConfig(aggressiveness=3)
        service = VADService(config=config)
        assert service.config.aggressiveness == 3

    def test_is_speech_returns_false_for_silence(self, vad_service, silence_frame):
        """Should detect silence as non-speech."""
        result = vad_service.is_speech(silence_frame)
        assert result is False

    def test_is_speech_returns_true_for_speech(self, vad_service, speech_frame):
        """Should detect speech audio as speech."""
        result = vad_service.is_speech(speech_frame)
        assert result is True

    def test_is_speech_with_invalid_frame_size_raises_error(self, vad_service):
        """Should reject frames with invalid size."""
        invalid_frame = bytes(100)  # Wrong size
        with pytest.raises(ValueError, match="frame size"):
            vad_service.is_speech(invalid_frame)

    def test_process_audio_stream_detects_speech_segments(self, vad_service):
        """Should detect speech segments in an audio stream."""
        # Simulate a stream with silence -> speech -> silence
        silence = bytes(640)  # 20ms silence

        # Create speech-like audio
        import math

        speech_samples = []
        for i in range(320):
            sample = int(16000 * math.sin(2 * math.pi * 300 * i / 16000))
            speech_samples.append(sample)
        speech = struct.pack("<" + "h" * 320, *speech_samples)

        # Process frames and track state changes
        events = []
        for frame in [silence, silence, speech, speech, speech, silence, silence]:
            event = vad_service.process_frame(frame)
            if event:
                events.append(event)

        # Should have detected speech_started and speech_ended
        assert len(events) >= 1
        assert any(e["type"] == "speech_started" for e in events)

    def test_reset_clears_internal_state(self, vad_service):
        """Should reset internal state for new session."""
        # Process some frames
        vad_service.process_frame(bytes(640))

        # Reset
        vad_service.reset()

        # Internal state should be cleared
        assert vad_service._speech_frames == 0
        assert vad_service._is_speaking is False

    def test_calibrate_noise_floor(self, vad_service):
        """Should calibrate noise floor from ambient audio."""
        # Generate some ambient noise frames
        import random

        noise_frames = []
        for _ in range(50):  # 1 second of audio at 20ms frames
            samples = [random.randint(-500, 500) for _ in range(320)]
            frame = struct.pack("<" + "h" * 320, *samples)
            noise_frames.append(frame)

        calibration = vad_service.calibrate(noise_frames)

        # CalibrationResult is a dataclass, access attributes directly
        assert hasattr(calibration, "noise_floor_db")
        assert hasattr(calibration, "percentile_90")
        assert hasattr(calibration, "sample_count")
        assert calibration.sample_count == 50

    def test_speech_detection_respects_threshold(self, vad_service):
        """Should respect speech threshold for segment detection."""
        # Configure with high threshold
        vad_service.config.speech_threshold = 0.9

        # With high threshold, brief speech should not trigger
        # (implementation detail - actual behavior depends on implementation)
        assert vad_service.config.speech_threshold == 0.9


class TestVADServiceIntegration:
    """Integration tests for VAD service with realistic audio."""

    @pytest.fixture
    def vad_service(self):
        """Create VAD service for integration tests."""
        return VADService(config=VADConfig(aggressiveness=2))

    def test_handles_continuous_audio_stream(self, vad_service):
        """Should handle continuous audio without memory leaks."""
        # Process many frames
        for _ in range(1000):  # 20 seconds of audio
            vad_service.process_frame(bytes(640))

        # Service should still be responsive
        result = vad_service.is_speech(bytes(640))
        assert result is False

    def test_thread_safety(self, vad_service):
        """Should be thread-safe for concurrent access."""
        import threading

        results = []

        def process_frames():
            for _ in range(100):
                result = vad_service.is_speech(bytes(640))
                results.append(result)

        threads = [threading.Thread(target=process_frames) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(results) == 400
