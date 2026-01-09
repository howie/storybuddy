# Research: Full App UI Flow

**Feature**: 002-full-app-ui-flow
**Date**: 2026-01-09

## Research Topics

### 1. Flutter Drawer Navigation Pattern

**Decision**: Use Material Design `Drawer` widget with `Scaffold.drawer` property

**Rationale**:
- Built-in Flutter widget, no additional dependencies
- Familiar UX pattern for mobile users
- Supports gesture-based opening (swipe from left edge)
- Works seamlessly with existing `Scaffold` in `story_list_page.dart`

**Alternatives Considered**:
- Bottom Navigation Bar: Rejected - not suitable for 3 secondary features (voice, settings, questions)
- Tab Navigation: Rejected - tabs imply same-level content, but stories are primary
- PopupMenu in AppBar: Rejected - less discoverable, no space for status indicators

**Implementation Notes**:
- Add hamburger menu icon to AppBar leading
- Drawer header shows app branding and voice profile status
- List tiles for: 錄製聲音, 待答問題, 設定
- Use `Navigator.pop(context)` before `context.go()` to close drawer

---

### 2. Voice Profile Status Display

**Decision**: Create reusable `VoiceStatusIndicator` widget showing status with icon and text

**Rationale**:
- Voice status is critical for user flow (must record before generating audio)
- Visual feedback reduces user confusion
- Reusable across drawer and potentially story detail page

**Status Mappings**:
| Backend Status | Display Text | Icon | Color |
|---------------|--------------|------|-------|
| null/empty | 尚未錄製 | mic_off | grey |
| pending | 準備中 | hourglass_empty | orange |
| processing | 處理中 | sync | orange |
| ready | 已就緒 | check_circle | green |
| failed | 處理失敗 | error | red |

**Data Source**: Existing `voice_profile_provider.dart` - use `voiceProfileListProvider`

---

### 3. Audio Generation Flow in Story Detail

**Decision**: Add FAB with conditional state based on `story.hasAudio` and voice profile availability

**Rationale**:
- FAB is the standard pattern for primary action in Flutter
- Consistent with existing "播放故事" FAB placement
- Clear call-to-action for users

**Flow Logic**:
```
IF story.hasAudio THEN
  Show "播放故事" FAB → Navigate to playback
ELSE IF hasReadyVoiceProfile THEN
  Show "生成語音" FAB → Call generateAudio API
ELSE
  Show "錄製聲音" FAB → Navigate to voice recording
```

**API Integration**:
- Use existing `playbackNotifierProvider.generateAudio()` method
- Show progress via `SnackBar` or overlay during generation
- Poll story endpoint for `audio_file_path` update

---

### 4. Existing API Endpoints Verification

**Decision**: No new backend APIs needed - use existing endpoints

**Verified Endpoints**:
- `GET /api/v1/voice-profiles` - List voice profiles with status
- `POST /api/v1/stories/{story_id}/audio` - Generate audio (accepts `voice_profile_id`)
- `GET /api/v1/stories/{story_id}` - Get story with `audio_file_path`

**Notes**:
- Audio generation returns 202 Accepted (async processing)
- Need to implement polling mechanism for completion check
- Existing `playback_provider.dart` has `generateAudio` method but not exposed to UI

---

### 5. Navigation State and Deep Linking

**Decision**: No changes to router.dart needed - all routes already defined

**Verified Routes**:
- `/voice-profile` → VoiceRecordingPage
- `/settings` → SettingsPage
- `/pending-questions` → PendingQuestionsPage
- `/stories/:id/play` → PlaybackPage

**Navigation Pattern**:
- From Drawer: Use `context.go('/path')` for full navigation
- Close drawer first with `Navigator.pop(context)` or use `context.go()` directly

---

## Summary

This feature requires minimal research as it primarily connects existing components. Key decisions:

1. **Drawer** - Standard Material Design pattern, built into Flutter
2. **Voice Status** - New shared widget using existing provider
3. **Audio Generation** - Expose existing provider method to UI with progress feedback
4. **No new APIs** - All backend endpoints already exist
5. **No router changes** - All routes already defined

All technical unknowns are resolved. Ready for Phase 1 design.
