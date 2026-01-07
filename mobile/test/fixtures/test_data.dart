import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/pending_questions/domain/entities/pending_question.dart';
import 'package:storybuddy/features/qa_session/domain/entities/qa_session.dart';
import 'package:storybuddy/features/stories/domain/entities/story.dart';
import 'package:storybuddy/features/voice_profile/domain/entities/voice_profile.dart';

/// Test fixtures for unit and integration tests.
class TestData {
  TestData._();

  // Stories
  static final story1 = Story(
    id: 'story-1',
    parentId: 'parent-1',
    title: '小紅帽',
    content: '從前從前，有一個小女孩叫做小紅帽...',
    wordCount: 500,
    source: StorySource.imported,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    syncStatus: SyncStatus.synced,
    audioUrl: 'https://example.com/audio/story-1.mp3',
    isDownloaded: false,
  );

  static final story2 = Story(
    id: 'story-2',
    parentId: 'parent-1',
    title: '三隻小豬',
    content: '三隻小豬離開媽媽去建造自己的房子...',
    wordCount: 800,
    source: StorySource.aiGenerated,
    createdAt: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
    syncStatus: SyncStatus.synced,
    audioUrl: 'https://example.com/audio/story-2.mp3',
    isDownloaded: true,
    localAudioPath: '/cache/story-2.enc',
  );

  static final storyPendingSync = Story(
    id: 'story-3',
    parentId: 'parent-1',
    title: '等待同步的故事',
    content: '這是一個等待同步的故事...',
    wordCount: 200,
    source: StorySource.imported,
    createdAt: DateTime(2024, 1, 3),
    updatedAt: DateTime(2024, 1, 3),
    syncStatus: SyncStatus.pendingSync,
    isDownloaded: false,
  );

  static final storyNoAudio = Story(
    id: 'story-4',
    parentId: 'parent-1',
    title: '沒有音檔的故事',
    content: '這個故事還沒有生成音檔...',
    wordCount: 300,
    source: StorySource.imported,
    createdAt: DateTime(2024, 1, 4),
    updatedAt: DateTime(2024, 1, 4),
    syncStatus: SyncStatus.synced,
    isDownloaded: false,
  );

  static List<Story> get allStories => [story1, story2, storyPendingSync, storyNoAudio];

  // Voice Profiles
  static final voiceProfile1 = VoiceProfile(
    id: 'voice-1',
    parentId: 'parent-1',
    name: '爸爸的聲音',
    status: VoiceProfileStatus.ready,
    sampleDurationSeconds: 45,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    localAudioPath: '/recordings/voice-1.wav',
    remoteVoiceModelUrl: 'https://example.com/voices/voice-1.wav',
    syncStatus: SyncStatus.synced,
  );

  static final voiceProfileProcessing = VoiceProfile(
    id: 'voice-2',
    parentId: 'parent-1',
    name: '媽媽的聲音',
    status: VoiceProfileStatus.processing,
    sampleDurationSeconds: 35,
    createdAt: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
    localAudioPath: '/recordings/voice-2.wav',
    syncStatus: SyncStatus.pendingSync,
  );

  static final voiceProfileFailed = VoiceProfile(
    id: 'voice-3',
    parentId: 'parent-1',
    name: '失敗的錄音',
    status: VoiceProfileStatus.failed,
    sampleDurationSeconds: 20,
    createdAt: DateTime(2024, 1, 3),
    updatedAt: DateTime(2024, 1, 3),
    localAudioPath: '/recordings/voice-3.wav',
    errorMessage: '錄音品質不足',
    syncStatus: SyncStatus.synced,
  );

  // Q&A Sessions
  static final qaSession1 = QASession(
    id: 'qa-session-1',
    storyId: 'story-1',
    startedAt: DateTime(2024, 1, 5, 14, 30),
    messageCount: 3,
    status: QASessionStatus.completed,
    endedAt: DateTime(2024, 1, 5, 14, 45),
  );

  static final qaSessionActive = QASession(
    id: 'qa-session-2',
    storyId: 'story-2',
    startedAt: DateTime(2024, 1, 6, 10, 0),
    messageCount: 1,
    status: QASessionStatus.active,
  );

  // Pending Questions
  static final pendingQuestion1 = PendingQuestion(
    id: 'pending-1',
    storyId: 'story-1',
    question: '為什麼天空是藍色的？',
    status: PendingQuestionStatus.pending,
    askedAt: DateTime(2024, 1, 5, 14, 33),
  );

  static final pendingQuestion2 = PendingQuestion(
    id: 'pending-2',
    storyId: 'story-2',
    question: '恐龍為什麼會滅絕？',
    status: PendingQuestionStatus.pending,
    askedAt: DateTime(2024, 1, 6, 10, 15),
  );

  static final pendingQuestionAnswered = PendingQuestion(
    id: 'pending-3',
    storyId: 'story-1',
    question: '狼是好人還是壞人？',
    status: PendingQuestionStatus.answered,
    askedAt: DateTime(2024, 1, 4, 9, 0),
    answeredAt: DateTime(2024, 1, 4, 20, 0),
  );

  static List<PendingQuestion> get allPendingQuestions =>
      [pendingQuestion1, pendingQuestion2, pendingQuestionAnswered];

  static List<PendingQuestion> get unansweredPendingQuestions =>
      [pendingQuestion1, pendingQuestion2];

  // Parent data
  static const parentId = 'parent-1';
  static const parentName = 'Test Parent';
  static const parentEmail = 'parent@test.com';
}
