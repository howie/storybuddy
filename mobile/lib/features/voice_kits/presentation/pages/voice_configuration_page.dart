import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybuddy/features/auth/presentation/providers/parent_provider.dart';
import 'package:storybuddy/features/voice_kits/presentation/providers/voice_kit_provider.dart';
import 'package:storybuddy/models/voice_kit.dart';

class VoiceConfigurationPage extends ConsumerWidget {
  const VoiceConfigurationPage({required this.storyId, super.key});
  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentNotifierProvider);
    final userId = parentState.value?.id;

    if (userId == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator()), // Or error/login prompt
      );
    }

    final voiceKitsAsync = ref.watch(voiceKitsProvider);
    final mappingsAsync = ref.watch(
      storyVoiceMappingsProvider(
        StoryVoiceMappingParams(userId, storyId),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Settings'),
      ),
      body: voiceKitsAsync.when(
        data: (kits) {
          // Aggregate all voices
          final allVoices = <VoiceCharacter>[];
          for (final kit in kits) {
            allVoices.addAll(kit.voices);
          }

          return mappingsAsync.when(
            data: (mappings) {
              // Convert list of mappings to a map for easy lookup
              final mappingMap = <String, String>{}; // role -> voiceId
              for (final m in mappings) {
                // Backend returns dict with keys: role, voice_id
                mappingMap[m['role'] as String] = m['voice_id'] as String;
              }

              // Mock roles for now
              final roles = ['Narrator', 'Character 1'];

              return ListView.builder(
                itemCount: roles.length,
                itemBuilder: (context, index) {
                  final role = roles[index];
                  final currentVoiceId = mappingMap[role]; // Defaults to null?

                  return ListTile(
                    title: Text(role),
                    subtitle: Text(
                      currentVoiceId != null
                          ? allVoices
                              .firstWhere(
                                (v) => v.id == currentVoiceId,
                                orElse: () => VoiceCharacter(
                                  id: 'unknown',
                                  kitId: 'unknown',
                                  name: 'Unknown Voice',
                                  providerVoiceId: '',
                                  gender: 'unknown',
                                  ageGroup: 'unknown',
                                  style: 'unknown',
                                ),
                              )
                              .name
                          : 'Default',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      _showVoiceSelectionDialog(
                        context,
                        ref,
                        userId,
                        storyId,
                        role,
                        allVoices,
                        currentVoiceId,
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading voices: $e')),
      ),
    );
  }

  void _showVoiceSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String storyId,
    String role,
    List<VoiceCharacter> voices,
    String? currentVoiceId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: voices.length,
          itemBuilder: (context, index) {
            final voice = voices[index];
            final isSelected = voice.id == currentVoiceId;

            return ListTile(
              title: Text(voice.name),
              subtitle: Text('${voice.gender} • ${voice.ageGroup}'),
              selected: isSelected,
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.pop(context); // Close dialog
                // Update mapping
                await ref
                    .read(storyVoiceMapControllerProvider.notifier)
                    .updateMapping(
                      userId,
                      storyId,
                      role,
                      voice.id,
                    );
                // Refresh mappings
                ref.refresh(
                  storyVoiceMappingsProvider(
                    StoryVoiceMappingParams(userId, storyId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
