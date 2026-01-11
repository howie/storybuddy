"""
T085 [P] [US5] Unit test for noise calibration.

Tests the noise calibration service for accurate environment noise detection.
"""

import math

import numpy as np
import pytest

from src.services.interaction.vad_service import (
    CalibrationResult,
    VADConfig,
    VADService,
)


class TestNoiseCalibration:
    """Test suite for noise calibration functionality."""

    @pytest.fixture
    def vad_service(self) -> VADService:
        """Create a VAD service instance."""
        config = VADConfig(
            sample_rate=16000,
            frame_duration_ms=20,
            calibration_duration_ms=2000,
        )
        return VADService(config)

    def generate_silent_audio(self, duration_ms: int, noise_db: float = -50) -> list[bytes]:
        """Generate silent audio frames with specified noise level.

        Args:
            duration_ms: Duration in milliseconds.
            noise_db: Noise level in dB.

        Returns:
            List of audio frames.
        """
        sample_rate = 16000
        samples_per_frame = 320  # 20ms at 16kHz
        num_frames = duration_ms // 20

        # Convert dB to amplitude
        amplitude = 10 ** (noise_db / 20) * 32767

        frames = []
        for _ in range(num_frames):
            # Generate noise samples
            noise = np.random.normal(0, amplitude, samples_per_frame)
            noise = np.clip(noise, -32767, 32767).astype(np.int16)
            frames.append(noise.tobytes())

        return frames

    def generate_speech_audio(self, duration_ms: int, speech_db: float = -20) -> list[bytes]:
        """Generate audio frames simulating speech.

        Args:
            duration_ms: Duration in milliseconds.
            speech_db: Speech level in dB.

        Returns:
            List of audio frames.
        """
        sample_rate = 16000
        samples_per_frame = 320
        num_frames = duration_ms // 20

        amplitude = 10 ** (speech_db / 20) * 32767

        frames = []
        for i in range(num_frames):
            # Generate speech-like signal (mix of frequencies)
            t = np.linspace(0, 0.02, samples_per_frame)
            signal = amplitude * (
                0.5 * np.sin(2 * np.pi * 200 * t)
                + 0.3 * np.sin(2 * np.pi * 400 * t)
                + 0.2 * np.sin(2 * np.pi * 800 * t)
            )
            signal = np.clip(signal, -32767, 32767).astype(np.int16)
            frames.append(signal.tobytes())

        return frames

    def test_calibration_requires_minimum_samples(self, vad_service: VADService):
        """Test that calibration requires minimum number of samples."""
        # Provide insufficient samples
        frames = self.generate_silent_audio(500)  # Only 500ms

        result = vad_service.calibrate(frames)

        # Should still produce result but with lower sample count
        assert result.sample_count < 100  # Less than 2 seconds worth

    def test_calibration_calculates_noise_floor(self, vad_service: VADService):
        """Test that calibration correctly estimates noise floor."""
        noise_db = -45
        frames = self.generate_silent_audio(2000, noise_db=noise_db)

        result = vad_service.calibrate(frames)

        # Noise floor should be close to input noise level
        assert -60 <= result.noise_floor_db <= -20
        # Allow some tolerance for calculation differences
        assert abs(result.noise_floor_db - noise_db) < 15

    def test_calibration_detects_quiet_environment(self, vad_service: VADService):
        """Test calibration in a quiet environment."""
        frames = self.generate_silent_audio(2000, noise_db=-55)

        result = vad_service.calibrate(frames)

        # Should detect quiet environment
        assert result.noise_floor_db < -40

    def test_calibration_detects_noisy_environment(self, vad_service: VADService):
        """Test calibration in a noisy environment."""
        frames = self.generate_silent_audio(2000, noise_db=-30)

        result = vad_service.calibrate(frames)

        # Should detect noisy environment
        assert result.noise_floor_db > -45

    def test_calibration_calculates_percentile_90(self, vad_service: VADService):
        """Test that calibration calculates 90th percentile correctly."""
        frames = self.generate_silent_audio(2000, noise_db=-45)

        result = vad_service.calibrate(frames)

        # 90th percentile should be above noise floor
        assert result.percentile_90 >= result.noise_floor_db

    def test_calibration_stores_sample_count(self, vad_service: VADService):
        """Test that calibration stores the sample count."""
        frames = self.generate_silent_audio(2000)

        result = vad_service.calibrate(frames)

        assert result.sample_count > 0
        assert result.sample_count <= 100  # ~2 seconds at 20ms frames

    def test_calibration_stores_duration(self, vad_service: VADService):
        """Test that calibration stores the calibration duration."""
        frames = self.generate_silent_audio(2000)

        result = vad_service.calibrate(frames)

        # Duration should be approximately 2000ms
        assert 1500 <= result.calibration_duration_ms <= 2500

    def test_calibration_handles_empty_frames(self, vad_service: VADService):
        """Test that calibration handles empty frame list."""
        result = vad_service.calibrate([])

        # Should return default values
        assert result.noise_floor_db == -40  # Default
        assert result.sample_count == 0

    def test_calibration_result_is_used_for_vad(self, vad_service: VADService):
        """Test that calibration result affects VAD decisions."""
        # Calibrate with quiet environment
        quiet_frames = self.generate_silent_audio(2000, noise_db=-50)
        result = vad_service.calibrate(quiet_frames)

        # Reset VAD state
        vad_service.reset()

        # Loud speech should be detected as speech
        speech_frames = self.generate_speech_audio(100, speech_db=-25)
        speech_detected = False
        for frame in speech_frames:
            event = vad_service.process_frame(frame)
            if event and event["type"] == "speech_started":
                speech_detected = True
                break

        assert speech_detected, "Speech should be detected after calibration"

    def test_calibration_adapts_to_environment(self, vad_service: VADService):
        """Test that calibration adapts VAD threshold to environment."""
        # First calibration: quiet environment
        quiet_frames = self.generate_silent_audio(2000, noise_db=-55)
        result1 = vad_service.calibrate(quiet_frames)

        # Reset and recalibrate with noisier environment
        vad_service.reset()
        noisy_frames = self.generate_silent_audio(2000, noise_db=-35)
        result2 = vad_service.calibrate(noisy_frames)

        # Noisy environment should have higher noise floor
        assert result2.noise_floor_db > result1.noise_floor_db

    def test_calibration_with_speech_contamination(self, vad_service: VADService):
        """Test calibration when speech accidentally occurs during calibration."""
        # Mix of silence and speech (speech contamination)
        silence = self.generate_silent_audio(1500, noise_db=-50)
        speech = self.generate_speech_audio(500, speech_db=-20)
        frames = silence + speech

        result = vad_service.calibrate(frames)

        # Should still get reasonable noise floor
        # The 90th percentile helps filter out speech spikes
        assert result.noise_floor_db < -20

    def test_calibration_result_dataclass(self):
        """Test CalibrationResult dataclass properties."""
        result = CalibrationResult(
            noise_floor_db=-45.5,
            percentile_90=-42.3,
            sample_count=100,
            calibration_duration_ms=2000,
        )

        assert result.noise_floor_db == -45.5
        assert result.percentile_90 == -42.3
        assert result.sample_count == 100
        assert result.calibration_duration_ms == 2000

    def test_multiple_calibrations(self, vad_service: VADService):
        """Test multiple consecutive calibrations."""
        for i in range(3):
            noise_db = -50 + (i * 10)  # -50, -40, -30
            frames = self.generate_silent_audio(2000, noise_db=noise_db)
            result = vad_service.calibrate(frames)

            # Each calibration should reflect the new noise level
            assert -60 <= result.noise_floor_db <= -20

    def test_calibration_with_variable_noise(self, vad_service: VADService):
        """Test calibration with varying noise levels."""
        frames = []

        # Simulate varying background noise (e.g., AC cycling)
        for i in range(100):
            noise_db = -45 + 5 * math.sin(i / 10)  # Oscillates between -50 and -40
            frame = self.generate_silent_audio(20, noise_db=noise_db)[0]
            frames.append(frame)

        result = vad_service.calibrate(frames)

        # Should find an average noise level
        assert -55 <= result.noise_floor_db <= -35
