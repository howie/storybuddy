import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/stories/domain/entities/story.dart';
import 'package:storybuddy/features/stories/domain/repositories/story_repository.dart';
import 'package:storybuddy/features/stories/domain/usecases/generate_story.dart';

class MockStoryRepository extends Mock implements StoryRepository {}

void main() {
  late GenerateStoryUseCase useCase;
  late MockStoryRepository mockRepository;

  setUp(() {
    mockRepository = MockStoryRepository();
    useCase = GenerateStoryUseCase(repository: mockRepository);
  });

  final testStory = Story(
    id: 'generated-story-1',
    parentId: 'parent-1',
    title: '小熊的森林冒險',
    content: '從前有一隻小熊住在森林裡...',
    wordCount: 500,
    source: StorySource.aiGenerated,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  group('GenerateStoryUseCase', () {
    group('call', () {
      test('generates story with valid keywords', () async {
        // Arrange
        when(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),).thenAnswer((_) async => testStory);

        // Act
        final result = await useCase.call(
          parentId: 'parent-1',
          keywords: ['小熊', '森林', '冒險'],
        );

        // Assert
        expect(result.id, 'generated-story-1');
        expect(result.title, '小熊的森林冒險');
        expect(result.source, StorySource.aiGenerated);
        verify(() => mockRepository.generateStory(
              parentId: 'parent-1',
              keywords: ['小熊', '森林', '冒險'],
            ),).called(1);
      });

      test('trims whitespace from keywords', () async {
        // Arrange
        when(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),).thenAnswer((_) async => testStory);

        // Act
        await useCase.call(
          parentId: 'parent-1',
          keywords: ['  小熊  ', ' 森林 ', '冒險  '],
        );

        // Assert
        verify(() => mockRepository.generateStory(
              parentId: 'parent-1',
              keywords: ['小熊', '森林', '冒險'],
            ),).called(1);
      });

      test('filters empty keywords', () async {
        // Arrange
        when(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),).thenAnswer((_) async => testStory);

        // Act
        await useCase.call(
          parentId: 'parent-1',
          keywords: ['小熊', '', '   ', '森林'],
        );

        // Assert
        verify(() => mockRepository.generateStory(
              parentId: 'parent-1',
              keywords: ['小熊', '森林'],
            ),).called(1);
      });

      test('throws NoKeywordsException when all keywords are empty', () async {
        // Act & Assert
        expect(
          () => useCase.call(parentId: 'parent-1', keywords: ['', '   ', '  ']),
          throwsA(isA<NoKeywordsException>()),
        );
        verifyNever(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),);
      });

      test('throws NoKeywordsException when keywords list is empty', () async {
        // Act & Assert
        expect(
          () => useCase.call(parentId: 'parent-1', keywords: []),
          throwsA(isA<NoKeywordsException>()),
        );
      });

      test('throws TooManyKeywordsException when more than 5 keywords',
          () async {
        // Act & Assert
        expect(
          () => useCase.call(
            parentId: 'parent-1',
            keywords: ['一', '二', '三', '四', '五', '六'],
          ),
          throwsA(isA<TooManyKeywordsException>()),
        );
      });

      test('accepts exactly 5 keywords', () async {
        // Arrange
        when(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),).thenAnswer((_) async => testStory);

        // Act
        await useCase.call(
          parentId: 'parent-1',
          keywords: ['一', '二', '三', '四', '五'],
        );

        // Assert
        verify(() => mockRepository.generateStory(
              parentId: 'parent-1',
              keywords: ['一', '二', '三', '四', '五'],
            ),).called(1);
      });

      test('throws KeywordTooLongException when keyword exceeds 20 characters',
          () async {
        // Keyword with 21 characters
        const longKeyword = '一二三四五六七八九十一二三四五六七八九十一';

        // Act & Assert
        expect(
          () => useCase.call(
            parentId: 'parent-1',
            keywords: [longKeyword],
          ),
          throwsA(isA<KeywordTooLongException>()),
        );
      });

      test('accepts keyword with exactly 20 characters', () async {
        // Arrange
        when(() => mockRepository.generateStory(
              parentId: any(named: 'parentId'),
              keywords: any(named: 'keywords'),
            ),).thenAnswer((_) async => testStory);
        // Exactly 20 characters
        const keyword20Chars = '一二三四五六七八九十一二三四五六七八九十';

        // Act
        await useCase.call(
          parentId: 'parent-1',
          keywords: [keyword20Chars],
        );

        // Assert
        verify(() => mockRepository.generateStory(
              parentId: 'parent-1',
              keywords: [keyword20Chars],
            ),).called(1);
      });
    });

    group('validateKeywords', () {
      test('returns valid result for good keywords', () {
        // Act
        final result = useCase.validateKeywords(['小熊', '森林', '冒險']);

        // Assert
        expect(result.isValid, true);
        expect(result.keywordCount, 3);
        expect(result.message, isNull);
      });

      test('returns invalid result for empty list', () {
        // Act
        final result = useCase.validateKeywords([]);

        // Assert
        expect(result.isValid, false);
        expect(result.keywordCount, 0);
        expect(result.message, isNotNull);
      });

      test('returns invalid result for too many keywords', () {
        // Act
        final result = useCase.validateKeywords(['一', '二', '三', '四', '五', '六']);

        // Assert
        expect(result.isValid, false);
        expect(result.keywordCount, 6);
        expect(result.message, contains('5'));
      });

      test('returns invalid result for long keyword', () {
        // Keyword with 21 characters
        const longKeyword = '一二三四五六七八九十一二三四五六七八九十一';

        // Act
        final result = useCase.validateKeywords([longKeyword]);

        // Assert
        expect(result.isValid, false);
        expect(result.message, contains('20'));
      });

      test('filters whitespace-only keywords in validation', () {
        // Act
        final result = useCase.validateKeywords(['小熊', '  ', '', '森林']);

        // Assert
        expect(result.isValid, true);
        expect(result.keywordCount, 2);
      });
    });
  });

  group('Exception Messages', () {
    test('NoKeywordsException has correct message', () {
      final exception = NoKeywordsException();
      expect(exception.toString(), contains('關鍵字'));
    });

    test('TooFewKeywordsException has correct message', () {
      final exception = TooFewKeywordsException(minRequired: 1, actual: 0);
      expect(exception.toString(), contains('1'));
      expect(exception.toString(), contains('0'));
    });

    test('TooManyKeywordsException has correct message', () {
      final exception = TooManyKeywordsException(maxAllowed: 5, actual: 6);
      expect(exception.toString(), contains('5'));
      expect(exception.toString(), contains('6'));
    });

    test('KeywordTooLongException has correct message', () {
      final exception = KeywordTooLongException(keyword: '測試', maxLength: 20);
      expect(exception.toString(), contains('測試'));
      expect(exception.toString(), contains('20'));
    });
  });
}
