import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/audio/audio_cache_manager.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/core/network/connectivity_service.dart';
import 'package:storybuddy/features/stories/data/datasources/story_local_datasource.dart';
import 'package:storybuddy/features/stories/data/datasources/story_remote_datasource.dart';
import 'package:storybuddy/features/stories/data/models/story_model.dart';
import 'package:storybuddy/features/stories/data/repositories/story_repository_impl.dart';
import 'package:storybuddy/features/stories/domain/entities/story.dart';

import '../../fixtures/test_data.dart';

class MockStoryRemoteDataSource extends Mock implements StoryRemoteDataSource {}

class MockStoryLocalDataSource extends Mock implements StoryLocalDataSource {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockAudioCacheManager extends Mock implements AudioCacheManager {}

void main() {
  late StoryRepositoryImpl repository;
  late MockStoryRemoteDataSource mockRemoteDataSource;
  late MockStoryLocalDataSource mockLocalDataSource;
  late MockConnectivityService mockConnectivityService;
  late MockAudioCacheManager mockAudioCacheManager;

  setUp(() {
    mockRemoteDataSource = MockStoryRemoteDataSource();
    mockLocalDataSource = MockStoryLocalDataSource();
    mockConnectivityService = MockConnectivityService();
    mockAudioCacheManager = MockAudioCacheManager();

    repository = StoryRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      connectivityService: mockConnectivityService,
      audioCacheManager: mockAudioCacheManager,
    );
  });

  setUpAll(() {
    registerFallbackValue(TestData.story1);
  });

