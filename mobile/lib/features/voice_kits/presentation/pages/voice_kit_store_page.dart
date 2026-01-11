import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_kit_provider.dart';
import '../../../../models/voice_kit.dart';

class VoiceKitStorePage extends ConsumerWidget {
  const VoiceKitStorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitsAsync = ref.watch(voiceKitsProvider);
    final downloadState = ref.watch(downloadKitControllerProvider);

    // Listen for errors/success
    ref.listen(downloadKitControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (err, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下載失敗: $err'), backgroundColor: Colors.red),
          );
        },
        data: (_) {
          if (previous?.isLoading == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('下載成功！'), backgroundColor: Colors.green),
            );
            // Refresh list to update status
            ref.refresh(voiceKitsProvider);
            ref.refresh(voiceListProvider); // Also refresh voices list
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('聲音商店'),
      ),
      body: kitsAsync.when(
        data: (kits) {
          if (kits.isEmpty) {
            return const Center(child: Text('暫無可用聲音包'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: kits.length,
            itemBuilder: (context, index) {
              final kit = kits[index];
              final isDownloading = downloadState
                  .isLoading; // Simplified global loading, ideally per-item

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(kit.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kit.description ?? kit.version),
                      const SizedBox(height: 4),
                      Text('Provider: ${kit.provider}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  trailing: kit.isDownloaded
                      ? const Chip(
                          label: Text('已安裝',
                              style: TextStyle(color: Colors.green)),
                          backgroundColor: Colors.white,
                          avatar:
                              Icon(Icons.check, size: 16, color: Colors.green),
                        )
                      : ElevatedButton(
                          onPressed: isDownloading
                              ? null
                              : () {
                                  ref
                                      .read(downloadKitControllerProvider
                                          .notifier)
                                      .downloadKit(kit.id);
                                },
                          child: isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('下載'),
                        ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
