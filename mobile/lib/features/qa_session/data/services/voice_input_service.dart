import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/network/api_client.dart';
import '../models/qa_message_model.dart';

/// Service for voice input recording and transcription.
/// Records audio and sends to backend /qa/transcribe endpoint.
class VoiceInputService {
  VoiceInputService({required this.apiClient});

  final ApiClient apiClient;
  final AudioRecorder _recorder = AudioRecorder();

  /// Stream controller for amplitude updates.
  StreamController<double>? _amplitudeController;

  /// Timer for polling amplitude.
  Timer? _amplitudeTimer;

  /// Path of the current recording file.
  String? _currentRecordingPath;

  /// Start time of the current recording.
  DateTime? _recordingStartTime;

  /// Maximum recording duration in seconds.
  static const int maxRecordingSeconds = 30;

  /// Returns true if currently recording.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Returns the amplitude stream for visualization.
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  /// Returns the elapsed recording duration.
  Duration get elapsedDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Checks if microphone permission is granted.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Starts recording a voice question.
  Future<String> startRecording() async {
    // Check permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw VoiceInputPermissionDeniedException();
    }

    // Generate file path
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/qa_question_$timestamp.m4a';

    // Configure recording
    const config = RecordConfig(
      numChannels: 1,
    );

    // Start recording
    await _recorder.start(config, path: _currentRecordingPath!);
    _recordingStartTime = DateTime.now();

    // Start amplitude stream
    _startAmplitudeStream();

    // Auto-stop after max duration
    Future.delayed(const Duration(seconds: maxRecordingSeconds), () async {
      if (await _recorder.isRecording()) {
        await stopRecording();
      }
    });

    return _currentRecordingPath!;
  }

  /// Stops recording and returns the file path.
  Future<VoiceInputResult> stopRecording() async {
    // Stop amplitude stream
    _stopAmplitudeStream();

    // Stop recording
    final path = await _recorder.stop();

    if (path == null || _currentRecordingPath == null) {
      throw VoiceInputRecordingFailedException('錄音失敗');
    }

    // Calculate duration
    final duration = elapsedDuration;
    _recordingStartTime = null;

    // Verify file exists
    final file = File(_currentRecordingPath!);
    if (!await file.exists()) {
      throw VoiceInputRecordingFailedException('錄音檔案不存在');
    }

    final fileSize = await file.length();
    final recordingPath = _currentRecordingPath!;
    _currentRecordingPath = null;

    return VoiceInputResult(
      path: recordingPath,
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

  /// Transcribes audio file using backend API.
  Future<TranscriptionResponse> transcribe(String audioFilePath) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw VoiceInputTranscriptionException('找不到音訊檔案');
    }

    try {
      final fileName = audioFilePath.split('/').last;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await apiClient.post<Map<String, dynamic>>(
        '/qa/transcribe',
        data: formData,
      );

      if (response.data == null) {
        throw VoiceInputTranscriptionException('語音辨識回應為空');
      }
      return TranscriptionResponse.fromJson(response.data!);
    } catch (e) {
      if (e is VoiceInputTranscriptionException) rethrow;
      throw VoiceInputTranscriptionException('語音辨識失敗：$e');
    }
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
    const minDb = -60.0;
    const maxDb = 0.0;

    if (dB < minDb) return 0;
    if (dB > maxDb) return 1;

    return (dB - minDb) / (maxDb - minDb);
  }
}

/// Result of a voice input recording.
class VoiceInputResult {
  VoiceInputResult({
    required this.path,
    required this.durationSeconds,
    required this.fileSizeBytes,
  });

  final String path;
  final int durationSeconds;
  final int fileSizeBytes;
}

/// Exception thrown when microphone permission is denied.
class VoiceInputPermissionDeniedException implements Exception {
  @override
  String toString() => '請允許麥克風權限以使用語音輸入';
}

/// Exception thrown when recording fails.
class VoiceInputRecordingFailedException implements Exception {
  VoiceInputRecordingFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exception thrown when transcription fails.
class VoiceInputTranscriptionException implements Exception {
  VoiceInputTranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
