"""
T087 [P] [US5] Integration test for VAD accuracy.

Tests VAD accuracy with realistic audio scenarios.
"""

import numpy as np
import pytest

from src.services.interaction.vad_service import VADConfig, VADService


class TestVADAccuracy:
    """Integration tests for VAD accuracy measurement."""

    @pytest.fixture
    def vad_service(self) -> VADService:
        """Create a VAD service with production-like settings."""
        config = VADConfig(
            sample_rate=16000,
            frame_duration_ms=20,
            speech_threshold_db=-35,
            silence_threshold_db=-50,
            min_speech_duration_ms=100,
            min_silence_duration_ms=300,
        )
        return VADService(config)

    def generate_audio_scenario(
        self,
        scenario: list[tuple[str, int, float]],
    ) -> tuple[list[bytes], list[tuple[int, int]]]:
        """Generate audio frames for a test scenario.

        Args:
            scenario: List of (type, duration_ms, db) tuples.
                     type: "silence", "speech", "noise"

        Returns:
            Tuple of (frames, expected_speech_regions).
            expected_speech_regions: List of (start_ms, end_ms) for speech.
        """
        frames = []
        speech_regions = []
        current_ms = 0

        for seg_type, duration_ms, db in scenario:
            num_frames = duration_ms // 20

            if seg_type == "speech":
                speech_regions.append((current_ms, current_ms + duration_ms))

            for _ in range(num_frames):
                frame = self._generate_frame(seg_type, db)
                frames.append(frame)

            current_ms += duration_ms

        return frames, speech_regions

    def _generate_frame(self, seg_type: str, db: float) -> bytes:
        """Generate a single audio frame.

        Args:
            seg_type: "silence", "speech", or "noise"
            db: dB level

        Returns:
            Audio frame bytes.
        """
        samples_per_frame = 320  # 20ms at 16kHz
        amplitude = 10 ** (db / 20) * 32767

        if seg_type == "silence":
            # Low-level random noise
            samples = np.random.normal(0, amplitude * 0.1, samples_per_frame)
        elif seg_type == "speech":
            # Speech-like signal with harmonics
            t = np.linspace(0, 0.02, samples_per_frame)
            samples = amplitude * (
                0.5 * np.sin(2 * np.pi * 200 * t)
                + 0.3 * np.sin(2 * np.pi * 400 * t)
                + 0.2 * np.sin(2 * np.pi * 800 * t)
                + 0.1 * np.random.normal(0, 1, samples_per_frame)  # Some noise
            )
        else:  # noise
            # Broadband noise
            samples = np.random.normal(0, amplitude, samples_per_frame)

        samples = np.clip(samples, -32767, 32767).astype(np.int16)
        return samples.tobytes()

    def evaluate_vad(
        self,
        vad_service: VADService,
        frames: list[bytes],
        expected_regions: list[tuple[int, int]],
    ) -> dict:
        """Evaluate VAD performance.

        Args:
            vad_service: VAD service instance.
            frames: Audio frames to process.
            expected_regions: Expected speech regions as (start_ms, end_ms).

        Returns:
            Performance metrics dict.
        """
        # First, calibrate with initial silence
        if frames:
            calibration_frames = frames[:50]  # First 1 second
            vad_service.calibrate(calibration_frames)

        # Process frames and collect detected regions
        detected_regions = []
        current_speech_start = None
        current_ms = 0

        for frame in frames:
            event = vad_service.process_frame(frame)

            if event:
                if event["type"] == "speech_started":
                    current_speech_start = current_ms
                elif event["type"] == "speech_ended":
                    if current_speech_start is not None:
                        detected_regions.append((current_speech_start, current_ms))
                        current_speech_start = None

            current_ms += 20

        # If still speaking at end
        if current_speech_start is not None:
            detected_regions.append((current_speech_start, current_ms))

        # Calculate metrics
        metrics = self._calculate_metrics(expected_regions, detected_regions)
        return metrics

    def _calculate_metrics(
        self,
        expected: list[tuple[int, int]],
        detected: list[tuple[int, int]],
    ) -> dict:
        """Calculate VAD performance metrics.

        Args:
            expected: Expected speech regions.
            detected: Detected speech regions.

        Returns:
            Dict with precision, recall, F1 score.
        """
        if not expected:
            if not detected:
                return {"precision": 1.0, "recall": 1.0, "f1": 1.0}
            return {"precision": 0.0, "recall": 1.0, "f1": 0.0}

        if not detected:
            return {"precision": 1.0, "recall": 0.0, "f1": 0.0}

        # Calculate overlap-based metrics
        total_expected_ms = sum(end - start for start, end in expected)
        total_detected_ms = sum(end - start for start, end in detected)

        # Calculate true positive (overlap)
        true_positive_ms = 0
        for exp_start, exp_end in expected:
            for det_start, det_end in detected:
                overlap_start = max(exp_start, det_start)
                overlap_end = min(exp_end, det_end)
                if overlap_end > overlap_start:
                    true_positive_ms += overlap_end - overlap_start

        precision = true_positive_ms / total_detected_ms if total_detected_ms > 0 else 0
        recall = true_positive_ms / total_expected_ms if total_expected_ms > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

        return {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "true_positive_ms": true_positive_ms,
            "total_expected_ms": total_expected_ms,
            "total_detected_ms": total_detected_ms,
        }

    def test_simple_speech_detection(self, vad_service: VADService):
        """Test detection of simple speech pattern: silence -> speech -> silence."""
        scenario = [
            ("silence", 2000, -55),  # 2s calibration/silence
            ("speech", 2000, -25),  # 2s speech
            ("silence", 1000, -55),  # 1s silence
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        assert metrics["recall"] >= 0.7, f"Recall too low: {metrics['recall']}"
        assert metrics["precision"] >= 0.7, f"Precision too low: {metrics['precision']}"

    def test_multiple_speech_segments(self, vad_service: VADService):
        """Test detection of multiple speech segments."""
        scenario = [
            ("silence", 2000, -55),
            ("speech", 1000, -25),
            ("silence", 1000, -55),
            ("speech", 1500, -25),
            ("silence", 1000, -55),
            ("speech", 500, -25),
            ("silence", 500, -55),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        assert metrics["recall"] >= 0.6, f"Recall too low: {metrics['recall']}"

    def test_quiet_speech_detection(self, vad_service: VADService):
        """Test detection of quieter speech."""
        scenario = [
            ("silence", 2000, -55),
            ("speech", 2000, -35),  # Quieter speech
            ("silence", 1000, -55),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # May have lower recall for quiet speech, but should detect something
        assert metrics["recall"] >= 0.5

    def test_noisy_environment(self, vad_service: VADService):
        """Test VAD in noisy environment."""
        scenario = [
            ("noise", 2000, -40),  # Calibrate to noise
            ("speech", 2000, -20),  # Loud speech over noise
            ("noise", 1000, -40),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # Should still detect loud speech over noise
        assert metrics["recall"] >= 0.5

    def test_short_speech_utterances(self, vad_service: VADService):
        """Test detection of short speech utterances (child responses)."""
        scenario = [
            ("silence", 2000, -55),
            ("speech", 300, -25),  # Short utterance 1
            ("silence", 500, -55),
            ("speech", 400, -25),  # Short utterance 2
            ("silence", 500, -55),
            ("speech", 200, -25),  # Very short utterance
            ("silence", 500, -55),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # Short utterances are harder to detect, lower threshold
        assert metrics["recall"] >= 0.3

    def test_continuous_speech(self, vad_service: VADService):
        """Test detection of continuous speech (storytelling)."""
        scenario = [
            ("silence", 2000, -55),
            ("speech", 10000, -25),  # 10 seconds of continuous speech
            ("silence", 1000, -55),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        assert metrics["recall"] >= 0.8, "Should detect most of continuous speech"
        assert metrics["precision"] >= 0.8, "Should not over-detect"

    def test_speech_with_natural_pauses(self, vad_service: VADService):
        """Test speech with natural pauses (doesn't break up speech too much)."""
        scenario = [
            ("silence", 2000, -55),
            ("speech", 1000, -25),
            ("silence", 200, -55),  # Brief pause
            ("speech", 1500, -25),
            ("silence", 150, -55),  # Very brief pause
            ("speech", 800, -25),
            ("silence", 1000, -55),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # Should maintain reasonable detection through natural pauses
        assert metrics["f1"] >= 0.5

    def test_no_false_positives_in_silence(self, vad_service: VADService):
        """Test that VAD doesn't trigger on pure silence."""
        scenario = [
            ("silence", 5000, -60),  # 5 seconds of silence
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # No speech expected, should have high precision (no false positives)
        assert metrics["precision"] == 1.0 or metrics["total_detected_ms"] < 500

    def test_accuracy_threshold(self, vad_service: VADService):
        """Test overall accuracy meets acceptable threshold for children's interaction."""
        # Simulate typical children's interaction pattern
        scenario = [
            ("silence", 2000, -50),
            ("speech", 1500, -25),  # Child speaking
            ("silence", 2000, -50),  # AI responding (child silent)
            ("speech", 800, -28),  # Child response
            ("silence", 1500, -50),
            ("speech", 2000, -25),  # Child longer response
            ("silence", 1000, -50),
        ]

        frames, expected = self.generate_audio_scenario(scenario)
        metrics = self.evaluate_vad(vad_service, frames, expected)

        # Overall F1 should be acceptable for children's interaction
        assert metrics["f1"] >= 0.5, f"F1 score too low: {metrics['f1']}"
