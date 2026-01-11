import 'dart:async';
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:record/record.dart';

import 'package:storybuddy/core/audio/vad_service.dart';

/// Audio streamer for real-time voice capture and Opus encoding.
///
/// T036 [P] [US1] Implement audio streamer with Opus encoding.
/// T093 [US5] Integrate VAD with audio streamer.
/// Captures audio from the microphone, encodes it to Opus format,
/// and provides a stream of encoded audio frames.
class AudioStreamer {
  AudioStreamer({
    this.sampleRate = 16000,
    this.channels = 1,
    this.frameDurationMs = 20,
    this.bitrate = 32000,
    this.enableVAD = true,
    this.skipSilentFrames = true,
    VADService? vadService,
  }) : _vadService = vadService;

  /// Sample rate in Hz (16000 for speech recognition).
  final int sampleRate;

  /// Number of audio channels (1 for mono).
  final int channels;

  /// Frame duration in milliseconds (20ms for optimal latency).
  final int frameDurationMs;

  /// Target bitrate in bits per second.
  final int bitrate;

  /// Whether to enable Voice Activity Detection.
  final bool enableVAD;

  /// Whether to skip silent frames (reduces bandwidth).
  final bool skipSilentFrames;

  AudioRecorder? _recorder;
  SimpleOpusEncoder? _encoder;
  StreamSubscription<Uint8List>? _recordSubscription;
  VADService? _vadService;

  final _audioStreamController = StreamController<Uint8List>.broadcast();
  final _rawAudioController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<AudioStreamerState>.broadcast();
  final _vadEventController = StreamController<VADEvent>.broadcast();

  bool _isRecording = false;
  bool _isPaused = false;

  /// Stream of encoded Opus audio frames.
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// Stream of raw PCM audio frames (for VAD and calibration).
  Stream<Uint8List> get rawAudioStream => _rawAudioController.stream;

  /// Stream of streamer state changes.
  Stream<AudioStreamerState> get stateStream => _stateController.stream;

  /// Stream of VAD events (speech started/ended).
  Stream<VADEvent> get vadEventStream => _vadEventController.stream;

  /// Whether currently recording.
  bool get isRecording => _isRecording;

  /// Whether recording is paused.
  bool get isPaused => _isPaused;

  /// Whether speech is currently detected.
  bool get isSpeaking => _vadService?.isSpeaking ?? false;

  /// Number of samples per frame.
  int get samplesPerFrame => (sampleRate * frameDurationMs) ~/ 1000;

  /// Get the VAD service for direct access.
  VADService? get vadService => _vadService;

  /// Initialize the audio streamer.
  Future<void> initialize() async {
    // Initialize Opus library - load dynamic library and initialize opus_dart
    // ignore: argument_type_not_assignable
    initOpus(await opus_flutter.load());

    // Create Opus encoder
    _encoder = SimpleOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: Application.voip, // Optimized for speech
    );

    // Create recorder
    _recorder = AudioRecorder();

    // T093 [US5] Create VAD service if enabled
    if (enableVAD) {
      _vadService ??= VADService(
        config: VADConfig(
          sampleRate: sampleRate,
          frameDurationMs: frameDurationMs,
        ),
      );
    }

