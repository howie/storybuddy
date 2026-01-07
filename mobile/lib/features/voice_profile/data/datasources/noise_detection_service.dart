import 'dart:async';

import 'package:record/record.dart';

/// Result of noise level detection.
enum NoiseLevel {
  /// Quiet environment, ideal for recording.
  quiet,

  /// Moderate noise, recording may be acceptable.
  moderate,

  /// Loud environment, not recommended for recording.
  loud,

  /// Very loud environment, recording will likely fail.
  veryLoud,
}

/// Service for detecting background noise levels.
///
/// This service samples the ambient noise level before recording
/// to warn users if the environment is too noisy for quality voice recording.
class NoiseDetectionService {
  NoiseDetectionService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Threshold in dB for quiet environment.
  static const double quietThreshold = -50.0;

  /// Threshold in dB for moderate noise.
  static const double moderateThreshold = -35.0;

  /// Threshold in dB for loud environment.
  static const double loudThreshold = -20.0;

  /// Number of samples to take for noise detection.
  static const int sampleCount = 10;

  /// Interval between samples.
  static const Duration sampleInterval = Duration(milliseconds: 100);

  /// Checks the current ambient noise level.
  ///
  /// Takes multiple amplitude samples and returns the average noise level.
  /// Requires microphone permission to be granted.
  Future<NoiseDetectionResult> checkNoiseLevel() async {
    // Check permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return const NoiseDetectionResult(
        level: NoiseLevel.moderate,
        averageDb: -40.0,
        peakDb: -40.0,
        isReliable: false,
        message: '需要麥克風權限才能檢測噪音',
      );
    }

    try {
      // Start a brief recording to sample ambient noise
      final path = await _getTemporaryPath();
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      await _recorder.start(config, path: path);

      // Collect amplitude samples
      final samples = <double>[];
      for (var i = 0; i < sampleCount; i++) {
        await Future.delayed(sampleInterval);
        final amplitude = await _recorder.getAmplitude();
        samples.add(amplitude.current);
      }

      // Stop and clean up
      await _recorder.stop();

      // Calculate statistics
      final averageDb = _calculateAverage(samples);
      final peakDb = _calculatePeak(samples);
      final level = _classifyNoiseLevel(averageDb);
      final message = _getNoiseMessage(level);

      return NoiseDetectionResult(
        level: level,
        averageDb: averageDb,
        peakDb: peakDb,
        isReliable: true,
        message: message,
      );
    } catch (e) {
      // Return moderate level if detection fails
      return NoiseDetectionResult(
        level: NoiseLevel.moderate,
        averageDb: -40.0,
        peakDb: -40.0,
        isReliable: false,
        message: '無法檢測噪音等級: $e',
      );
    }
  }

  /// Monitors noise level continuously.
  ///
  /// Returns a stream of noise level updates.
  Stream<NoiseDetectionResult> monitorNoiseLevel() async* {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      yield const NoiseDetectionResult(
        level: NoiseLevel.moderate,
        averageDb: -40.0,
        peakDb: -40.0,
        isReliable: false,
        message: '需要麥克風權限才能監測噪音',
      );
      return;
    }

    try {
      final path = await _getTemporaryPath();
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      await _recorder.start(config, path: path);

      // Keep a sliding window of samples
      final samples = <double>[];
      const windowSize = 10;

      while (await _recorder.isRecording()) {
        await Future.delayed(sampleInterval);

        final amplitude = await _recorder.getAmplitude();
        samples.add(amplitude.current);

        // Keep only the last windowSize samples
        if (samples.length > windowSize) {
          samples.removeAt(0);
        }

        if (samples.length >= windowSize) {
          final averageDb = _calculateAverage(samples);
          final peakDb = _calculatePeak(samples);
          final level = _classifyNoiseLevel(averageDb);
          final message = _getNoiseMessage(level);

          yield NoiseDetectionResult(
            level: level,
            averageDb: averageDb,
            peakDb: peakDb,
            isReliable: true,
            message: message,
          );
        }
      }
    } catch (e) {
      yield NoiseDetectionResult(
        level: NoiseLevel.moderate,
        averageDb: -40.0,
        peakDb: -40.0,
        isReliable: false,
        message: '監測中斷: $e',
      );
    }
  }

  /// Stops noise monitoring.
  Future<void> stopMonitoring() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    await _recorder.dispose();
  }

  String _getTemporaryPath() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '/tmp/noise_check_$timestamp.m4a';
  }

  double _calculateAverage(List<double> samples) {
    if (samples.isEmpty) return -60.0;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  double _calculatePeak(List<double> samples) {
    if (samples.isEmpty) return -60.0;
    return samples.reduce((a, b) => a > b ? a : b);
  }

  NoiseLevel _classifyNoiseLevel(double averageDb) {
    if (averageDb <= quietThreshold) {
      return NoiseLevel.quiet;
    } else if (averageDb <= moderateThreshold) {
      return NoiseLevel.moderate;
    } else if (averageDb <= loudThreshold) {
      return NoiseLevel.loud;
    } else {
      return NoiseLevel.veryLoud;
    }
  }

  String _getNoiseMessage(NoiseLevel level) {
    switch (level) {
      case NoiseLevel.quiet:
        return '環境安靜，適合錄音';
      case NoiseLevel.moderate:
        return '環境音量適中，可以錄音';
      case NoiseLevel.loud:
        return '環境較吵雜，建議找更安靜的地方';
      case NoiseLevel.veryLoud:
        return '環境非常吵雜，不建議錄音';
    }
  }
}

/// Result of noise level detection.
class NoiseDetectionResult {
  const NoiseDetectionResult({
    required this.level,
    required this.averageDb,
    required this.peakDb,
    required this.isReliable,
    required this.message,
  });

  /// The classified noise level.
  final NoiseLevel level;

  /// Average noise level in dB.
  final double averageDb;

  /// Peak noise level in dB.
  final double peakDb;

  /// Whether the detection result is reliable.
  final bool isReliable;

  /// Human-readable message about the noise level.
  final String message;

  /// Returns true if the environment is suitable for recording.
  bool get isSuitableForRecording =>
      level == NoiseLevel.quiet || level == NoiseLevel.moderate;

  /// Returns true if a warning should be shown to the user.
  bool get shouldShowWarning =>
      level == NoiseLevel.loud || level == NoiseLevel.veryLoud;
}
