import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/pending_questions/domain/entities/pending_question.dart';
import 'package:storybuddy/features/pending_questions/presentation/widgets/question_card.dart';

import '../../fixtures/test_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('QuestionCard', () {
    final pendingQuestion = PendingQuestion(
      id: 'pending-1',
      storyId: 'story-1',
      question: '為什麼天空是藍色的？',
      status: PendingQuestionStatus.pending,
      askedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    final answeredQuestion = PendingQuestion(
      id: 'pending-2',
      storyId: 'story-1',
      question: '恐龍為什麼會滅絕？',
      status: PendingQuestionStatus.answered,
      askedAt: DateTime.now().subtract(const Duration(days: 1)),
      answeredAt: DateTime.now().subtract(const Duration(hours: 12)),
    );

    testWidgets('displays question text', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('為什麼天空是藍色的？'), findsOneWidget);
    });

    testWidgets('displays story title', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('小紅帽'), findsOneWidget);
    });

    testWidgets('shows story icon', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    });

    testWidgets('shows question icon', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('shows time ago for questions asked hours ago', (tester) async {
      final recentQuestion = PendingQuestion(
        id: 'pending-1',
        storyId: 'story-1',
        question: '測試問題',
        status: PendingQuestionStatus.pending,
        askedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: recentQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3小時前'), findsOneWidget);
    });

    testWidgets('shows time ago for questions asked days ago', (tester) async {
      final oldQuestion = PendingQuestion(
        id: 'pending-1',
        storyId: 'story-1',
        question: '測試問題',
        status: PendingQuestionStatus.pending,
        askedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: oldQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2天前'), findsOneWidget);
    });

    testWidgets('shows time ago for questions asked minutes ago',
        (tester) async {
      final recentQuestion = PendingQuestion(
        id: 'pending-1',
        storyId: 'story-1',
        question: '測試問題',
        status: PendingQuestionStatus.pending,
        askedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: recentQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15分鐘前'), findsOneWidget);
    });

    testWidgets('shows "剛剛" for very recent questions', (tester) async {
      final justNowQuestion = PendingQuestion(
        id: 'pending-1',
        storyId: 'story-1',
        question: '測試問題',
        status: PendingQuestionStatus.pending,
        askedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: justNowQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('剛剛'), findsOneWidget);
    });

    testWidgets('shows mark answered button when callback provided',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
              onMarkAnswered: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('標記為已回答'), findsOneWidget);
    });

    testWidgets('hides mark answered button when no callback', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('標記為已回答'), findsNothing);
    });

    testWidgets('calls onMarkAnswered when button tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
              onMarkAnswered: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('標記為已回答'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows answered indicator for answered questions',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: answeredQuestion,
              storyTitle: '小紅帽',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已回答'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('does not show mark answered for answered questions',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: answeredQuestion,
              storyTitle: '小紅帽',
              onMarkAnswered: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('標記為已回答'), findsNothing);
    });

    testWidgets('calls onTap when card tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: QuestionCard(
              question: pendingQuestion,
              storyTitle: '小紅帽',
              onTap: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(QuestionCard));
      await tester.pumpAndSettle();

      expect(called, true);
    });
  });

  group('PendingQuestionsEmptyState', () {
    testWidgets('shows empty inbox icon', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionsEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('shows empty state message', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionsEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('沒有待回答的問題'), findsOneWidget);
    });

    testWidgets('shows description text', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionsEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('當孩子問了超出故事範圍的問題'), findsOneWidget);
    });
  });

  group('PendingQuestionBadge', () {
    testWidgets('shows count when greater than 0', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionBadge(count: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hides when count is 0', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionBadge(count: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PendingQuestionBadge), findsOneWidget);
      // Should return SizedBox.shrink, so no text visible
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows 99+ when count exceeds 99', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionBadge(count: 150),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows exact count when 99 or less', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionBadge(count: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows single digit count', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const Scaffold(
            body: PendingQuestionBadge(count: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('PendingQuestion entity', () {
    test('test fixture pendingQuestion1 has correct values', () {
      expect(TestData.pendingQuestion1.question, '為什麼天空是藍色的？');
      expect(TestData.pendingQuestion1.status, PendingQuestionStatus.pending);
    });

    test('test fixture pendingQuestionAnswered has correct values', () {
      expect(TestData.pendingQuestionAnswered.status,
          PendingQuestionStatus.answered,);
      expect(TestData.pendingQuestionAnswered.answeredAt, isNotNull);
    });

    test('unansweredPendingQuestions returns only pending questions', () {
      expect(TestData.unansweredPendingQuestions.length, 2);
      for (final q in TestData.unansweredPendingQuestions) {
        expect(q.status, PendingQuestionStatus.pending);
      }
    });
  });
}
