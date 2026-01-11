import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/datasources/qa_session_local_datasource.dart';
import '../../data/datasources/qa_session_remote_datasource.dart';
import '../../data/repositories/qa_session_repository_impl.dart';
import '../../data/services/voice_input_service.dart';
import '../../domain/entities/qa_message.dart';
import '../../domain/entities/qa_session.dart';
import '../../domain/repositories/qa_session_repository.dart';
import '../../domain/usecases/send_question.dart';
import '../../domain/usecases/start_session.dart';

part 'qa_session_provider.g.dart';

/// Provider for [VoiceInputService].
@riverpod
VoiceInputService voiceInputService(VoiceInputServiceRef ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = VoiceInputService(apiClient: apiClient);
  ref.onDispose(service.dispose);
  return service;
}

/// Provider for [QASessionRemoteDataSource].
@riverpod
QASessionRemoteDataSource qaSessionRemoteDataSource(
  QaSessionRemoteDataSourceRef ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return QASessionRemoteDataSourceImpl(apiClient: apiClient);
}

/// Provider for [QASessionLocalDataSource].
@riverpod
QASessionLocalDataSource qaSessionLocalDataSource(
  QaSessionLocalDataSourceRef ref,
) {
  final database = ref.watch(databaseProvider);
  return QASessionLocalDataSourceImpl(database: database);
}

