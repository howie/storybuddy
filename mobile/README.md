# StoryBuddy Mobile App

A Flutter mobile application for StoryBuddy - an interactive storytelling platform that allows parents to create personalized audio stories for their children.

## Features

- Browse and manage story library
- Play stories with audio controls (play/pause, seek, speed control)
- Interactive Q&A sessions during story playback
- Voice profile recording for personalized narration
- Offline mode with audio caching
- Pending questions management
- Parent answer recording for out-of-scope questions

## Prerequisites

- Flutter 3.x (latest stable)
- Dart 3.x
- Xcode (for iOS development)
- Android Studio (for Android development)
- CocoaPods (for iOS dependencies)

## Getting Started

### 1. Install Dependencies

```bash
cd mobile
flutter pub get
```

### 2. Generate Code

This project uses code generation for Riverpod providers and Drift database:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Or for watch mode during development:

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 3. iOS Setup

```bash
cd ios
pod install
cd ..
```

### 4. Run the App

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device_id>

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android
```

## Project Structure

```
lib/
├── app/                    # App configuration (router, theme)
├── core/                   # Core utilities and services
│   ├── audio/             # Audio playback and caching
│   ├── database/          # Drift database setup
│   ├── network/           # API client and interceptors
│   ├── sync/              # Offline sync management
│   └── errors/            # Error handling
├── features/              # Feature modules (Clean Architecture)
│   ├── auth/              # Parent authentication
│   ├── stories/           # Story browsing and management
│   ├── playback/          # Audio playback controls
│   ├── qa_session/        # Q&A recording sessions
│   ├── voice_profile/     # Voice profile recording
│   ├── pending_questions/ # Pending questions management
│   └── settings/          # App settings
├── shared/                # Shared widgets and providers
└── main.dart              # App entry point
```

## Testing

### Unit Tests

```bash
flutter test test/unit/
```

### Widget Tests

```bash
flutter test test/widget/
```

### Integration Tests

```bash
flutter test integration_test/
```

### All Tests

```bash
flutter test
```

## Code Quality

### Run Analyzer

```bash
flutter analyze
```

### Format Code

```bash
dart format lib test
```

## Building for Release

### Android

```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Environment Configuration

The app connects to the StoryBuddy backend API. Configure the API base URL in:
- `lib/core/constants/api_constants.dart`

For development, the default points to `http://localhost:8000`.

## Architecture

This app follows Clean Architecture with the following layers:

1. **Presentation** - UI widgets, pages, and state management (Riverpod)
2. **Domain** - Business logic, entities, and use cases
3. **Data** - Data sources (local/remote) and repositories

### Key Dependencies

- **State Management**: Riverpod
- **Routing**: go_router
- **HTTP Client**: Dio
- **Local Database**: Drift (SQLite)
- **Audio Playback**: just_audio, audio_service
- **Audio Recording**: record
- **Secure Storage**: flutter_secure_storage

## License

Apache License 2.0
