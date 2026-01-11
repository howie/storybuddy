/// T086 [P] [US5] Unit test for client-side VAD.
///
/// Tests the client-side Voice Activity Detection service.
library;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:storybuddy/core/audio/vad_service.dart';

void main() {
  group('VADService', () {
    late VADService vadService;

    setUp(() {
      vadService = VADService(
        
      );
    });

    tearDown(() {
      vadService.dispose();
    });

    /// Generate silent audio frame.
    Uint8List generateSilentFrame({double noiseDb = -55}) {
      const samplesPerFrame = 320; // 20ms at 16kHz
      final amplitude = pow(10, noiseDb / 20) * 32767;
      final random = Random();

      final samples = Int16List(samplesPerFrame);
      for (var i = 0; i < samplesPerFrame; i++) {
        samples[i] = (random.nextDouble() * 2 - 1) * amplitude ~/ 1;
      }

      return samples.buffer.asUint8List();
    }

    /// Generate speech-like audio frame.
    Uint8List generateSpeechFrame({double speechDb = -25}) {
      const samplesPerFrame = 320;
      final amplitude = pow(10, speechDb / 20) * 32767;

      final samples = Int16List(samplesPerFrame);
      for (var i = 0; i < samplesPerFrame; i++) {
        // Simulate speech with a simple sine wave
        final t = i / 16000.0;
        samples[i] =
            (sin(2 * pi * 300 * t) * amplitude).toInt().clamp(-32767, 32767);
      }

      return samples.buffer.asUint8List();
    }

    test('initializes with default calibration', () {
      expect(vadService.isCalibrated, isFalse);
      expect(vadService.noiseFloorDb, isNull);
    });

    test('processFrame returns null for silent frames', () {
      vadService.calibrate(-50);

      for (var i = 0; i < 10; i++) {
        final frame = generateSilentFrame();
        final event = vadService.processFrame(frame);

        // Silent frames should not trigger speech events
        if (event != null) {
          expect(event.type, isNot(equals(VADEventType.speechStarted)));
        }
      }
    });

    test('detects speech start', () {
      vadService.calibrate(-50);

      // Send several speech frames
      VADEvent? speechEvent;
      for (var i = 0; i < 10; i++) {
        final frame = generateSpeechFrame();
        final event = vadService.processFrame(frame);
        if (event?.type == VADEventType.speechStarted) {
          speechEvent = event;
          break;
        }
      }

      expect(speechEvent, isNotNull);
      expect(speechEvent!.type, equals(VADEventType.speechStarted));
    });

    test('detects speech end after silence', () {
      vadService.calibrate(-50);

      // Start with speech
      for (var i = 0; i < 10; i++) {
        vadService.processFrame(generateSpeechFrame());
      }

      // Then silence
      VADEvent? silenceEvent;
      for (var i = 0; i < 30; i++) {
        final frame = generateSilentFrame();
        final event = vadService.processFrame(frame);
        if (event?.type == VADEventType.speechEnded) {
          silenceEvent = event;
          break;
        }
      }

      expect(silenceEvent, isNotNull);
      expect(silenceEvent!.type, equals(VADEventType.speechEnded));
      expect(silenceEvent.durationMs, greaterThan(0));
    });

    test('calibrate sets noise floor', () {
      vadService.calibrate(-45);

      expect(vadService.isCalibrated, isTrue);
      expect(vadService.noiseFloorDb, equals(-45));
    });

    test('reset clears state', () {
      vadService.calibrate(-45);

      // Process some frames
      for (var i = 0; i < 5; i++) {
        vadService.processFrame(generateSpeechFrame());
      }

      vadService.reset();

      expect(vadService.isSpeaking, isFalse);
    });

    test('isSpeaking returns correct state', () {
      vadService.calibrate(-50);

      expect(vadService.isSpeaking, isFalse);

      // Process speech until speech is detected
      for (var i = 0; i < 20; i++) {
        final event = vadService.processFrame(generateSpeechFrame());
        if (event?.type == VADEventType.speechStarted) {
          break;
        }
      }

      expect(vadService.isSpeaking, isTrue);
    });

    test('calculates energy correctly', () {
      // Silent frame should have low energy
      final silentFrame = generateSilentFrame();
      final silentEnergy = vadService.calculateFrameEnergy(silentFrame);

      // Speech frame should have higher energy
      final speechFrame = generateSpeechFrame();
      final speechEnergy = vadService.calculateFrameEnergy(speechFrame);

      expect(speechEnergy, greaterThan(silentEnergy));
    });

    test('respects minimum speech duration', () {
      vadService.calibrate(-50);

      // Very short speech burst (less than minSpeechDurationMs)
      final frame = generateSpeechFrame();
      final event = vadService.processFrame(frame);

      // Should not trigger speech started for single frame
      expect(event?.type, isNot(equals(VADEventType.speechStarted)));
    });

    test('respects minimum silence duration', () {
      vadService.calibrate(-50);

      // Start speech
      for (var i = 0; i < 10; i++) {
        vadService.processFrame(generateSpeechFrame());
      }

      // Very short silence (less than minSilenceDurationMs)
      for (var i = 0; i < 5; i++) {
        final event = vadService.processFrame(generateSilentFrame());
        // Should not trigger speech ended yet
        expect(event?.type, isNot(equals(VADEventType.speechEnded)));
      }
    });

    test('handles rapid speech/silence transitions', () {
      vadService.calibrate(-50);

      var speechEvents = 0;
      var endEvents = 0;

      // Rapid transitions
      for (var cycle = 0; cycle < 5; cycle++) {
        // Speech burst
        for (var i = 0; i < 10; i++) {
          final event = vadService.processFrame(generateSpeechFrame());
          if (event?.type == VADEventType.speechStarted) speechEvents++;
        }

        // Silence burst
        for (var i = 0; i < 20; i++) {
          final event = vadService.processFrame(generateSilentFrame());
          if (event?.type == VADEventType.speechEnded) endEvents++;
        }
      }

      // Should handle transitions gracefully
      expect(speechEvents, greaterThan(0));
      expect(endEvents, greaterThan(0));
    });
  });

  group('VADConfig', () {
    test('has sensible defaults', () {
      const config = VADConfig();

      expect(config.sampleRate, equals(16000));
      expect(config.frameDurationMs, equals(20));
      expect(config.speechThresholdDb, lessThan(0));
      expect(config.silenceThresholdDb, lessThan(config.speechThresholdDb));
    });

    test('validates frame duration', () {
      // Valid durations: 10, 20, 30 ms
      expect(() => const VADConfig(frameDurationMs: 10), returnsNormally);
      expect(() => const VADConfig(), returnsNormally);
      expect(() => const VADConfig(frameDurationMs: 30), returnsNormally);
    });
  });

  group('VADEvent', () {
    test('speechStarted event has correct properties', () {
      const event = VADEvent(
        type: VADEventType.speechStarted,
        timestamp: Duration(seconds: 1),
      );

      expect(event.type, equals(VADEventType.speechStarted));
      expect(event.timestamp, equals(const Duration(seconds: 1)));
      expect(event.durationMs, isNull);
    });

    test('speechEnded event includes duration', () {
      const event = VADEvent(
        type: VADEventType.speechEnded,
        timestamp: Duration(seconds: 2),
        durationMs: 1500,
      );

      expect(event.type, equals(VADEventType.speechEnded));
      expect(event.durationMs, equals(1500));
    });
  });
}
