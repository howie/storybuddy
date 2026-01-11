# Data Model: Full App UI Flow

**Feature**: 002-full-app-ui-flow
**Date**: 2026-01-09

## Overview

This feature primarily uses existing data models. No new database entities are required. This document describes the existing entities used and any UI state models added.

## Existing Entities (No Changes)

### VoiceProfile

Represents a parent's voice sample used for AI voice cloning.

| Field | Type | Description |
|-------|------|-------------|
| id | String (UUID) | Unique identifier |
| parentId | String (UUID) | Owner parent ID |
| status | Enum | pending, processing, ready, failed |
| createdAt | DateTime | Creation timestamp |
| updatedAt | DateTime | Last update timestamp |
| audioFilePath | String? | Path to voice sample file |

**Source**: `voice_profile/domain/entities/voice_profile.dart`

### Story

Represents a story that can be played with AI voice.

| Field | Type | Description |
|-------|------|-------------|
| id | String (UUID) | Unique identifier |
| title | String | Story title |
| content | String | Story text content |
| source | Enum | imported, ai_generated |
| hasAudio | bool (computed) | True if audioUrl or localAudioPath exists |
| audioUrl | String? | Remote audio URL |
| localAudioPath | String? | Local cached audio path |

**Source**: `stories/domain/entities/story.dart`

## New UI State Models

### DrawerState

Lightweight state for drawer display. Not persisted.

```dart
class DrawerState {
  final VoiceProfileStatus? voiceStatus;
  final int pendingQuestionCount;
  final bool isLoading;
}

enum VoiceProfileStatus {
  notRecorded,  // No voice profile exists
  pending,      // Uploaded, awaiting processing
  processing,   // Being processed by AI
  ready,        // Ready for use
  failed,       // Processing failed
}
```

**Usage**: Drawer header shows voice status indicator and pending question badge.

### AudioGenerationState

State for tracking audio generation progress. Managed by existing `playbackNotifierProvider`.

```dart
class AudioGenerationState {
  final bool isGenerating;
  final double? progress;  // 0.0 to 1.0, null if indeterminate
  final String? errorMessage;
  final String? generatedAudioPath;
}
```

**Flow**:
1. User taps "生成語音" → `isGenerating = true`
2. API returns 202 → Start polling story endpoint
3. `audio_file_path` populated → `isGenerating = false`, navigate to playback
4. Error → `errorMessage` set, show to user

## State Provider Modifications

### Existing: voiceProfileListProvider

**Current**: Fetches list of voice profiles for parent
**Modification**: Add computed `hasReadyProfile` getter

```dart
extension VoiceProfileListX on AsyncValue<List<VoiceProfile>> {
  bool get hasReadyProfile =>
    valueOrNull?.any((p) => p.status == VoiceProfileStatus.ready) ?? false;

  VoiceProfile? get latestReadyProfile =>
    valueOrNull
      ?.where((p) => p.status == VoiceProfileStatus.ready)
      .sorted((a, b) => b.createdAt.compareTo(a.createdAt))
      .firstOrNull;
}
```

### Existing: pendingQuestionListProvider

**Current**: Fetches pending questions
**Usage**: Count used in drawer badge

## Entity Relationships

```
┌─────────────┐       ┌─────────────┐
│   Parent    │───────│VoiceProfile │
│             │  1:N  │   (status)  │
└─────────────┘       └─────────────┘
       │
       │ 1:N
       ▼
┌─────────────┐       ┌─────────────┐
│   Story     │───────│   Audio     │
│ (hasAudio)  │  1:1  │   (file)    │
└─────────────┘       └─────────────┘
       │
       │ 1:N
       ▼
┌─────────────────────┐
│  PendingQuestion    │
│  (from Q&A session) │
└─────────────────────┘
```

## No Database Migrations Required

All data models already exist in:
- Backend: SQLite via SQLAlchemy (000-StoryBuddy-mvp)
- Mobile: SQLite via Drift (001-flutter-mobile-app)

This feature only adds UI presentation logic, no schema changes.
