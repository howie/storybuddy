import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/voice_kit.dart';
import '../providers/voice_kit_provider.dart';

class VoiceSelectionPage extends ConsumerWidget {
  const VoiceSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(voiceListProvider);
    final selectedVoiceId = ref.watch(selectedVoiceIdProvider);
    final previewingVoiceId = ref.watch(voicePreviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇聲音'),
      ),
      body: voicesAsync.when(
        data: (voices) {
          if (voices.isEmpty) {
            return const Center(child: Text('沒有可用的聲音'));
          }
          return ListView.builder(
            itemCount: voices.length + 1, // +1 for footer
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index == voices.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Powered by Microsoft Azure Cognitive Services',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              }
              final voice = voices[index];
              final isSelected = voice.id == selectedVoiceId;
              final isPreviewing = voice.id == previewingVoiceId;

              return Card(
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.grey.shade200,
                    child: Icon(
                      voice.gender == Gender.female ? Icons.face_3 : Icons.face,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                  title: Text(
                    voice.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(voice.previewText ?? '點擊試聽'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isPreviewing
                              ? Icons.stop_circle
                              : Icons.play_circle_fill,
                          color: isPreviewing
                              ? Colors.red
                              : Theme.of(context).primaryColor,
                          size: 32,
                        ),
                        onPressed: () {
                          if (isPreviewing) {
                            ref.read(voicePreviewProvider.notifier).stop();
                          } else {
                            // Construct preview URL
                            // Assuming base URL logic needed or full URL returned
                            // Just passing raw URL for now or constructing relative
                            // Use local preview implementation or call provider
                            // For now assuming backend returns absolute or relative path that just_audio handles
                            // But wait, backend returns audio bytes for preview endpoint usually?
                            // No, GET /api/voices/{id}/preview returns bytes directly.
                            // AudioPlayer needs a URL.
                            // We should construct the URL: BASE_URL/api/voices/{id}/preview

                            // Hack: Get API Host from config (not avail here easily) or hardcode relative
                            // But AudioPlayer needs absolute URL usually
                            // pass: "http://localhost:8000/api/voices/${voice.id}/preview"
                            // In real app need config.

                            final url =
                                'http://10.0.2.2:8000/api/voices/${voice.id}/preview'; // Android emulator
                            // For now let's use a placeholder or assume config is available
                            ref
                                .read(voicePreviewProvider.notifier)
                                .playPreview(url, voice.id);
                          }
                        },
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  onTap: () {
                    ref.read(selectedVoiceIdProvider.notifier).state = voice.id;
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: selectedVoiceId == null
              ? null
              : () {
                  // Confirm selection
                  context.pop(selectedVoiceId);
                },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('確認選擇'),
        ),
      ),
    );
  }
}
