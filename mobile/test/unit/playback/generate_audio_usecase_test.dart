import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/features/playback/domain/repositories/playback_repository.dart';
import 'package:storybuddy/features/playback/domain/usecases/generate_audio.dart';

class MockPlaybackRepository extends Mock implements PlaybackRepository {}

void main() {
  late GenerateAudioUseCase useCase;
  late MockPlaybackRepository mockRepository;

  setUp(() {
    mockRepository = MockPlaybackRepository();
    useCase = GenerateAudioUseCase(repository: mockRepository);
  });

  group('GenerateAudioUseCase', () {
    group('call', () {
      test('generates audio with valid inputs', () async {
        // Arrange
        const expectedUrl = 'https://example.com/audio/generated.mp3';
        when(() => mockRepository.generateAudio(
              storyId: any(named: 'storyId'),
              voiceProfileId: any(named: 'voiceProfileId'),
            ),).thenAnswer((_) async => expectedUrl);

        // Act
        final result = await useCase.call(
          storyId: 'story-1',
          voiceProfileId: 'voice-1',
        );

        // Assert
        expect(result, expectedUrl);
        verify(() => mockRepository.generateAudio(
              storyId: 'story-1',
              voiceProfileId: 'voice-1',
            ),).called(1);
      });

      test('throws InvalidStoryIdException when storyId is empty', () async {
        // Act & Assert
        expect(
          () => useCase.call(storyId: '', voiceProfileId: 'voice-1'),
          throwsA(isA<InvalidStoryIdException>()),
        );
        verifyNever(() => mockRepository.generateAudio(
              storyId: any(named: 'storyId'),
              voiceProfileId: any(named: 'voiceProfileId'),
            ),);
      });

      test('throws InvalidVoiceProfileIdException when voiceProfileId is empty',
          () async {
        // Act & Assert
        expect(
          () => useCase.call(storyId: 'story-1', voiceProfileId: ''),
          throwsA(isA<InvalidVoiceProfileIdException>()),
        );
        verifyNever(() => mockRepository.generateAudio(
              storyId: any(named: 'storyId'),
              voiceProfileId: any(named: 'voiceProfileId'),
            ),);
      });

      test('throws InvalidStoryIdException before checking voiceProfileId',
          () async {
        // Act & Assert
        // Both inputs are invalid, but storyId should be checked first
        expect(
          () => useCase.call(storyId: '', voiceProfileId: ''),
          throwsA(isA<InvalidStoryIdException>()),
        );
      });

      test('propagates repository exceptions', () async {
        // Arrange
        when(() => mockRepository.generateAudio(
              storyId: any(named: 'storyId'),
              voiceProfileId: any(named: 'voiceProfileId'),
            ),).thenThrow(AudioGenerationException('Server error'));

        // Act & Assert
        expect(
          () => useCase.call(storyId: 'story-1', voiceProfileId: 'voice-1'),
          throwsA(isA<AudioGenerationException>()),
        );
      });
    });
  });

  group('Exception Messages', () {
    test('InvalidStoryIdException has correct message', () {
      final exception = InvalidStoryIdException();
      expect(exception.toString(), contains('故事'));
      expect(exception.toString(), contains('ID'));
    });

    test('InvalidVoiceProfileIdException has correct message', () {
      final exception = InvalidVoiceProfileIdException();
      expect(exception.toString(), contains('語音'));
      expect(exception.toString(), contains('ID'));
    });

    test('VoiceProfileNotReadyException has correct message', () {
      final exception = VoiceProfileNotReadyException();
      expect(exception.toString(), contains('語音'));
      expect(exception.toString(), contains('就緒'));
    });

    test('AudioGenerationException has correct message', () {
      final exception = AudioGenerationException('測試錯誤');
      expect(exception.toString(), contains('語音生成'));
      expect(exception.toString(), contains('測試錯誤'));
    });
  });
}
