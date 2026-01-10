import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/voice_profile/data/services/audio_recording_service.dart';
import 'package:storybuddy/features/voice_profile/domain/entities/voice_profile.dart'; 
import 'package:storybuddy/features/voice_profile/domain/usecases/record_voice.dart';
import 'package:storybuddy/features/voice_profile/domain/usecases/upload_voice.dart';
import 'package:storybuddy/features/voice_profile/presentation/pages/voice_recording_page.dart';
import 'package:storybuddy/features/voice_profile/presentation/providers/voice_profile_provider.dart';

// Mocks
class MockAudioRecordingService extends Mock implements AudioRecordingService {}
class MockRecordVoiceUseCase extends Mock implements RecordVoiceUseCase {}
class MockUploadVoiceUseCase extends Mock implements UploadVoiceUseCase {}

// Fake VoiceProfile for return values
final _fakeProfile = VoiceProfile(
  id: 'test-profile-id',
  parentId: 'parent-id',
  name: 'Test Voice',
  status: VoiceProfileStatus.processing,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  syncStatus: SyncStatus.synced,
);

void main() {
  group('VoiceRecordingPage Integration Test', () {
    late MockAudioRecordingService mockRecordingService;
    late MockRecordVoiceUseCase mockRecordUseCase;
    late MockUploadVoiceUseCase mockUploadUseCase;
    late StreamController<double> amplitudeController;

    setUp(() {
      mockRecordingService = MockAudioRecordingService();
      mockRecordUseCase = MockRecordVoiceUseCase();
      mockUploadUseCase = MockUploadVoiceUseCase();
      amplitudeController = StreamController<double>.broadcast();

      // Default behaviors
      when(() => mockRecordingService.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecordingService.amplitudeStream).thenAnswer((_) => amplitudeController.stream);
      when(() => mockRecordingService.startRecording()).thenAnswer((_) async => '/tmp/audio.wav');
      
      when(() => mockRecordingService.stopRecording()).thenAnswer((_) async => 
          RecordingResult(
            path: '/tmp/audio.wav',
            durationSeconds: 45,
            fileSizeBytes: 1024,
          ));
      
      when(() => mockRecordUseCase.call(
        name: any(named: 'name'),
        localAudioPath: any(named: 'localAudioPath'),
        sampleDurationSeconds: any(named: 'sampleDurationSeconds'),
      )).thenAnswer((_) async => _fakeProfile);

      when(() => mockUploadUseCase.call(any(), onSendProgress: any(named: 'onSendProgress')))
          .thenAnswer((invocation) async {
            final progressCallback = invocation.namedArguments[const Symbol('onSendProgress')] as void Function(int, int)?;
            if (progressCallback != null) {
              progressCallback(50, 100);
            }
            return _fakeProfile;
          });
    });

    tearDown(() {
      amplitudeController.close();
    });

    testWidgets('Full flow: Record -> Stop -> Upload -> Navigate', (tester) async {
      // Setup Router
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const VoiceRecordingPage(),
          ),
          GoRoute(
            path: '/voice-profile/status/:id',
            builder: (context, state) => Scaffold(body: Text('Status Page: ${state.pathParameters["id"]}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecordingServiceProvider.overrideWithValue(mockRecordingService),
            recordVoiceUseCaseProvider.overrideWithValue(mockRecordUseCase),
            uploadVoiceUseCaseProvider.overrideWithValue(mockUploadUseCase),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle(); // Wait for privacy dialog

      // 1. Handle Privacy Consent
      expect(find.text('隱私聲明'), findsOneWidget);
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();

      // 2. Start Recording
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(); 
      
      verify(() => mockRecordingService.startRecording()).called(1);

      // 3. Stop Recording
      await tester.pump(const Duration(seconds: 35)); 
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      verify(() => mockRecordingService.stopRecording()).called(1);

      // 4. Upload
      await tester.tap(find.text('上傳'));
      
      // Verification of upload flow
      await tester.pump(); // Initiate upload
      await tester.pump(); // Process upload future

      // 5. Verify Navigation
      await tester.pumpAndSettle(); 

      // Check if router location updated
      // Since we can't easily access router.location property (private/protected in some versions or just not refreshed?)
      // We can check if the new page is in the tree.
      expect(find.text('Status Page: ${_fakeProfile.id}'), findsOneWidget);
    });
  });
}
