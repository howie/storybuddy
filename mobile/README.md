# StoryBuddy Mobile App

A Flutter mobile application for StoryBuddy - an interactive storytelling platform that allows parents to create personalized audio stories for their children.

## Features

### Core User Stories

| ID | Feature | Description |
|----|---------|-------------|
| US1 | Voice Profile Recording | Parents record 30+ seconds for AI voice cloning |
| US2 | AI Voice Story Narration | Stories played with parent's cloned voice |
| US3 | Interactive Q&A | Children can ask questions after stories |
| US4 | Story Library | Browse, select, and manage stories |
| US5 | Import Stories | Import stories from text (max 5000 chars) |
| US6 | AI Story Generation | Generate stories from keywords |
| US7 | Pending Questions | View out-of-scope questions for parents |

### Additional Features

- Background audio playback with lock screen controls
- Offline mode with encrypted audio caching
- Real-time waveform visualization during recording
- Noise detection for optimal recording quality
- Light/Dark theme support
- Traditional Chinese localization

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

## Security Features

- **Encrypted Storage**: Auth tokens and sensitive data stored using flutter_secure_storage
- **AES-256 Encryption**: Cached audio files are encrypted locally
- **HTTPS/TLS**: All API communications use secure connections
- **Privacy Consent**: Required before first voice recording
- **Data Deletion**: Users can delete all local data from settings

## Offline Support

- **Local-First Architecture**: App works offline with local SQLite database
- **Sync Queue**: Changes made offline are automatically synced when online
- **Audio Caching**: Downloaded stories can be played offline
- **Connectivity Awareness**: Visual indicators show online/offline status
- **Background Sync**: Automatic sync when connection is restored

## Troubleshooting

### Build Issues

If you encounter build issues, try:

```bash
# Clean build
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# iOS specific
cd ios && pod deintegrate && pod install && cd ..
```

### Audio Not Working on iOS Simulator

The iOS Simulator has limited audio recording capabilities. Test voice recording features on a physical device.

### macOS Development

On macOS without code signing, the app uses SharedPreferences fallback for secure storage. This is only for development purposes.

## Architecture

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
