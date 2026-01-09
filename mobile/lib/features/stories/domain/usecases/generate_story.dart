import '../entities/story.dart';
import '../repositories/story_repository.dart';

/// Use case for generating a story using AI from keywords.
class GenerateStoryUseCase {
  GenerateStoryUseCase({required this.repository});

  final StoryRepository repository;

  /// Minimum number of keywords required.
  static const int minKeywords = 1;

  /// Maximum number of keywords allowed.
  static const int maxKeywords = 5;

  /// Maximum length for a single keyword.
  static const int maxKeywordLength = 20;

  /// Generates a story from the given keywords.
  Future<Story> call({
    required String parentId,
    required List<String> keywords,
  }) async {
    // Validate keywords
    final trimmedKeywords = keywords
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    if (trimmedKeywords.isEmpty) {
      throw NoKeywordsException();
    }

    if (trimmedKeywords.length < minKeywords) {
      throw TooFewKeywordsException(
        minRequired: minKeywords,
        actual: trimmedKeywords.length,
      );
    }

    if (trimmedKeywords.length > maxKeywords) {
      throw TooManyKeywordsException(
        maxAllowed: maxKeywords,
        actual: trimmedKeywords.length,
      );
    }

    // Check individual keyword length
    for (final keyword in trimmedKeywords) {
      if (keyword.length > maxKeywordLength) {
        throw KeywordTooLongException(
          keyword: keyword,
          maxLength: maxKeywordLength,
        );
      }
    }

    return repository.generateStory(
      parentId: parentId,
      keywords: trimmedKeywords,
    );
  }

  /// Validates keywords without generating.
  KeywordValidationResult validateKeywords(List<String> keywords) {
    final trimmed = keywords
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    if (trimmed.isEmpty) {
      return KeywordValidationResult(
        isValid: false,
        message: '請輸入至少 $minKeywords 個關鍵字',
        keywordCount: 0,
      );
    }

    if (trimmed.length < minKeywords) {
      return KeywordValidationResult(
        isValid: false,
        message: '請輸入至少 $minKeywords 個關鍵字',
        keywordCount: trimmed.length,
      );
    }

    if (trimmed.length > maxKeywords) {
      return KeywordValidationResult(
        isValid: false,
        message: '最多只能輸入 $maxKeywords 個關鍵字',
        keywordCount: trimmed.length,
      );
    }

    // Check for long keywords
    final longKeywords = trimmed.where((k) => k.length > maxKeywordLength);
    if (longKeywords.isNotEmpty) {
      return KeywordValidationResult(
        isValid: false,
        message: '關鍵字不能超過 $maxKeywordLength 字',
        keywordCount: trimmed.length,
      );
    }

    return KeywordValidationResult(
      isValid: true,
      keywordCount: trimmed.length,
    );
  }
}

/// Result of keyword validation.
class KeywordValidationResult {
  KeywordValidationResult({
    required this.isValid,
    this.message,
    required this.keywordCount,
  });

  final bool isValid;
  final String? message;
  final int keywordCount;
}

/// Exception thrown when no keywords are provided.
class NoKeywordsException implements Exception {
  @override
  String toString() => '請輸入關鍵字';
}

/// Exception thrown when too few keywords are provided.
class TooFewKeywordsException implements Exception {
  TooFewKeywordsException({
    required this.minRequired,
    required this.actual,
  });

  final int minRequired;
  final int actual;

  @override
  String toString() => '請輸入至少 $minRequired 個關鍵字（目前 $actual 個）';
}

/// Exception thrown when too many keywords are provided.
class TooManyKeywordsException implements Exception {
  TooManyKeywordsException({
    required this.maxAllowed,
    required this.actual,
  });

  final int maxAllowed;
  final int actual;

  @override
  String toString() => '最多只能輸入 $maxAllowed 個關鍵字（目前 $actual 個）';
}

/// Exception thrown when a keyword is too long.
class KeywordTooLongException implements Exception {
  KeywordTooLongException({
    required this.keyword,
    required this.maxLength,
  });

  final String keyword;
  final int maxLength;

  @override
  String toString() => '關鍵字「$keyword」太長，最多 $maxLength 字';
}
