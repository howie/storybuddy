import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/voice_kit.dart';
import '../../data/repositories/voice_kit_repository_impl.dart';

import 'package:just_audio/just_audio.dart';

// -- Voice List Provider --
final voiceListProvider = FutureProvider<List<VoiceCharacter>>((ref) async {
  final repository = ref.watch(voiceKitRepositoryProvider);
  return repository.getVoices();
});

// -- Selected Voice State --
final selectedVoiceIdProvider = StateProvider<String?>((ref) => null);

// -- Voice Preview Notifier --
class VoicePreviewNotifier extends StateNotifier<String?> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  VoicePreviewNotifier() : super(null);

  Future<void> playPreview(String? url, String voiceId) async {
    if (url == null) return;
    
    try {
      state = voiceId; // Set current playing voice ID to update UI
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      
      // Reset state when finished
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          state = null;
        }
      });
    } catch (e) {
      state = null;
      print("Error playing preview: $e");
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    state = null;
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

final voicePreviewProvider = StateNotifierProvider<VoicePreviewNotifier, String?>((ref) {
  return VoicePreviewNotifier();
});
