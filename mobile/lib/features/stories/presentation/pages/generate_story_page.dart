import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../auth/presentation/providers/parent_provider.dart';
import '../../domain/entities/story.dart';
import '../../domain/usecases/generate_story.dart';
import '../providers/story_provider.dart';
import '../widgets/keyword_input.dart';

/// Page for generating a story using AI from keywords.
class GenerateStoryPage extends ConsumerStatefulWidget {
  const GenerateStoryPage({super.key});

  @override
  ConsumerState<GenerateStoryPage> createState() => _GenerateStoryPageState();
}

class _GenerateStoryPageState extends ConsumerState<GenerateStoryPage> {
  List<String> _keywords = [];
  Story? _generatedStory;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _errorMessage;

  static const _suggestedKeywords = [
    '冒險',
    '友誼',
    '勇氣',
    '動物',
    '魔法',
    '公主',
    '恐龍',
    '太空',
    '森林',
    '海洋',
  ];

  bool get _canGenerate =>
      _keywords.length >= GenerateStoryUseCase.minKeywords &&
      _keywords.length <= GenerateStoryUseCase.maxKeywords &&
      !_isGenerating;

  Future<void> _generateStory() async {
    if (!_canGenerate) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedStory = null;
    });

    try {
      // Get the current parent ID
      final parent = await ref.read(currentParentProvider.future);
      if (parent == null) {
        throw Exception('請先設定家長資料');
      }

      final story =
          await ref.read(storyListNotifierProvider.notifier).generateStory(
                parentId: parent.id,
                keywords: _keywords,
              );

      setState(() {
        _generatedStory = story;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveStory() async {
    if (_generatedStory == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Story is already saved when generated, just navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('故事已儲存')),
        );
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 生成故事'),
      ),
      body: _generatedStory != null
          ? _buildPreviewContent()
          : _buildInputContent(),
    );
  }

  Widget _buildInputContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Error banner
        if (_errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 16),
        ],

        // Instructions
        _buildInstructions(),
        const SizedBox(height: 24),

        // Keyword input
        const Text(
          '輸入關鍵字',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 8),
        KeywordInput(
          keywords: _keywords,
          onKeywordsChanged: (keywords) {
            setState(() {
              _keywords = keywords;
            });
          },
        ),
        const SizedBox(height: 24),

        // Suggested keywords
        SuggestedKeywords(
          suggestions: _suggestedKeywords,
          selectedKeywords: _keywords,
          onKeywordTap: (keyword) {
            if (_keywords.length < GenerateStoryUseCase.maxKeywords) {
              setState(() {
                _keywords = [..._keywords, keyword];
              });
            }
          },
        ),
        const SizedBox(height: 32),

        // Generate button
        FilledButton.icon(
          onPressed: _canGenerate ? _generateStory : null,
          icon: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_isGenerating ? '生成中...' : '生成故事'),
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Story preview
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              Text(
                _generatedStory!.title,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 8),

              // Keywords
              Wrap(
                spacing: 8,
                children: _generatedStory!.keywords?.map((k) {
                      return Chip(
                        label: Text(k),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      );
                    }).toList() ??
                    [],
              ),
              const SizedBox(height: 16),

              // Content
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _generatedStory!.content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Meta info
              Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_generatedStory!.wordCount} 字',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '約 ${_generatedStory!.estimatedDurationMinutes} 分鐘',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Regenerate button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating || _isSaving
                        ? null
                        : () {
                            setState(() {
                              _generatedStory = null;
                            });
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                  ),
                ),
                const SizedBox(width: 16),

                // Save button
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveStory,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? '儲存中...' : '儲存故事'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: theme.colorScheme.onErrorContainer,
            ),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '讓 AI 為您創作故事',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '輸入 1-5 個關鍵字，AI 會根據這些主題創作一個獨特的故事',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