/// Provider for [QASessionRepository].
@riverpod
QASessionRepository qaSessionRepository(QaSessionRepositoryRef ref) {
  return QASessionRepositoryImpl(
    remoteDataSource: ref.watch(qaSessionRemoteDataSourceProvider),
    localDataSource: ref.watch(qaSessionLocalDataSourceProvider),
    voiceInputService: ref.watch(voiceInputServiceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
}

/// Provider for [StartSessionUseCase].
@riverpod
StartSessionUseCase startSessionUseCase(StartSessionUseCaseRef ref) {
  return StartSessionUseCase(
    repository: ref.watch(qaSessionRepositoryProvider),
  );
}

/// Provider for [SendQuestionUseCase].
@riverpod
SendQuestionUseCase sendQuestionUseCase(SendQuestionUseCaseRef ref) {
  return SendQuestionUseCase(
    repository: ref.watch(qaSessionRepositoryProvider),
  );
}

/// Provider for watching messages in a session.
@riverpod
Stream<List<QAMessage>> qaMessagesStream(
  QaMessagesStreamRef ref,
  String sessionId,
) {
  final repository = ref.watch(qaSessionRepositoryProvider);
  return repository.watchMessages(sessionId);
}

/// Provider for watching a session.
@riverpod
Stream<QASession?> qaSessionStream(
  QaSessionStreamRef ref,
  String sessionId,
) {
  final repository = ref.watch(qaSessionRepositoryProvider);
  return repository.watchSession(sessionId);
}

/// State for the Q&A session page.
enum QASessionState {
  initial,
  loading,
  active,
  recording,
  processing,
  error,
  ended,
}

/// UI state for Q&A session.
class QASessionUIState {
  const QASessionUIState({
    this.state = QASessionState.initial,
    this.session,
    this.messages = const [],
    this.errorMessage,
    this.isNearLimit = false,
    this.hasReachedLimit = false,
  });

  final QASessionState state;
  final QASession? session;
  final List<QAMessage> messages;
  final String? errorMessage;
  final bool isNearLimit;
  final bool hasReachedLimit;

  QASessionUIState copyWith({
    QASessionState? state,
    QASession? session,
    List<QAMessage>? messages,
    String? errorMessage,
    bool? isNearLimit,
    bool? hasReachedLimit,
  }) {
    return QASessionUIState(
      state: state ?? this.state,
      session: session ?? this.session,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      isNearLimit: isNearLimit ?? this.isNearLimit,
      hasReachedLimit: hasReachedLimit ?? this.hasReachedLimit,
    );
  }
}

/// Notifier for Q&A session state.
@riverpod
class QASessionNotifier extends _$QASessionNotifier {
  @override
  QASessionUIState build(String storyId) {
    return const QASessionUIState();
  }

  /// Starts or resumes a Q&A session.
  Future<void> startSession() async {
    state = state.copyWith(state: QASessionState.loading);

    try {
      final useCase = ref.read(startSessionUseCaseProvider);
      final session = await useCase.call(storyId);

      // Load existing messages
      final repository = ref.read(qaSessionRepositoryProvider);
      final messages = await repository.getMessages(session.id);

      state = state.copyWith(
        state: QASessionState.active,
        session: session,
        messages: messages,
        isNearLimit: session.isNearLimit,
        hasReachedLimit: session.hasReachedLimit,
      );

      // Watch for message updates
      _watchMessages(session.id);
    } catch (e) {
      state = state.copyWith(
        state: QASessionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Starts recording a voice question.
  Future<void> startRecording() async {
    if (state.hasReachedLimit) {
      state = state.copyWith(
        state: QASessionState.error,
        errorMessage: '已達到問答次數上限',
      );
      return;
    }

    try {
      final voiceService = ref.read(voiceInputServiceProvider);
      await voiceService.startRecording();
      state = state.copyWith(state: QASessionState.recording);
    } catch (e) {
      state = state.copyWith(
        state: QASessionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stops recording and sends the question.
  Future<void> stopRecordingAndSend() async {
    if (state.session == null) return;

    try {
      final voiceService = ref.read(voiceInputServiceProvider);
      final result = await voiceService.stopRecording();

      state = state.copyWith(state: QASessionState.processing);

      final useCase = ref.read(sendQuestionUseCaseProvider);
      final response = await useCase.sendVoiceQuestion(
        sessionId: state.session!.id,
        audioFilePath: result.path,
      );

      state = state.copyWith(
        state: QASessionState.active,
        session: response.session,
        messages: [
          ...state.messages,
          response.childMessage,
          response.aiMessage,
        ],
        isNearLimit: response.isNearLimit,
        hasReachedLimit: response.hasReachedLimit,
      );
    } catch (e) {
      state = state.copyWith(
        state: QASessionState.active,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancels the current recording.
  Future<void> cancelRecording() async {
    try {
      final voiceService = ref.read(voiceInputServiceProvider);
      await voiceService.cancelRecording();
      state = state.copyWith(state: QASessionState.active);
    } catch (_) {
      state = state.copyWith(state: QASessionState.active);
    }
  }

  /// Sends a text question.
  Future<void> sendTextQuestion(String question) async {
    if (state.session == null) return;

    if (state.hasReachedLimit) {
      state = state.copyWith(
        state: QASessionState.error,
        errorMessage: '已達到問答次數上限',
      );
      return;
    }

    state = state.copyWith(state: QASessionState.processing);

    try {
      final useCase = ref.read(sendQuestionUseCaseProvider);
      final response = await useCase.sendTextQuestion(
        sessionId: state.session!.id,
        question: question,
      );

      state = state.copyWith(
        state: QASessionState.active,
        session: response.session,
        messages: [
          ...state.messages,
          response.childMessage,
          response.aiMessage,
        ],
        isNearLimit: response.isNearLimit,
        hasReachedLimit: response.hasReachedLimit,
      );
    } catch (e) {
      state = state.copyWith(
        state: QASessionState.active,
        errorMessage: e.toString(),
      );
    }
  }

  /// Ends the session.
  Future<void> endSession() async {
    if (state.session == null) return;

    try {
      final useCase = ref.read(startSessionUseCaseProvider);
      await useCase.endSession(state.session!.id);

      state = state.copyWith(
        state: QASessionState.ended,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString(),
      );
    }
  }

  /// Clears any error message.
  void clearError() {
    state = state.copyWith();
  }

  /// Watches for message updates.
  void _watchMessages(String sessionId) {
    final repository = ref.read(qaSessionRepositoryProvider);
    repository.watchMessages(sessionId).listen((messages) {
      state = state.copyWith(messages: messages);
    });
  }
}
