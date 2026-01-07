# Quickstart: Flutter Mobile App

**Branch**: `001-flutter-mobile-app` | **Date**: 2026-01-05

## Prerequisites

### Required Tools

- **Flutter**: 3.x (latest stable)
- **Dart**: 3.x (bundled with Flutter)
- **Xcode**: 15+ (for iOS)
- **Android Studio**: Latest (for Android)
- **VS Code** or **Android Studio** with Flutter extensions

### Verify Installation

```bash
# Check Flutter installation
flutter doctor -v

# Expected output should show:
# [✓] Flutter (Channel stable, 3.x.x)
# [✓] Android toolchain
# [✓] Xcode (for macOS)
# [✓] VS Code or Android Studio
```

---

## Project Setup

### 1. Create Flutter Project

```bash
# Navigate to repository root
cd /Users/howie/Workspace/github/storybuddy

# Create Flutter project in mobile/ directory
flutter create --org com.storybuddy --project-name storybuddy mobile

# Navigate to project
cd mobile
```

### 2. Update `pubspec.yaml`

Replace the dependencies section:

```yaml
name: storybuddy
description: AI-powered storytelling app with parent voice cloning
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Routing
  go_router: ^14.0.0

  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0

  # Audio
  just_audio: ^0.9.36
  audio_service: ^0.18.12
  record: ^5.0.0

  # Database
  drift: ^2.15.0
  sqlite3_flutter_libs: ^0.5.0

  # Storage & Caching
  path_provider: ^2.1.0
  flutter_cache_manager: ^3.3.0
  flutter_secure_storage: ^9.0.0

  # Encryption
  encrypt: ^5.0.3

  # Background Tasks
  workmanager: ^0.5.2

  # Utilities
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  logger: ^2.0.0
  permission_handler: ^11.0.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  drift_dev: ^2.15.0

  # Testing
  mocktail: ^1.0.0
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/l10n/
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Generate Code

```bash
# Run build_runner for code generation
dart run build_runner build --delete-conflicting-outputs
```

---

## Platform Configuration

### iOS Configuration

#### 1. Update `ios/Runner/Info.plist`

Add the following permissions:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>StoryBuddy needs microphone access to record your voice for AI voice cloning.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

#### 2. Set iOS Deployment Target

In `ios/Podfile`, set minimum iOS version:

```ruby
platform :ios, '14.0'
```

Then run:

```bash
cd ios && pod install && cd ..
```

### Android Configuration

#### 1. Update `android/app/src/main/AndroidManifest.xml`

Add permissions inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

#### 2. Set Android SDK Version

In `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 26  // Android 8+
        targetSdkVersion 34
    }
}
```

---

## Project Structure

After setup, create the following structure:

```bash
# Create directory structure
mkdir -p lib/{app,core/{constants,errors,network/interceptors,utils},features/{auth,voice_profile,stories,playback,qa_session,pending_questions}/{data/{datasources,models,repositories},domain/{entities,repositories,usecases},presentation/{providers,pages,widgets}},shared/{widgets,providers}}

mkdir -p test/{unit,widget,mocks}
mkdir -p integration_test
mkdir -p assets/{images,l10n,fonts}
```

---

## Running the App

### Start Backend API

In a separate terminal:

```bash
cd /Users/howie/Workspace/github/storybuddy
source venv/bin/activate
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

### Run Flutter App

```bash
cd mobile

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>
```

### Hot Reload

- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## Development Workflow

### 1. Run Code Generation

When you modify freezed classes, drift tables, or riverpod providers:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 2. Run Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/story_repository_test.dart

# Run with coverage
flutter test --coverage
```

### 3. Run Linter

```bash
flutter analyze
```

### 4. Format Code

```bash
dart format lib test
```

---

## Environment Configuration

### Create `lib/core/constants/env.dart`

```dart
abstract class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );
}
```

### Run with Environment Variables

```bash
# Development
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Production build
flutter build apk --dart-define=API_BASE_URL=https://api.storybuddy.app/api/v1 --dart-define=PRODUCTION=true
```

---

## API Client Setup

### Create `lib/core/network/api_client.dart`

```dart
import 'package:dio/dio.dart';
import '../constants/env.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  Dio get dio => _dio;
}
```

---

## Troubleshooting

### Common Issues

1. **iOS build fails with CocoaPods error**
   ```bash
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

2. **Android Gradle sync fails**
   ```bash
   cd android
   ./gradlew clean
   cd ..
   flutter clean
   flutter pub get
   ```

3. **Code generation not working**
   ```bash
   flutter clean
   flutter pub get
   dart run build_runner clean
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Permission denied on real device**
   - iOS: Check Info.plist permissions
   - Android: Check AndroidManifest.xml permissions
   - Both: Test permission requests at runtime

---

## Next Steps

1. Implement core data layer with Drift database
2. Set up Riverpod providers for state management
3. Create API data sources connecting to backend
4. Build UI screens following feature structure
5. Add widget tests and integration tests
