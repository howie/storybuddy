import '../entities/story.dart';
import '../repositories/story_repository.dart';

/// Use case for importing a story from text.
class ImportStoryUseCase {
  ImportStoryUseCase({required this.repository});

  final StoryRepository repository;

  /// Maximum allowed character count for story content.
  static const int maxContentLength = 5000;

  /// Minimum required character count for story content.
  static const int minContentLength = 50;

  /// Maximum allowed character count for story title.
  static const int maxTitleLength = 200;

  /// Imports a story from text content.
  Future<Story> call({
    required String title,
    required String content,
  }) async {
    // Validate title
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw EmptyTitleException();
    }

    if (trimmedTitle.length > maxTitleLength) {
      throw TitleTooLongException(
        maxLength: maxTitleLength,
        actualLength: trimmedTitle.length,
      );
    }

    // Validate content
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw EmptyContentException();
    }

    if (trimmedContent.length < minContentLength) {
      throw ContentTooShortException(
        minLength: minContentLength,
        actualLength: trimmedContent.length,
      );
    }

    if (trimmedContent.length > maxContentLength) {
      throw ContentTooLongException(
        maxLength: maxContentLength,
        actualLength: trimmedContent.length,
      );
    }

    return repository.importStory(
      title: trimmedTitle,
      content: trimmedContent,
    );
  }

  /// Validates content length without importing.
  ValidationResult validateContent(String content) {
    final length = content.trim().length;

    if (length == 0) {
      return ValidationResult(
        isValid: false,
        message: '請輸入故事內容',
        characterCount: 0,
        maxCharacters: maxContentLength,
      );
    }

    if (length < minContentLength) {
      return ValidationResult(
        isValid: false,
        message: '故事內容至少需要 $minContentLength 字',
        characterCount: length,
        maxCharacters: maxContentLength,
      );
    }

    if (length > maxContentLength) {
      return ValidationResult(
        isValid: false,
        message: '故事內容不能超過 $maxContentLength 字',
        characterCount: length,
        maxCharacters: maxContentLength,
      );
    }

    // Warning when approaching limit
    if (length > maxContentLength * 0.9) {
      return ValidationResult(
        isValid: true,
        message: '接近字數上限',
        characterCount: length,
        maxCharacters: maxContentLength,
        isWarning: true,
      );
    }

    return ValidationResult(
      isValid: true,
      characterCount: length,
      maxCharacters: maxContentLength,
    );
  }
}

/// Result of content validation.
class ValidationResult {
  ValidationResult({
    required this.isValid,
    required this.characterCount, required this.maxCharacters, this.message,
    this.isWarning = false,
  });

  final bool isValid;
  final String? message;
  final int characterCount;
  final int maxCharacters;
  final bool isWarning;

  double get progress => characterCount / maxCharacters;
  int get remainingCharacters => maxCharacters - characterCount;
}

/// Exception thrown when title is empty.
class EmptyTitleException implements Exception {
  @override
  String toString() => '請輸入故事標題';
}

/// Exception thrown when title is too long.
class TitleTooLongException implements Exception {
  TitleTooLongException({
    required this.maxLength,
    required this.actualLength,
  });

  final int maxLength;
  final int actualLength;

  @override
  String toString() => '標題不能超過 $maxLength 字（目前 $actualLength 字）';
}

/// Exception thrown when content is empty.
class EmptyContentException implements Exception {
  @override
  String toString() => '請輸入故事內容';
}

/// Exception thrown when content is too short.
class ContentTooShortException implements Exception {
  ContentTooShortException({
    required this.minLength,
    required this.actualLength,
  });

  final int minLength;
  final int actualLength;

  @override
  String toString() => '故事內容至少需要 $minLength 字（目前 $actualLength 字）';
}

/// Exception thrown when content is too long.
class ContentTooLongException implements Exception {
  ContentTooLongException({
    required this.maxLength,
    required this.actualLength,
  });

  final int maxLength;
  final int actualLength;

  @override
  String toString() => '故事內容不能超過 $maxLength 字（目前 $actualLength 字）';
}
