import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service for audio recording with waveform visualization support.
class AudioRecordingService {
  AudioRecordingService();

  final AudioRecorder _recorder = AudioRecorder();

  /// Stream controller for amplitude updates.
  StreamController<double>? _amplitudeController;

  /// Timer for polling amplitude.
  Timer? _amplitudeTimer;

  /// Path of the current recording file.
  String? _currentRecordingPath;

  /// Start time of the current recording.
  DateTime? _recordingStartTime;

  /// Returns true if currently recording.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Returns the amplitude stream for waveform visualization.
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  /// Returns the current recording path.
  String? get currentRecordingPath => _currentRecordingPath;

  /// Returns the elapsed recording duration.
  Duration get elapsedDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Checks if microphone permission is granted.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Requests microphone permission.
  Future<bool> requestPermission() async {
    return _recorder.hasPermission();
  }

  /// Starts recording audio.
  ///
  /// Returns the path where the recording will be saved.
  Future<String> startRecording() async {
    // Check permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionDeniedException();
    }

    // Generate file path
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/voice_sample_$timestamp.m4a';

    // Configure recording
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 128000,
      numChannels: 1,
    );

    // Start recording
    await _recorder.start(config, path: _currentRecordingPath!);
    _recordingStartTime = DateTime.now();

    // Start amplitude stream
    _startAmplitudeStream();

    return _currentRecordingPath!;
  }

  /// Stops recording and returns the recording info.
  Future<RecordingResult> stopRecording() async {
    // Stop amplitude stream
    _stopAmplitudeStream();

    // Stop recording
    final path = await _recorder.stop();

    if (path == null || _currentRecordingPath == null) {
      throw RecordingFailedException('錄音失敗');
    }

    // Calculate duration
    final duration = elapsedDuration;
    _recordingStartTime = null;

    // Verify file exists
    final file = File(_currentRecordingPath!);
    if (!await file.exists()) {
      throw RecordingFailedException('錄音檔案不存在');
    }

    final fileSize = await file.length();

    return RecordingResult(
      path: _currentRecordingPath!,
      durationSeconds: duration.inSeconds,
      fileSizeBytes: fileSize,
    );
  }

  /// Cancels the current recording.
  Future<void> cancelRecording() async {
    _stopAmplitudeStream();

    await _recorder.cancel();

    // Delete the file if it exists
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _currentRecordingPath = null;
    _recordingStartTime = null;
  }

  /// Pauses the recording.
  Future<void> pauseRecording() async {
    await _recorder.pause();
    _amplitudeTimer?.cancel();
  }

  /// Resumes the recording.
  Future<void> resumeRecording() async {
    await _recorder.resume();
    _startAmplitudePolling();
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    _stopAmplitudeStream();
    await _recorder.dispose();
  }

  /// Starts the amplitude stream.
  void _startAmplitudeStream() {
    _amplitudeController = StreamController<double>.broadcast();
    _startAmplitudePolling();
  }

  /// Stops the amplitude stream.
  void _stopAmplitudeStream() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeController?.close();
    _amplitudeController = null;
  }

  /// Starts polling for amplitude values.
  void _startAmplitudePolling() {
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        try {
          final amplitude = await _recorder.getAmplitude();
          // Normalize amplitude from dB to 0.0-1.0 range
          // Typical range is -160 dB to 0 dB
          final normalized = _normalizeAmplitude(amplitude.current);
          _amplitudeController?.add(normalized);
        } catch (_) {
          // Ignore errors
        }
      },
    );
  }

  /// Normalizes amplitude from dB to 0.0-1.0 range.
  double _normalizeAmplitude(double dB) {
    // dB range is typically -160 to 0
    // Map to 0.0-1.0
    const minDb = -60.0;
    const maxDb = 0.0;

    if (dB < minDb) return 0.0;
    if (dB > maxDb) return 1.0;

    return (dB - minDb) / (maxDb - minDb);
  }
}

/// Result of a recording operation.
class RecordingResult {
  RecordingResult({
    required this.path,
    required this.durationSeconds,
    required this.fileSizeBytes,
  });

  final String path;
  final int durationSeconds;
  final int fileSizeBytes;
}

/// Exception thrown when recording permission is denied.
class RecordingPermissionDeniedException implements Exception {
  @override
  String toString() => '請允許麥克風權限以錄製聲音';
}

/// Exception thrown when recording fails.
class RecordingFailedException implements Exception {
  RecordingFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
