/// Voice profile status for cloning process.
enum VoiceProfileStatus {
  /// Waiting for upload.
  pending,

  /// Voice model being created.
  processing,

  /// Ready to use for story narration.
  ready,

  /// Voice cloning failed.
  failed,
}

/// Story content source.
enum StorySource {
  /// Parent imported story text.
  imported,

  /// AI generated story from keywords.
  aiGenerated,
}

/// Q&A session status.
enum QASessionStatus {
  /// Session in progress.
  active,

  /// Session ended normally.
  completed,

  /// Session timed out.
  timeout,
}

/// Message sender role in Q&A.
enum MessageRole {
  /// Child's question.
  child,

  /// AI assistant's response.
  assistant,
}

/// Pending question status.
enum PendingQuestionStatus {
  /// Awaiting parent answer.
  pending,

  /// Parent has answered.
  answered,
}

/// Sync status for offline-first architecture.
enum SyncStatus {
  /// Entity is synced with server.
  synced,

  /// Local changes pending sync.
  pendingSync,

  /// Sync attempt failed.
  syncFailed,
}

/// Type of sync operation.
enum SyncOperationType {
  /// Create new entity on server.
  create,

  /// Update existing entity on server.
  update,

  /// Delete entity from server.
  delete,
}

/// Status of a sync operation.
enum SyncOperationStatus {
  /// Waiting to be processed.
  pending,

  /// Currently being processed.
  inProgress,

  /// Successfully completed.
  completed,

  /// Failed after all retries.
  failed,
}
