import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'story.freezed.dart';

/// Story entity representing a story that can be narrated.
@freezed
class Story with _$Story {
  const factory Story({
    /// Unique identifier.
    required String id,

    /// Parent/owner ID.
    required String parentId,

    /// Story title.
    required String title,

    /// Story text content.
    required String content,

    /// Content source (imported or AI generated).
    required StorySource source,

    /// Character count of content.
    required int wordCount,

    /// Creation timestamp.
    required DateTime createdAt,

    /// Last update timestamp.
    required DateTime updatedAt,

    /// AI generation keywords (if AI generated).
    List<String>? keywords,

    /// Estimated reading time in minutes.
    int? estimatedDurationMinutes,

    /// Remote audio URL (after voice synthesis).
    String? audioUrl,

    /// Local cached audio path.
    String? localAudioPath,

    /// Whether the story is available offline.
    @Default(false) bool isDownloaded,

    /// Sync status for offline support.
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _Story;

  const Story._();

  /// Creates a new story from imported text.
  factory Story.imported({
    required String id,
    required String parentId,
    required String title,
    required String content,
  }) {
    final now = DateTime.now();
    return Story(
      id: id,
      parentId: parentId,
      title: title,
      content: content,
      source: StorySource.imported,
      wordCount: content.length,
      estimatedDurationMinutes: _estimateReadingTime(content.length),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Creates a new story from AI generation.
  factory Story.generated({
    required String id,
    required String parentId,
    required String title,
    required String content,
    required List<String> keywords,
  }) {
    final now = DateTime.now();
    return Story(
      id: id,
      parentId: parentId,
      title: title,
      content: content,
      source: StorySource.aiGenerated,
      keywords: keywords,
      wordCount: content.length,
      estimatedDurationMinutes: _estimateReadingTime(content.length),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Returns true if the story has been synced with the server.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Returns true if there are pending local changes.
  bool get hasPendingChanges => syncStatus == SyncStatus.pendingSync;

  /// Returns true if audio is available (either remote or local).
  bool get hasAudio => audioUrl != null || localAudioPath != null;

  /// Returns true if the story can be played offline.
  bool get canPlayOffline => isDownloaded && localAudioPath != null;

  /// Returns a display-friendly source label.
  String get sourceLabel => switch (source) {
        StorySource.imported => '匯入',
        StorySource.aiGenerated => 'AI 生成',
      };

  /// Estimates reading time based on character count.
  /// Assumes ~300 Chinese characters per minute for children's stories.
  static int _estimateReadingTime(int charCount) {
    const charsPerMinute = 300;
    return (charCount / charsPerMinute).ceil().clamp(1, 60);
  }
}