  group('StoryRepositoryImpl', () {
    group('getStories', () {
      test('returns stories from local data source immediately', () async {
        // Arrange
        final localStories = [TestData.story1, TestData.story2];
        when(() => mockLocalDataSource.getStories())
            .thenAnswer((_) async => localStories);
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.getStories();

        // Assert
        expect(result, localStories);
        verify(() => mockLocalDataSource.getStories()).called(1);
      });

      test('triggers background refresh when online', () async {
        // Arrange
        final localStories = [TestData.story1];
        when(() => mockLocalDataSource.getStories())
            .thenAnswer((_) async => localStories);
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockRemoteDataSource.getStories())
            .thenAnswer((_) async => []);
        when(() => mockLocalDataSource.getStory(any()))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getStories();

        // Assert
        expect(result, localStories);
        // Background refresh is triggered but we don't wait for it
        await Future.delayed(const Duration(milliseconds: 100));
      });
    });

    group('getStory', () {
      test('returns story from local cache when available', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('story-1'))
            .thenAnswer((_) async => TestData.story1);

        // Act
        final result = await repository.getStory('story-1');

        // Assert
        expect(result, TestData.story1);
        verifyNever(() => mockRemoteDataSource.getStory(any()));
      });

      test('fetches from remote when not in local cache and online', () async {
        // Arrange
        final storyModel = StoryModel(
          id: 'story-1',
          parentId: 'parent-1',
          title: '小紅帽',
          content: '從前從前...',
          source: StorySource.imported,
          wordCount: 500,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        when(() => mockLocalDataSource.getStory('story-1'))
            .thenAnswer((_) async => null);
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockRemoteDataSource.getStory('story-1'))
            .thenAnswer((_) async => storyModel);
        when(() => mockLocalDataSource.saveStory(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.getStory('story-1');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'story-1');
        verify(() => mockLocalDataSource.saveStory(any())).called(1);
      });

      test('returns null when offline and not cached', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('story-1'))
            .thenAnswer((_) async => null);
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.getStory('story-1');

        // Assert
        expect(result, isNull);
        verifyNever(() => mockRemoteDataSource.getStory(any()));
      });
    });

    group('importStory', () {
      test('saves story locally with pending sync status', () async {
        // Arrange
        when(() => mockLocalDataSource.saveStory(any()))
            .thenAnswer((_) async {});
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.importStory(
          title: '新故事',
          content: '這是新故事的內容...',
        );

        // Assert
        expect(result.title, '新故事');
        expect(result.syncStatus, SyncStatus.pendingSync);
        verify(() => mockLocalDataSource.saveStory(any())).called(1);
      });

      test('syncs to remote when online', () async {
        // Arrange
        final remoteModel = StoryModel(
          id: 'remote-id',
          parentId: 'parent-1',
          title: '新故事',
          content: '這是新故事的內容...',
          source: StorySource.imported,
          wordCount: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        when(() => mockLocalDataSource.saveStory(any()))
            .thenAnswer((_) async {});
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockRemoteDataSource.importStory(
              title: any(named: 'title'),
              content: any(named: 'content'),
            )).thenAnswer((_) async => remoteModel);

        // Act
        final result = await repository.importStory(
          title: '新故事',
          content: '這是新故事的內容...',
        );

        // Assert
        expect(result.id, 'remote-id');
        verify(() => mockRemoteDataSource.importStory(
              title: any(named: 'title'),
              content: any(named: 'content'),
            )).called(1);
      });
    });

    group('generateStory', () {
      test('throws exception when offline', () async {
        // Arrange
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => repository.generateStory(parentId: 'parent-1', keywords: ['小熊', '森林']),
          throwsException,
        );
      });

      test('generates story from remote when online', () async {
        // Arrange
        final remoteModel = StoryModel(
          id: 'generated-id',
          parentId: 'parent-1',
          title: '小熊的森林冒險',
          content: '從前有一隻小熊住在森林裡...',
          source: StorySource.aiGenerated,
          wordCount: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockRemoteDataSource.generateStory(parentId: any(named: 'parentId'), keywords: any(named: 'keywords')))
            .thenAnswer((_) async => remoteModel);
        when(() => mockLocalDataSource.saveStory(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.generateStory(parentId: 'parent-1', keywords: ['小熊', '森林']);

        // Assert
        expect(result.id, 'generated-id');
        expect(result.source, StorySource.aiGenerated);
        verify(() => mockLocalDataSource.saveStory(any())).called(1);
      });
    });

    group('deleteStory', () {
      test('deletes story locally and removes cached audio', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('story-2'))
            .thenAnswer((_) async => TestData.story2);
        when(() => mockAudioCacheManager.deleteCachedAudio(any()))
            .thenAnswer((_) async {});
        when(() => mockLocalDataSource.deleteStory('story-2'))
            .thenAnswer((_) async {});
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act
        await repository.deleteStory('story-2');

        // Assert
        verify(() => mockAudioCacheManager.deleteCachedAudio('/cache/story-2.enc'))
            .called(1);
        verify(() => mockLocalDataSource.deleteStory('story-2')).called(1);
      });

      test('deletes from remote when online', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('story-1'))
            .thenAnswer((_) async => TestData.story1);
        when(() => mockLocalDataSource.deleteStory('story-1'))
            .thenAnswer((_) async {});
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockRemoteDataSource.deleteStory('story-1'))
            .thenAnswer((_) async {});

        // Act
        await repository.deleteStory('story-1');

        // Assert
        verify(() => mockRemoteDataSource.deleteStory('story-1')).called(1);
      });
    });

    group('downloadStoryAudio', () {
      test('downloads and caches audio with encryption', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('story-1'))
            .thenAnswer((_) async => TestData.story1);
        when(() => mockAudioCacheManager.cacheAudioFromUrl(
              any(),
              storyId: any(named: 'storyId'),
            )).thenAnswer((_) async => '/cache/story-1.enc');
        when(() => mockLocalDataSource.updateLocalAudioPath(any(), any(), any()))
            .thenAnswer((_) async {});

        // Act
        await repository.downloadStoryAudio('story-1');

        // Assert
        verify(() => mockAudioCacheManager.cacheAudioFromUrl(
              'https://example.com/audio/story-1.mp3',
              storyId: 'story-1',
            )).called(1);
        verify(() => mockLocalDataSource.updateLocalAudioPath(
              'story-1',
              '/cache/story-1.enc',
              true,
            )).called(1);
      });

      test('throws when story not found', () async {
        // Arrange
        when(() => mockLocalDataSource.getStory('invalid'))
            .thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => repository.downloadStoryAudio('invalid'),
          throwsException,
        );
      });
    });

    group('syncStory', () {
      test('does nothing when offline', () async {
        // Arrange
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        // Act
        await repository.syncStory('story-3');

        // Assert
        verifyNever(() => mockLocalDataSource.getStory(any()));
      });

      test('syncs pending story to remote', () async {
        // Arrange
        final remoteModel = StoryModel(
          id: 'story-3',
          parentId: 'parent-1',
          title: '等待同步的故事',
          content: '這是一個等待同步的故事...',
          source: StorySource.imported,
          wordCount: 200,
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
        );
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
        when(() => mockLocalDataSource.getStory('story-3'))
            .thenAnswer((_) async => TestData.storyPendingSync);
        when(() => mockRemoteDataSource.updateStory(
              id: any(named: 'id'),
              title: any(named: 'title'),
              content: any(named: 'content'),
            )).thenAnswer((_) async => remoteModel);
        when(() => mockLocalDataSource.saveStory(any()))
            .thenAnswer((_) async {});

        // Act
        await repository.syncStory('story-3');

        // Assert
        verify(() => mockRemoteDataSource.updateStory(
              id: 'story-3',
              title: '等待同步的故事',
              content: '這是一個等待同步的故事...',
            )).called(1);
      });
    });

    group('watchStories', () {
      test('returns stream from local data source', () {
        // Arrange
        final storiesStream = Stream.value([TestData.story1, TestData.story2]);
        when(() => mockLocalDataSource.watchStories())
            .thenAnswer((_) => storiesStream);

        // Act
        final result = repository.watchStories();

        // Assert
        expect(result, isA<Stream<List<Story>>>());
        verify(() => mockLocalDataSource.watchStories()).called(1);
      });
    });
  });
}
