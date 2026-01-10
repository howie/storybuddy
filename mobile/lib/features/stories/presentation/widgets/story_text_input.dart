import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/usecases/import_story.dart';

/// Widget for inputting story text content with character count.
class StoryTextInput extends StatefulWidget {
  const StoryTextInput({
    required this.controller,
    required this.onChanged,
    this.maxLength = ImportStoryUseCase.maxContentLength,
    this.minLines = 10,
    this.maxLines = 20,
    this.hintText = '在這裡貼上或輸入故事內容...',
    super.key,
  });

  final TextEditingController controller;
  final void Function(String, ValidationResult) onChanged;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final String hintText;

  @override
  State<StoryTextInput> createState() => _StoryTextInputState();
}

class _StoryTextInputState extends State<StoryTextInput> {
  late ValidationResult _validationResult;

  @override
  void initState() {
    super.initState();
    _validationResult = _validate(widget.controller.text);
  }

  ValidationResult _validate(String text) {
    final length = text.trim().length;

    if (length == 0) {
      return ValidationResult(
        isValid: false,
        message: '請輸入故事內容',
        characterCount: 0,
        maxCharacters: widget.maxLength,
      );
    }

    if (length < ImportStoryUseCase.minContentLength) {
      return ValidationResult(
        isValid: false,
        message: '故事內容至少需要 ${ImportStoryUseCase.minContentLength} 字',
        characterCount: length,
        maxCharacters: widget.maxLength,
      );
    }

    if (length > widget.maxLength) {
      return ValidationResult(
        isValid: false,
        message: '故事內容不能超過 ${widget.maxLength} 字',
        characterCount: length,
        maxCharacters: widget.maxLength,
      );
    }

    if (length > widget.maxLength * 0.9) {
      return ValidationResult(
        isValid: true,
        message: '接近字數上限',
        characterCount: length,
        maxCharacters: widget.maxLength,
        isWarning: true,
      );
    }

    return ValidationResult(
      isValid: true,
      characterCount: length,
      maxCharacters: widget.maxLength,
    );
  }

  void _onTextChanged(String text) {
    setState(() {
      _validationResult = _validate(text);
    });
    widget.onChanged(text, _validationResult);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text field
        TextField(
          controller: widget.controller,
          onChanged: _onTextChanged,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          decoration: InputDecoration(
            hintText: widget.hintText,
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor:
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            height: 1.6,
          ),
        ),

        const SizedBox(height: 8),

        // Character count and validation
        _buildFooter(theme),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    Color countColor;
    if (!_validationResult.isValid &&
        _validationResult.characterCount > _validationResult.maxCharacters) {
      countColor = theme.colorScheme.error;
    } else if (_validationResult.isWarning) {
      countColor = theme.colorScheme.tertiary;
    } else {
      countColor = theme.colorScheme.onSurfaceVariant;
    }

    return Row(
      children: [
        // Validation message
        if (_validationResult.message != null)
          Expanded(
            child: Text(
              _validationResult.message!,
              style: AppTextStyles.labelLarge.copyWith(
                color: _validationResult.isValid
                    ? (_validationResult.isWarning
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant)
                    : theme.colorScheme.error,
              ),
            ),
          )
        else
          const Spacer(),

        // Character count
        Text(
          '${_validationResult.characterCount} / ${_validationResult.maxCharacters}',
          style: AppTextStyles.labelLarge.copyWith(
            color: countColor,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Progress indicator for character count.
class CharacterCountProgress extends StatelessWidget {
  const CharacterCountProgress({
    required this.current,
    required this.max,
    this.height = 4.0,
    super.key,
  });

  final int current;
  final int max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (current / max).clamp(0.0, 1.0);

    Color progressColor;
    if (current > max) {
      progressColor = theme.colorScheme.error;
    } else if (current > max * 0.9) {
      progressColor = theme.colorScheme.tertiary;
    } else {
      progressColor = theme.colorScheme.primary;
    }

    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
