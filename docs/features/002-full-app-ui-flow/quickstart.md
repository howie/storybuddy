# Quickstart: Full App UI Flow

**Feature**: 002-full-app-ui-flow
**Date**: 2026-01-09

## Prerequisites

- Flutter 3.x installed
- Python backend running on port 8001 (000-StoryBuddy-mvp)
- Existing mobile app code from 001-flutter-mobile-app

## Development Setup

```bash
# 1. Switch to feature branch
cd /path/to/storybuddy
git checkout 002-full-app-ui-flow

# 2. Start backend server
source venv/bin/activate
uvicorn src.main:app --host 0.0.0.0 --port 8001 --reload

# 3. In another terminal, run Flutter app
cd mobile
flutter pub get
flutter run -d macos  # or -d chrome, -d ios, -d android
```

## Feature Implementation Order

### Step 1: VoiceStatusIndicator Widget (TDD)

1. Write test: `test/shared/widgets/voice_status_indicator_test.dart`
2. Implement: `lib/shared/widgets/voice_status_indicator.dart`
3. Run test: `flutter test test/shared/widgets/`

### Step 2: AppDrawer Widget (TDD)

1. Write test: `test/features/stories/presentation/widgets/app_drawer_test.dart`
2. Implement: `lib/features/stories/presentation/widgets/app_drawer.dart`
3. Run test: `flutter test test/features/stories/`

### Step 3: Integrate Drawer into StoryListPage

1. Modify: `lib/features/stories/presentation/pages/story_list_page.dart`
   - Add `drawer: AppDrawer()` to Scaffold
   - Add hamburger menu icon to AppBar

### Step 4: Audio Generation FAB in StoryDetailPage (TDD)

1. Write/update test: `test/features/stories/presentation/pages/story_detail_page_test.dart`
2. Modify: `lib/features/stories/presentation/pages/story_detail_page.dart`
   - Update FAB logic for three states (play/generate/record)
   - Add audio generation progress indicator

### Step 5: Integration Testing

```bash
flutter test integration_test/
```

## Key Files to Modify/Create

| Action | File Path |
|--------|-----------|
| CREATE | `lib/shared/widgets/voice_status_indicator.dart` |
| CREATE | `lib/features/stories/presentation/widgets/app_drawer.dart` |
| MODIFY | `lib/features/stories/presentation/pages/story_list_page.dart` |
| MODIFY | `lib/features/stories/presentation/pages/story_detail_page.dart` |
| CREATE | `test/shared/widgets/voice_status_indicator_test.dart` |
| CREATE | `test/features/stories/presentation/widgets/app_drawer_test.dart` |
| MODIFY | `test/features/stories/presentation/pages/story_detail_page_test.dart` |

## Testing the Feature

### Manual Testing Checklist

- [ ] Open app → Story list page loads
- [ ] Tap hamburger menu → Drawer opens
- [ ] Drawer shows voice status (尚未錄製/處理中/已就緒)
- [ ] Tap "錄製聲音" → Navigates to voice recording page
- [ ] Tap "待答問題" → Navigates to pending questions page
- [ ] Tap "設定" → Navigates to settings page
- [ ] Go to story detail (no audio) → Shows "生成語音" or "錄製聲音" FAB
- [ ] (With voice profile) Tap "生成語音" → Shows progress, then "播放故事"
- [ ] Tap "播放故事" → Navigates to playback page

### Automated Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/app_navigation_test.dart
```

## API Endpoints Used

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/voice-profiles` | Get voice profile status |
| POST | `/api/v1/stories/{id}/audio` | Generate audio |
| GET | `/api/v1/stories/{id}` | Poll for audio completion |
| GET | `/api/v1/questions/pending` | Get pending question count |

## Troubleshooting

### Drawer doesn't open
- Check `Scaffold` has `drawer` property set
- Verify `AppBar` has `leading` with menu icon or uses default

### Voice status not updating
- Verify `voiceProfileListProvider` is being watched
- Check network connectivity to backend

### Audio generation fails
- Ensure voice profile has `ready` status
- Check backend logs for ElevenLabs API errors
- Verify `voice_profile_id` is passed to API

### Navigation doesn't work
- Verify routes exist in `router.dart`
- Check `context.go()` vs `context.push()` usage
