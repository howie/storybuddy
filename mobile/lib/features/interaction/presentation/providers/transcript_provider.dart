import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybuddy/features/interaction/data/datasources/transcript_remote_datasource.dart';
import 'package:storybuddy/features/interaction/data/repositories/transcript_repository_impl.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';
import 'package:storybuddy/features/interaction/domain/repositories/transcript_repository.dart';
import 'package:storybuddy/features/interaction/presentation/providers/interaction_settings_provider.dart';

/// T080 [US4] Providers for transcript operations.

/// Provider for transcript remote datasource.
final transcriptRemoteDatasourceProvider =
    Provider<TranscriptRemoteDatasource>((ref) {
  final dio = ref.watch(dioProvider);
  return TranscriptRemoteDatasourceImpl(dio: dio);
});

/// Provider for transcript repository.
final transcriptRepositoryProvider = Provider<TranscriptRepository>((ref) {
  return TranscriptRepositoryImpl(
    remoteDatasource: ref.watch(transcriptRemoteDatasourceProvider),
  );
});

/// State for transcript list.
class TranscriptListState {
  const TranscriptListState({
    this.transcripts = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  final List<TranscriptSummary> transcripts;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  TranscriptListState copyWith({
    List<TranscriptSummary>? transcripts,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return TranscriptListState(
      transcripts: transcripts ?? this.transcripts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Notifier for transcript list with pagination.
class TranscriptListNotifier extends StateNotifier<TranscriptListState> {
  TranscriptListNotifier(this._repository) : super(const TranscriptListState());

  final TranscriptRepository _repository;
  String? _storyIdFilter;

  /// Load first page of transcripts.
  Future<void> loadTranscripts({String? storyId}) async {
    _storyIdFilter = storyId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getTranscripts(
        storyId: storyId,
        page: 1,
      );

      state = TranscriptListState(
        transcripts: response.transcripts,
        hasMore: response.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load next page.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getTranscripts(
        storyId: _storyIdFilter,
        page: nextPage,
      );

      state = state.copyWith(
        transcripts: [...state.transcripts, ...response.transcripts],
        hasMore: response.hasMore,
        currentPage: nextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh the list.
  Future<void> refresh() => loadTranscripts(storyId: _storyIdFilter);

  /// Remove a transcript from the list (after deletion).
  void removeTranscript(String transcriptId) {
    state = state.copyWith(
      transcripts: state.transcripts
          .where((t) => t.id != transcriptId)
          .toList(),
    );
  }
}

/// Provider for transcript list.
final transcriptListProvider =
    StateNotifierProvider<TranscriptListNotifier, TranscriptListState>((ref) {
  return TranscriptListNotifier(ref.watch(transcriptRepositoryProvider));
});

/// Provider for a single transcript.
final transcriptProvider =
    FutureProvider.family<InteractionTranscript, String>((ref, id) async {
  final repository = ref.watch(transcriptRepositoryProvider);
  return repository.getTranscript(id);
});

/// State for email sending.
class SendEmailState {
  const SendEmailState({
    this.isSending = false,
    this.success = false,
    this.error,
  });

  final bool isSending;
  final bool success;
  final String? error;
}

/// Notifier for sending transcript emails.
class SendEmailNotifier extends StateNotifier<SendEmailState> {
  SendEmailNotifier(this._repository) : super(const SendEmailState());

  final TranscriptRepository _repository;

  /// Send transcript to email.
  Future<void> sendEmail({
    required String transcriptId,
    required String email,
  }) async {
    state = const SendEmailState(isSending: true);

    try {
      final result = await _repository.sendEmail(
        transcriptId: transcriptId,
        email: email,
      );

      if (result.success) {
        state = const SendEmailState(success: true);
      } else {
        state = SendEmailState(error: result.error ?? '發送失敗');
      }
    } catch (e) {
      state = SendEmailState(error: e.toString());
    }
  }

  /// Reset state.
  void reset() {
    state = const SendEmailState();
  }
}

/// Provider for email sending state.
final sendEmailProvider =
    StateNotifierProvider<SendEmailNotifier, SendEmailState>((ref) {
  return SendEmailNotifier(ref.watch(transcriptRepositoryProvider));
});

/// Provider for deleting a transcript.
final deleteTranscriptProvider =
    FutureProvider.family<bool, String>((ref, id) async {
  final repository = ref.watch(transcriptRepositoryProvider);
  return repository.deleteTranscript(id);
});
