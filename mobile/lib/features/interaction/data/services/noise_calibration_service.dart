/// T091 [P] [US5] Noise calibration service.
///
/// Collects ambient audio samples and calculates noise floor
/// for optimal VAD performance.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

/// Result of noise calibration.
class CalibrationResult {
  /// Average noise floor in dB.
  final double noiseFloorDb;

  /// 90th percentile of noise levels.
  final double percentile90;

  /// Number of samples collected.
  final int sampleCount;

  /// Duration of calibration in milliseconds.
  final int calibrationDurationMs;

  /// When calibration was performed.
  final DateTime calibratedAt;

  const CalibrationResult({
    required this.noiseFloorDb,
    required this.percentile90,
    required this.sampleCount,
    required this.calibrationDurationMs,
    required this.calibratedAt,
  });

  /// Whether the noise environment is quiet enough for good detection.
  bool get isQuietEnvironment => noiseFloorDb < -40;

  /// Whether the noise environment is too noisy for reliable detection.
  bool get isNoisyEnvironment => noiseFloorDb > -25;

  Map<String, dynamic> toJson() => {
    'noiseFloorDb': noiseFloorDb,
    'percentile90': percentile90,
    'sampleCount': sampleCount,
    'calibrationDurationMs': calibrationDurationMs,
    'calibratedAt': calibratedAt.toIso8601String(),
  };

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    return CalibrationResult(
      noiseFloorDb: json['noiseFloorDb'] as double,
      percentile90: json['percentile90'] as double,
      sampleCount: json['sampleCount'] as int,
      calibrationDurationMs: json['calibrationDurationMs'] as int,
      calibratedAt: DateTime.parse(json['calibratedAt'] as String),
    );
  }

  @override
  String toString() =>
      'CalibrationResult(noiseFloorDb: ${noiseFloorDb.toStringAsFixed(1)}, '
      'sampleCount: $sampleCount, calibrationDurationMs: $calibrationDurationMs)';
}

/// Configuration for noise calibration.
class CalibrationConfig {
  /// Target duration for calibration in milliseconds.
  final int targetDurationMs;

  /// Minimum number of samples required.
  final int minSamples;

  /// Audio sample rate.
  final int sampleRate;

  /// Frame duration in milliseconds.
  final int frameDurationMs;

  const CalibrationConfig({
    this.targetDurationMs = 2000,
    this.minSamples = 50,
    this.sampleRate = 16000,
    this.frameDurationMs = 20,
  });

  /// Expected number of samples based on target duration.
  int get expectedSamples => targetDurationMs ~/ frameDurationMs;
}

/// Service for performing noise calibration.
class NoiseCalibrationService {
  final CalibrationConfig config;

  final List<double> _energySamples = [];
  final List<Uint8List> _audioFrames = [];
  DateTime? _startTime;
  bool _isCalibrating = false;

  NoiseCalibrationService({
    this.config = const CalibrationConfig(),
  });

  /// Whether calibration is in progress.
  bool get isCalibrating => _isCalibrating;

  /// Current number of collected samples.
  int get sampleCount => _energySamples.length;

  /// Progress of calibration (0.0 to 1.0).
  double get progress {
    if (!_isCalibrating) return 0.0;
    return min(1.0, _energySamples.length / config.expectedSamples);
  }

  /// Start collecting calibration samples.
  void startCalibration() {
    _energySamples.clear();
    _audioFrames.clear();
    _startTime = DateTime.now();
    _isCalibrating = true;
  }

  /// Add an audio frame for calibration.
  ///
  /// Returns true if more samples are needed, false if calibration is complete.
  bool addFrame(Uint8List audioFrame) {
    if (!_isCalibrating) return false;

    final energyDb = _calculateFrameEnergy(audioFrame);
    _energySamples.add(energyDb);
    _audioFrames.add(audioFrame);

    // Check if we have enough samples
    return _energySamples.length < config.expectedSamples;
  }

  /// Complete calibration and return results.
  ///
  /// Throws [StateError] if not enough samples have been collected.
  CalibrationResult completeCalibration() {
    if (!_isCalibrating) {
      throw StateError('Calibration not started');
    }

    if (_energySamples.isEmpty) {
      throw StateError('No samples collected');
    }

    _isCalibrating = false;

    // Calculate statistics
    final sortedSamples = List<double>.from(_energySamples)..sort();
    final noiseFloorDb = _calculateMean(sortedSamples);
    final percentile90Idx = (sortedSamples.length * 0.9).floor();
    final percentile90 = percentile90Idx < sortedSamples.length
        ? sortedSamples[percentile90Idx]
        : sortedSamples.last;

    final endTime = DateTime.now();
    final calibrationDurationMs = _startTime != null
        ? endTime.difference(_startTime!).inMilliseconds
        : _energySamples.length * config.frameDurationMs;

    return CalibrationResult(
      noiseFloorDb: noiseFloorDb,
      percentile90: percentile90,
      sampleCount: _energySamples.length,
      calibrationDurationMs: calibrationDurationMs,
      calibratedAt: endTime,
    );
  }

  /// Cancel the current calibration.
  void cancelCalibration() {
    _isCalibrating = false;
    _energySamples.clear();
    _audioFrames.clear();
    _startTime = null;
  }

  /// Get collected audio frames (for sending to server).
  List<Uint8List> get audioFrames => List.unmodifiable(_audioFrames);

  /// Calculate mean of values.
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return -40.0; // Default
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate energy of an audio frame in dB.
  double _calculateFrameEnergy(Uint8List frame) {
    final samples = Int16List.view(frame.buffer, frame.offsetInBytes,
        frame.lengthInBytes ~/ 2);

    if (samples.isEmpty) return -100.0;

    // Calculate RMS
    double sumSquares = 0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / samples.length);

    // Convert to dB
    if (rms < 1) return -100.0;
    return 20 * log(rms / 32768) / ln10;
  }

  /// Reset the service.
  void reset() {
    cancelCalibration();
  }

  /// Dispose of resources.
  void dispose() {
    reset();
  }
}
