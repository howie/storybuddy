import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/qa_session/domain/entities/qa_message.dart';
import 'package:storybuddy/features/qa_session/presentation/widgets/chat_bubble.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ChatBubble', () {
    final childMessage = QAMessage(
      id: 'msg-1',
      sessionId: 'session-1',
      role: MessageRole.child,
      content: '為什麼天空是藍色的？',
      sequence: 1,
      createdAt: DateTime(2024),
    );

    final aiMessage = QAMessage(
      id: 'msg-2',
      sessionId: 'session-1',
      role: MessageRole.assistant,
      content: '天空看起來是藍色的，是因為陽光穿過大氣層時發生了散射。',
      sequence: 2,
      createdAt: DateTime(2024),
      audioUrl: 'https://example.com/audio.mp3',
    );

    final outOfScopeMessage = QAMessage(
      id: 'msg-3',
      sessionId: 'session-1',
      role: MessageRole.child,
      content: '恐龍為什麼會滅絕？',
      sequence: 3,
      createdAt: DateTime(2024),
      isInScope: false,
    );

    testWidgets('displays child message content', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: childMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('為什麼天空是藍色的？'), findsOneWidget);
    });

    testWidgets('displays AI message content', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: aiMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('天空看起來是藍色的，是因為陽光穿過大氣層時發生了散射。'), findsOneWidget);
    });

    testWidgets('shows role label for child message', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: childMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('小朋友'), findsOneWidget);
    });

    testWidgets('shows role label for AI message', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: aiMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('shows out of scope badge for out-of-scope messages',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: outOfScopeMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已記錄'), findsOneWidget);
    });

    testWidgets('does not show out of scope badge for in-scope messages',
        (tester) async {
      final inScopeMessage = childMessage.copyWith(isInScope: true);
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: inScopeMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已記錄'), findsNothing);
    });

    testWidgets('shows play button for AI messages with audio', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(
              message: aiMessage,
              onPlayAudio: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('播放'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('hides play button for AI messages without audio',
        (tester) async {
      final noAudioMessage = aiMessage.copyWith(audioUrl: null);
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: noAudioMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('播放'), findsNothing);
      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets('hides play button for child messages', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: childMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('播放'), findsNothing);
    });

    testWidgets('calls onPlayAudio when play button tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(
              message: aiMessage,
              onPlayAudio: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('播放'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows child care icon for child avatar', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: childMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.child_care), findsOneWidget);
    });

    testWidgets('shows smart toy icon for AI avatar', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: ChatBubble(message: aiMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });
  });

  group('TypingIndicator', () {
    testWidgets('displays typing indicator with smart toy icon',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: TypingIndicator(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });

    testWidgets('animates the dots', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: TypingIndicator(),
          ),
        ),
      );

      // Pump through some animation frames
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Widget should still be rendered after animation
      expect(find.byType(TypingIndicator), findsOneWidget);
    });
  });

  group('QAMessage entity', () {
    test('isChildMessage returns true for child role', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(message.isChildMessage, true);
      expect(message.isAiMessage, false);
    });

    test('isAiMessage returns true for assistant role', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(message.isAiMessage, true);
      expect(message.isChildMessage, false);
    });

    test('isOutOfScope returns true when isInScope is false', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        isInScope: false,
      );
      expect(message.isOutOfScope, true);
    });

    test('isOutOfScope returns false when isInScope is true', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        isInScope: true,
      );
      expect(message.isOutOfScope, false);
    });

    test('isOutOfScope returns false when isInScope is null', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(message.isOutOfScope, false);
    });

    test('hasAudio returns true when audioUrl is set', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        audioUrl: 'https://example.com/audio.mp3',
      );
      expect(message.hasAudio, true);
    });

    test('hasAudio returns true when localAudioPath is set', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        localAudioPath: '/cache/audio.mp3',
      );
      expect(message.hasAudio, true);
    });

    test('hasAudio returns false when no audio', () {
      final message = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(message.hasAudio, false);
    });

    test('hasOfflineAudio returns true only with localAudioPath', () {
      final onlineOnly = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        audioUrl: 'https://example.com/audio.mp3',
      );
      expect(onlineOnly.hasOfflineAudio, false);

      final withLocal = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        localAudioPath: '/cache/audio.mp3',
      );
      expect(withLocal.hasOfflineAudio, true);
    });

    test('roleLabel returns correct labels', () {
      final childMsg = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(childMsg.roleLabel, '小朋友');

      final aiMsg = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(aiMsg.roleLabel, 'AI');
    });

    test('childQuestion factory creates correct message', () {
      final message = QAMessage.childQuestion(
        id: 'msg-1',
        sessionId: 'session-1',
        content: 'Test question',
        sequence: 1,
        isInScope: true,
      );
      expect(message.role, MessageRole.child);
      expect(message.content, 'Test question');
      expect(message.syncStatus, SyncStatus.pendingSync);
      expect(message.isInScope, true);
    });

    test('aiResponse factory creates correct message', () {
      final message = QAMessage.aiResponse(
        id: 'msg-1',
        sessionId: 'session-1',
        content: 'Test response',
        sequence: 1,
        audioUrl: 'https://example.com/audio.mp3',
      );
      expect(message.role, MessageRole.assistant);
      expect(message.content, 'Test response');
      expect(message.syncStatus, SyncStatus.synced);
      expect(message.audioUrl, 'https://example.com/audio.mp3');
    });

    test('hasPendingChanges returns correct value', () {
      final synced = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
      );
      expect(synced.hasPendingChanges, false);

      final pending = QAMessage(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.child,
        content: 'Test',
        sequence: 1,
        createdAt: DateTime.now(),
        syncStatus: SyncStatus.pendingSync,
      );
      expect(pending.hasPendingChanges, true);
    });
  });

  group('OutOfScopeResponse', () {
    test('has default response text', () {
      expect(OutOfScopeResponse.defaultResponse, isNotEmpty);
      expect(OutOfScopeResponse.defaultResponse, contains('記錄'));
    });

    test('has saved prompt text', () {
      expect(OutOfScopeResponse.savedPrompt, isNotEmpty);
    });
  });
}
