/// T090 [P] [US5] Client-side Voice Activity Detection service.
///
/// Provides real-time voice activity detection for interactive story mode.
/// Detects speech start/end events based on audio energy levels.
import 'dart:math';
import 'dart:typed_data';

/// Configuration for Voice Activity Detection.
class VADConfig {
  /// Audio sample rate (Hz).
  final int sampleRate;

  /// Frame duration in milliseconds.
  final int frameDurationMs;

  /// Threshold for speech detection (dB above noise floor).
  final double speechThresholdDb;

  /// Threshold for silence detection (dB).
  final double silenceThresholdDb;

  /// Minimum speech duration to confirm speech start (ms).
  final int minSpeechDurationMs;

  /// Minimum silence duration to confirm speech end (ms).
  final int minSilenceDurationMs;

  const VADConfig({
    this.sampleRate = 16000,
    this.frameDurationMs = 20,
    this.speechThresholdDb = -35,
    this.silenceThresholdDb = -50,
    this.minSpeechDurationMs = 100,
    this.minSilenceDurationMs = 300,
  }) : assert(frameDurationMs == 10 || frameDurationMs == 20 || frameDurationMs == 30,
           'Frame duration must be 10, 20, or 30 ms');

  /// Number of samples per frame.
  int get samplesPerFrame => (sampleRate * frameDurationMs) ~/ 1000;

  /// Number of bytes per frame (16-bit audio).
  int get bytesPerFrame => samplesPerFrame * 2;
}

/// Types of VAD events.
enum VADEventType {
  /// Speech has started.
  speechStarted,

  /// Speech has ended.
  speechEnded,
}

/// Event emitted by VAD service.
class VADEvent {
  /// Type of event.
  final VADEventType type;

  /// Timestamp of the event.
  final Duration timestamp;

  /// Duration of speech in milliseconds (only for speechEnded).
  final int? durationMs;

  const VADEvent({
    required this.type,
    required this.timestamp,
    this.durationMs,
  });

  @override
  String toString() => 'VADEvent(type: $type, timestamp: $timestamp, durationMs: $durationMs)';
}

/// Voice Activity Detection service.
///
/// Detects speech vs silence in audio frames based on energy levels.
class VADService {
  final VADConfig config;

  // State tracking
  bool _isSpeaking = false;
  int _speechFrames = 0;
  int _silenceFrames = 0;
  int _totalFrames = 0;
  int _speechStartFrame = 0;

  // Calibration
  double? _noiseFloorDb;
  bool _isCalibrated = false;

  VADService({this.config = const VADConfig()});

  /// Whether calibration has been performed.
  bool get isCalibrated => _isCalibrated;

  /// Calibrated noise floor in dB.
  double? get noiseFloorDb => _noiseFloorDb;

  /// Whether speech is currently detected.
  bool get isSpeaking => _isSpeaking;

  /// Calibrate the VAD with the ambient noise level.
  ///
  /// [noiseFloorDb] The measured ambient noise level in dB.
  void calibrate(double noiseFloorDb) {
    _noiseFloorDb = noiseFloorDb;
    _isCalibrated = true;
  }

  /// Process an audio frame and detect speech events.
  ///
  /// Returns a [VADEvent] if a speech state change occurred, null otherwise.
  VADEvent? processFrame(Uint8List audioFrame) {
    if (!_isCalibrated) {
      // Use default threshold if not calibrated
      _noiseFloorDb = config.silenceThresholdDb;
    }

    final energyDb = calculateFrameEnergy(audioFrame);
    _totalFrames++;

    final currentTimestamp = Duration(milliseconds: _totalFrames * config.frameDurationMs);
    final speechThreshold = _noiseFloorDb! + 15; // 15dB above noise floor

    final isSpeech = energyDb > speechThreshold;
    VADEvent? event;

    if (isSpeech) {
      _speechFrames++;
      _silenceFrames = 0;

      // Check for speech start
      if (!_isSpeaking) {
        final minSpeechFrames = config.minSpeechDurationMs ~/ config.frameDurationMs;
        if (_speechFrames >= minSpeechFrames) {
          _isSpeaking = true;
          _speechStartFrame = _totalFrames - _speechFrames;
          event = VADEvent(
            type: VADEventType.speechStarted,
            timestamp: currentTimestamp,
          );
        }
      }
    } else {
      _silenceFrames++;

      // Check for speech end
      if (_isSpeaking) {
        final minSilenceFrames = config.minSilenceDurationMs ~/ config.frameDurationMs;
        if (_silenceFrames >= minSilenceFrames) {
          _isSpeaking = false;
          final durationFrames = _totalFrames - _speechStartFrame - _silenceFrames;
          final durationMs = durationFrames * config.frameDurationMs;
          event = VADEvent(
            type: VADEventType.speechEnded,
            timestamp: currentTimestamp,
            durationMs: durationMs > 0 ? durationMs : config.minSpeechDurationMs,
          );
          _speechFrames = 0;
        }
      }
    }

    return event;
  }

  /// Calculate the energy of an audio frame in dB.
  double calculateFrameEnergy(Uint8List audioFrame) {
    // Interpret bytes as 16-bit signed integers (little-endian)
    final samples = Int16List.view(audioFrame.buffer, audioFrame.offsetInBytes,
        audioFrame.lengthInBytes ~/ 2);

    if (samples.isEmpty) return -100.0;

    // Calculate RMS
    double sumSquares = 0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / samples.length);

    // Convert to dB (normalized to 16-bit range)
    if (rms < 1) return -100.0;
    return 20 * log(rms / 32768) / ln10;
  }

  /// Reset VAD state for a new session.
  void reset() {
    _isSpeaking = false;
    _speechFrames = 0;
    _silenceFrames = 0;
    _totalFrames = 0;
    _speechStartFrame = 0;
  }

  /// Dispose of resources.
  void dispose() {
    reset();
    _noiseFloorDb = null;
    _isCalibrated = false;
  }
}
