"""Voice Activity Detection (VAD) Service.

T029 [US1] Implement VAD service using webrtcvad.
Provides real-time voice activity detection for interactive story mode.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List, Dict, Any, Callable
import struct
import math
import threading
from datetime import datetime

import webrtcvad


class VADEvent(str, Enum):
    """Types of VAD events."""

    SPEECH_STARTED = "speech_started"
    SPEECH_ENDED = "speech_ended"


@dataclass
class VADConfig:
    """Configuration for Voice Activity Detection.

    Attributes:
        sample_rate: Audio sample rate (8000, 16000, 32000, or 48000 Hz).
        frame_duration_ms: Frame duration (10, 20, or 30 ms).
        aggressiveness: VAD aggressiveness (0-3, higher = more aggressive filtering).
        speech_threshold: Fraction of frames that must be speech to trigger detection.
        min_speech_frames: Minimum consecutive speech frames to confirm speech start.
        min_silence_frames: Minimum consecutive silence frames to confirm speech end.
    """

    sample_rate: int = 16000
    frame_duration_ms: int = 20
    aggressiveness: int = 2
    speech_threshold: float = 0.5
    min_speech_frames: int = 3  # ~60ms of speech to start
    min_silence_frames: int = 75  # ~1.5 seconds of silence to end (FR spec)

    def __post_init__(self):
        """Validate configuration values."""
        valid_sample_rates = [8000, 16000, 32000, 48000]
        if self.sample_rate not in valid_sample_rates:
            raise ValueError(
                f"sample_rate must be one of {valid_sample_rates}, got {self.sample_rate}"
            )

        valid_frame_durations = [10, 20, 30]
        if self.frame_duration_ms not in valid_frame_durations:
            raise ValueError(
                f"frame_duration must be one of {valid_frame_durations}, got {self.frame_duration_ms}"
            )

        if not 0 <= self.aggressiveness <= 3:
            raise ValueError(
                f"aggressiveness must be 0-3, got {self.aggressiveness}"
            )

        if not 0.0 <= self.speech_threshold <= 1.0:
            raise ValueError(
                f"speech_threshold must be 0.0-1.0, got {self.speech_threshold}"
            )

    @property
    def frame_size_samples(self) -> int:
        """Number of samples per frame."""
        return int(self.sample_rate * self.frame_duration_ms / 1000)

    @property
    def frame_size_bytes(self) -> int:
        """Number of bytes per frame (16-bit audio)."""
        return self.frame_size_samples * 2


@dataclass
class CalibrationResult:
    """Result of noise calibration."""

    noise_floor_db: float
    percentile_90: float
    sample_count: int
    calibration_duration_ms: int
    calibrated_at: datetime = field(default_factory=datetime.utcnow)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "noise_floor_db": self.noise_floor_db,
            "percentile_90": self.percentile_90,
            "sample_count": self.sample_count,
            "calibration_duration_ms": self.calibration_duration_ms,
            "calibrated_at": self.calibrated_at.isoformat(),
        }


class VADService:
    """Voice Activity Detection service using webrtcvad.

    Provides methods to:
    - Detect speech vs silence in audio frames
    - Process continuous audio streams with state tracking
    - Calibrate noise floor from ambient audio
    - Emit events for speech start/end
    """

    def __init__(self, config: Optional[VADConfig] = None):
        """Initialize VAD service.

        Args:
            config: VAD configuration. Uses defaults if not provided.
        """
        self.config = config or VADConfig()
        self._vad = webrtcvad.Vad(self.config.aggressiveness)

        # State tracking
        self._is_speaking: bool = False
        self._speech_frames: int = 0
        self._silence_frames: int = 0
        self._total_frames: int = 0

        # Calibration data
        self._calibration_samples: List[float] = []
        self._noise_floor_db: Optional[float] = None

        # Thread safety
        self._lock = threading.Lock()

    def is_speech(self, audio_frame: bytes) -> bool:
        """Detect if an audio frame contains speech.

        Args:
            audio_frame: Raw audio bytes (16-bit PCM).

        Returns:
            True if the frame likely contains speech.

        Raises:
            ValueError: If frame size is invalid.
        """
        expected_size = self.config.frame_size_bytes
        if len(audio_frame) != expected_size:
            raise ValueError(
                f"Invalid frame size: expected {expected_size} bytes, got {len(audio_frame)}"
            )

        return self._vad.is_speech(audio_frame, self.config.sample_rate)

    def process_frame(self, audio_frame: bytes) -> Optional[Dict[str, Any]]:
        """Process an audio frame and detect speech events.

        Maintains internal state to detect speech start/end transitions.

        Args:
            audio_frame: Raw audio bytes (16-bit PCM, 20ms frame).

        Returns:
            Event dict if a speech_started or speech_ended event occurred,
            None otherwise.
        """
        with self._lock:
            is_speech = self.is_speech(audio_frame)
            self._total_frames += 1
            event = None

            if is_speech:
                self._speech_frames += 1
                self._silence_frames = 0

                # Check for speech start
                if not self._is_speaking:
                    if self._speech_frames >= self.config.min_speech_frames:
                        self._is_speaking = True
                        event = {
                            "type": VADEvent.SPEECH_STARTED.value,
                            "timestamp": datetime.utcnow().isoformat() + "Z",
                        }
            else:
                self._silence_frames += 1

                # Check for speech end
                if self._is_speaking:
                    if self._silence_frames >= self.config.min_silence_frames:
                        self._is_speaking = False
                        duration_frames = self._speech_frames
                        duration_ms = duration_frames * self.config.frame_duration_ms
                        event = {
                            "type": VADEvent.SPEECH_ENDED.value,
                            "timestamp": datetime.utcnow().isoformat() + "Z",
                            "durationMs": duration_ms,
                        }
                        self._speech_frames = 0

            return event

    def reset(self) -> None:
        """Reset internal state for a new session."""
        with self._lock:
            self._is_speaking = False
            self._speech_frames = 0
            self._silence_frames = 0
            self._total_frames = 0

    def calibrate(self, noise_frames: List[bytes]) -> CalibrationResult:
        """Calibrate noise floor from ambient audio samples.

        Analyzes the provided audio frames to determine the ambient noise level.
        This is used to improve speech detection accuracy (FR-018).

        Args:
            noise_frames: List of audio frames containing ambient noise.

        Returns:
            CalibrationResult with noise statistics.
        """
        if not noise_frames:
            raise ValueError("No frames provided for calibration")

        # Calculate RMS energy for each frame
        energies_db = []
        for frame in noise_frames:
            energy_db = self._calculate_frame_energy_db(frame)
            energies_db.append(energy_db)

        # Calculate statistics
        energies_db.sort()
        noise_floor_db = sum(energies_db) / len(energies_db)
        percentile_90_idx = int(len(energies_db) * 0.9)
        percentile_90 = energies_db[percentile_90_idx] if percentile_90_idx < len(energies_db) else energies_db[-1]

        calibration_duration_ms = len(noise_frames) * self.config.frame_duration_ms

        self._noise_floor_db = noise_floor_db

        return CalibrationResult(
            noise_floor_db=noise_floor_db,
            percentile_90=percentile_90,
            sample_count=len(noise_frames),
            calibration_duration_ms=calibration_duration_ms,
        )

    def _calculate_frame_energy_db(self, frame: bytes) -> float:
        """Calculate energy of an audio frame in decibels.

        Args:
            frame: Audio frame bytes.

        Returns:
            Energy in dB (negative values, with -inf for silence).
        """
        # Unpack 16-bit signed samples
        num_samples = len(frame) // 2
        samples = struct.unpack('<' + 'h' * num_samples, frame)

        # Calculate RMS
        sum_squares = sum(s * s for s in samples)
        rms = math.sqrt(sum_squares / num_samples) if num_samples > 0 else 0

        # Convert to dB (avoid log(0))
        if rms < 1:
            return -100.0  # Practical minimum
        return 20 * math.log10(rms / 32768.0)  # Normalize to 16-bit range

    @property
    def is_speaking(self) -> bool:
        """Whether speech is currently detected."""
        return self._is_speaking

    @property
    def noise_floor_db(self) -> Optional[float]:
        """Calibrated noise floor in dB, or None if not calibrated."""
        return self._noise_floor_db

    def set_aggressiveness(self, level: int) -> None:
        """Update VAD aggressiveness level.

        Args:
            level: Aggressiveness level (0-3).

        Raises:
            ValueError: If level is out of range.
        """
        if not 0 <= level <= 3:
            raise ValueError(f"aggressiveness must be 0-3, got {level}")
        self._vad.set_mode(level)
        self.config.aggressiveness = level
