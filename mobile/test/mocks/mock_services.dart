import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/audio/audio_cache_manager.dart';
import 'package:storybuddy/core/audio/audio_handler.dart';
import 'package:storybuddy/core/network/api_client.dart';
import 'package:storybuddy/core/network/connectivity_service.dart';
import 'package:storybuddy/core/storage/secure_storage_service.dart';
import 'package:storybuddy/core/sync/sync_manager.dart';
import 'package:storybuddy/features/auth/data/repositories/parent_repository_impl.dart';
import 'package:storybuddy/features/pending_questions/data/repositories/pending_question_repository_impl.dart';
import 'package:storybuddy/features/playback/data/repositories/playback_repository_impl.dart';
import 'package:storybuddy/features/qa_session/data/repositories/qa_session_repository_impl.dart';
import 'package:storybuddy/features/stories/data/datasources/story_local_datasource.dart';
import 'package:storybuddy/features/stories/data/datasources/story_remote_datasource.dart';
import 'package:storybuddy/features/stories/data/repositories/story_repository_impl.dart';
import 'package:storybuddy/features/voice_profile/data/repositories/voice_profile_repository_impl.dart';
import 'package:storybuddy/features/voice_profile/data/services/audio_recording_service.dart';

// Core Services
class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockApiClient extends Mock implements ApiClient {}

class MockAudioCacheManager extends Mock implements AudioCacheManager {}

class MockSyncManager extends Mock implements SyncManager {}

class MockStoryAudioHandler extends Mock implements StoryAudioHandler {}

// Data Sources
class MockStoryRemoteDataSource extends Mock implements StoryRemoteDataSource {}

class MockStoryLocalDataSource extends Mock implements StoryLocalDataSource {}

// Repositories
class MockStoryRepositoryImpl extends Mock implements StoryRepositoryImpl {}

class MockVoiceProfileRepositoryImpl extends Mock
    implements VoiceProfileRepositoryImpl {}

class MockPlaybackRepositoryImpl extends Mock
    implements PlaybackRepositoryImpl {}

class MockQASessionRepositoryImpl extends Mock
    implements QASessionRepositoryImpl {}

class MockPendingQuestionRepositoryImpl extends Mock
    implements PendingQuestionRepositoryImpl {}

class MockParentRepositoryImpl extends Mock implements ParentRepositoryImpl {}

// Feature Services
class MockAudioRecordingService extends Mock implements AudioRecordingService {}