    _stateController.add(AudioStreamerState.initialized);
  }

  /// Calibrate VAD with the given noise floor.
  void calibrateVAD(double noiseFloorDb) {
    _vadService?.calibrate(noiseFloorDb);
  }

  /// Reset VAD state.
  void resetVAD() {
    _vadService?.reset();
  }

  /// Start recording and streaming audio.
  Future<void> startRecording() async {
    if (_isRecording) return;

    if (_recorder == null || _encoder == null) {
      throw StateError(
          'AudioStreamer not initialized. Call initialize() first.',);
    }

    // Check microphone permission
    if (!await _recorder!.hasPermission()) {
      throw AudioStreamerException('Microphone permission not granted');
    }

    // Start recording with PCM output
    final stream = await _recorder!.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
        bitRate: bitrate,
      ),
    );

    _isRecording = true;
    _isPaused = false;
    _stateController.add(AudioStreamerState.recording);

    // Process audio stream
    _recordSubscription = stream.listen(
      _processAudioData,
      onError: (Object error) {
        _stateController.addError(error);
      },
      onDone: () {
        if (_isRecording) {
          stopRecording();
        }
      },
    );
  }

  /// Pause recording.
  void pauseRecording() {
    if (!_isRecording || _isPaused) return;

    _isPaused = true;
    _recorder?.pause();
    _stateController.add(AudioStreamerState.paused);
  }

  /// Resume recording.
  void resumeRecording() {
    if (!_isRecording || !_isPaused) return;

    _isPaused = false;
    _recorder?.resume();
    _stateController.add(AudioStreamerState.recording);
  }

  /// Stop recording.
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _isPaused = false;

    await _recordSubscription?.cancel();
    _recordSubscription = null;

    await _recorder?.stop();
    _stateController.add(AudioStreamerState.stopped);
  }

  // Buffer for accumulating PCM samples until we have a complete frame
  final List<int> _sampleBuffer = [];

  void _processAudioData(Uint8List pcmData) {
    if (_isPaused) return;

    // Convert bytes to 16-bit signed samples
    final samples = _bytesToSamples(pcmData);
    _sampleBuffer.addAll(samples);

    // Process complete frames
    while (_sampleBuffer.length >= samplesPerFrame) {
      final frame = Int16List.fromList(
        _sampleBuffer.sublist(0, samplesPerFrame),
      );
      _sampleBuffer.removeRange(0, samplesPerFrame);

      // Convert frame to bytes for raw stream and VAD
      final frameBytes = Uint8List.view(frame.buffer);

      // Emit raw audio for calibration and external use
      _rawAudioController.add(frameBytes);

      // T093 [US5] Process through VAD if enabled
      var shouldSendFrame = true;
      if (enableVAD && _vadService != null) {
        final vadEvent = _vadService!.processFrame(frameBytes);

        // Emit VAD events
        if (vadEvent != null) {
          _vadEventController.add(vadEvent);
        }

        // Skip silent frames if configured
        if (skipSilentFrames && !_vadService!.isSpeaking) {
          shouldSendFrame = false;
        }
      }

      // Encode and emit frame if speech detected (or VAD disabled)
      if (shouldSendFrame) {
        try {
          final encoded = _encoder!.encode(input: frame);
          if (encoded.isNotEmpty) {
            _audioStreamController.add(Uint8List.fromList(encoded));
          }
        } catch (e) {
          // Encoding error, skip frame
        }
      }
    }
  }

  List<int> _bytesToSamples(Uint8List bytes) {
    final samples = <int>[];
    for (var i = 0; i < bytes.length - 1; i += 2) {
      // Little-endian 16-bit signed
      final sample = bytes[i] | (bytes[i + 1] << 8);
      // Convert to signed
      samples.add(sample < 32768 ? sample : sample - 65536);
    }
    return samples;
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await stopRecording();
    _encoder?.destroy();
    _encoder = null;
    _recorder?.dispose();
    _recorder = null;
    _vadService?.dispose();
    _vadService = null;
    _sampleBuffer.clear();
    await _audioStreamController.close();
    await _rawAudioController.close();
    await _stateController.close();
    await _vadEventController.close();
  }
}

/// Audio streamer states.
enum AudioStreamerState {
  /// Streamer is not initialized.
  uninitialized,

  /// Streamer is initialized and ready to record.
  initialized,

  /// Currently recording audio.
  recording,

  /// Recording is paused.
  paused,

  /// Recording has stopped.
  stopped,
}

/// Exception thrown by AudioStreamer.
class AudioStreamerException implements Exception {
  AudioStreamerException(this.message);

  final String message;

  @override
  String toString() => 'AudioStreamerException: $message';
}
