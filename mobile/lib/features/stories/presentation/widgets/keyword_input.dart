import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/usecases/generate_story.dart';

/// Widget for inputting keywords for story generation.
class KeywordInput extends StatefulWidget {
  const KeywordInput({
    required this.keywords,
    required this.onKeywordsChanged,
    this.maxKeywords = GenerateStoryUseCase.maxKeywords,
    super.key,
  });

  final List<String> keywords;
  final void Function(List<String>) onKeywordsChanged;
  final int maxKeywords;

  @override
  State<KeywordInput> createState() => _KeywordInputState();
}

class _KeywordInputState extends State<KeywordInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addKeyword(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;

    if (widget.keywords.length >= widget.maxKeywords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能輸入 ${widget.maxKeywords} 個關鍵字')),
      );
      return;
    }

    // Check for duplicates
    if (widget.keywords.contains(trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('這個關鍵字已經加入了')),
      );
      return;
    }

    // Check keyword length
    if (trimmed.length > GenerateStoryUseCase.maxKeywordLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('關鍵字不能超過 ${GenerateStoryUseCase.maxKeywordLength} 字'),
        ),
      );
      return;
    }

    widget.onKeywordsChanged([...widget.keywords, trimmed]);
    _textController.clear();
  }

  void _removeKeyword(String keyword) {
    final newKeywords = widget.keywords.where((k) => k != keyword).toList();
    widget.onKeywordsChanged(newKeywords);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddMore = widget.keywords.length < widget.maxKeywords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keyword chips
        if (widget.keywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.keywords.map((keyword) {
              return _KeywordChip(
                keyword: keyword,
                onRemove: () => _removeKeyword(keyword),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Input field
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: canAddMore,
          decoration: InputDecoration(
            hintText: canAddMore ? '輸入關鍵字，按 Enter 新增' : '已達關鍵字上限',
            prefixIcon: const Icon(Icons.label_outline),
            suffixIcon: canAddMore
                ? IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addKeyword(_textController.text),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            _addKeyword(value);
            _focusNode.requestFocus();
          },
        ),

        const SizedBox(height: 8),

        // Counter and hint
        Row(
          children: [
            Text(
              '${widget.keywords.length} / ${widget.maxKeywords} 個關鍵字',
              style: AppTextStyles.labelLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (widget.keywords.length < GenerateStoryUseCase.minKeywords)
              Text(
                '至少需要 ${GenerateStoryUseCase.minKeywords} 個',
                style: AppTextStyles.labelLarge.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chip widget for displaying a keyword with remove button.
class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.keyword,
    required this.onRemove,
  });

  final String keyword;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyword,
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested keywords section.
class SuggestedKeywords extends StatelessWidget {
  const SuggestedKeywords({
    required this.suggestions,
    required this.onKeywordTap,
    required this.selectedKeywords,
    super.key,
  });

  final List<String> suggestions;
  final void Function(String) onKeywordTap;
  final List<String> selectedKeywords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '推薦關鍵字',
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            final isSelected = selectedKeywords.contains(suggestion);

            return GestureDetector(
              onTap: isSelected ? null : () => onKeywordTap(suggestion),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.outline.withOpacity(0.3)
                        : theme.colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  suggestion,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
