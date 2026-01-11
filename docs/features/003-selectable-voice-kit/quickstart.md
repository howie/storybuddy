# Quickstart: Selectable Voice Kit

**Feature**: 003-selectable-voice-kit
**Date**: 2026-01-05

## Prerequisites

1. **Azure Account** with Cognitive Services Speech resource
2. **Python 3.11+** with dependencies installed
3. **StoryBuddy backend** running (from 000-StoryBuddy-mvp)

## Environment Setup

### 1. Azure Cognitive Services Speech

1. Create a Speech resource at [portal.azure.com](https://portal.azure.com)
2. Get your **Key** and **Region** (e.g., `eastus`)

### 2. Environment Variables

Add to your `.env` file:

```bash
# Azure Speech Service
AZURE_SPEECH_KEY=your_key_here
AZURE_SPEECH_REGION=eastus

# Optional: ElevenLabs (for premium character voices)
ELEVENLABS_API_KEY=your_key_here
```

### 3. Install Dependencies

```bash
pip install azure-cognitiveservices-speech
```

## Quick Integration Guide

### Backend: Generate Speech with Azure TTS

```python
import azure.cognitiveservices.speech as speechsdk

def synthesize_speech(text: str, voice_id: str = "zh-TW-HsiaoChenNeural") -> bytes:
    """Convert text to speech audio using Azure TTS."""
    speech_config = speechsdk.SpeechConfig(
        subscription=os.getenv("AZURE_SPEECH_KEY"),
        region=os.getenv("AZURE_SPEECH_REGION")
    )
    
    # Set synthesis voice
    speech_config.speech_synthesis_voice_name = voice_id
    
    # Output to memory (bytes)
    synthesizer = speechsdk.SpeechSynthesizer(speech_config=speech_config, audio_config=None)
    
    result = synthesizer.speak_text_async(text).get()
    
    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_data
    else:
         raise RuntimeError(f"Speech synthesis canceled: {result.cancellation_details.reason}")

# Usage
# audio_data = synthesize_speech("大家好，我是故事姐姐！")
# with open("output.mp3", "wb") as f:
#     f.write(audio_data)
```

### Backend: Use SSML for Character Voices (Simulated)

```python
from src.services.tts.ssml_utils import create_ssml

# Use the installed Azure provider which handles SSML
# See src/services/tts/azure_tts.py for implementation details
```

### Flutter: Voice Selection UI

```dart
// lib/models/voice_character.dart
class VoiceCharacter {
  final String id;
  final String name;
  final String gender;
  final String ageGroup;
  final String previewUrl;

  VoiceCharacter({
    required this.id,
    required this.name,
    required this.gender,
    required this.ageGroup,
    required this.previewUrl,
  });

  factory VoiceCharacter.fromJson(Map<String, dynamic> json) {
    return VoiceCharacter(
      id: json['id'],
      name: json['name'],
      gender: json['gender'],
      ageGroup: json['age_group'],
      previewUrl: json['preview_url'],
    );
  }
}
```

```dart
// lib/services/voice_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceService {
  final String baseUrl;

  VoiceService({required this.baseUrl});

  Future<List<VoiceCharacter>> getVoices() async {
    final response = await http.get(Uri.parse('$baseUrl/api/voices'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['voices'] as List)
          .map((v) => VoiceCharacter.fromJson(v))
          .toList();
    }
    throw Exception('Failed to load voices');
  }

  Future<void> setDefaultVoice(String userId, String voiceId) async {
    await http.put(
      Uri.parse('$baseUrl/api/users/$userId/voice-preference'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'default_voice_id': voiceId}),
    );
  }
}
```

```dart
// lib/screens/voice_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceSelectionScreen extends StatefulWidget {
  @override
  _VoiceSelectionScreenState createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> {
  final _player = AudioPlayer();
  String? _selectedVoiceId;
  List<VoiceCharacter> _voices = [];

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voiceService = VoiceService(baseUrl: 'http://localhost:8000');
    final voices = await voiceService.getVoices();
    setState(() => _voices = voices);
  }

  Future<void> _playPreview(String previewUrl) async {
    await _player.setUrl(previewUrl);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('選擇聲音')),
      body: ListView.builder(
        itemCount: _voices.length,
        itemBuilder: (context, index) {
          final voice = _voices[index];
          return ListTile(
            leading: _getAvatarIcon(voice),
            title: Text(voice.name),
            subtitle: Text(_getDescription(voice)),
            trailing: IconButton(
              icon: Icon(Icons.play_circle_outline),
              onPressed: () => _playPreview(voice.previewUrl),
            ),
            selected: _selectedVoiceId == voice.id,
            onTap: () => setState(() => _selectedVoiceId = voice.id),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.check),
        onPressed: _selectedVoiceId != null
            ? () => _confirmSelection()
            : null,
      ),
    );
  }

  Icon _getAvatarIcon(VoiceCharacter voice) {
    if (voice.ageGroup == 'child') {
      return Icon(Icons.child_care);
    } else if (voice.ageGroup == 'senior') {
      return Icon(Icons.elderly);
    }
    return Icon(Icons.person);
  }

  String _getDescription(VoiceCharacter voice) {
    final genderText = voice.gender == 'female' ? '女性' : '男性';
    final ageText = {
      'child': '兒童',
      'adult': '成人',
      'senior': '長者',
    }[voice.ageGroup] ?? '';
    return '$ageText $genderText';
  }

  void _confirmSelection() {
    // Save selection and navigate back
    Navigator.pop(context, _selectedVoiceId);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
```

## API Usage Examples

### List Available Voices

```bash
curl http://localhost:8000/api/voices
```

Response:
```json
{
  "voices": [
    {
      "id": "narrator-female",
      "name": "故事姐姐",
      "gender": "female",
      "age_group": "adult",
      "style": "narrator",
      "preview_url": "/api/voices/narrator-female/preview"
    },
    {
      "id": "child-girl",
      "name": "小美",
      "gender": "female",
      "age_group": "child",
      "style": "character"
    }
  ],
  "total": 6
}
```

### Get Voice Preview

```bash
curl http://localhost:8000/api/voices/narrator-female/preview -o preview.mp3
```

### Generate Story Audio

```bash
curl -X POST http://localhost:8000/api/stories/story-123/generate-audio \
  -H "Content-Type: application/json" \
  -d '{"voice_id": "narrator-female"}' \
  -o story.mp3
```

### Set User Preference

```bash
curl -X PUT http://localhost:8000/api/users/user-123/voice-preference \
  -H "Content-Type: application/json" \
  -d '{"default_voice_id": "child-girl"}'
```

## Testing

### Unit Test Example

```python
# tests/unit/services/test_voice_kit_service.py
import pytest
from unittest.mock import Mock, patch
from src.services.voice_kit_service import VoiceKitService

class TestVoiceKitService:
    def test_get_builtin_voices_returns_six_voices(self):
        service = VoiceKitService()
        voices = service.get_builtin_voices()
        assert len(voices) == 6

    def test_get_voice_by_id_returns_correct_voice(self):
        service = VoiceKitService()
        voice = service.get_voice("narrator-female")
        assert voice.name == "故事姐姐"
        assert voice.gender == "female"

    def test_get_voice_by_invalid_id_raises_not_found(self):
        service = VoiceKitService()
        with pytest.raises(ValueError):
            service.get_voice("invalid-id")
```

### Integration Test Example

```python
# tests/integration/test_google_tts.py
import pytest
import os
from src.services.tts.google_tts import GoogleTTSProvider

@pytest.mark.skipif(
    not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
    reason="Google credentials not configured"
)
class TestGoogleTTSIntegration:
    @pytest.fixture
    def provider(self):
        return GoogleTTSProvider()

    async def test_synthesize_returns_audio_data(self, provider):
        audio = await provider.synthesize(
            text="測試語音",
            voice_id="cmn-TW-Wavenet-A"
        )
        assert len(audio) > 0
        # Check MP3 magic bytes
        assert audio[:3] == b'\xff\xfb\x90' or audio[:3] == b'ID3'

    async def test_synthesize_with_ssml_options_works(self, provider):
        audio = await provider.synthesize(
            text="小女孩聲音測試",
            voice_id="cmn-TW-Wavenet-A",
            options={"pitch": "+4st", "rate": "1.05"}
        )
        assert len(audio) > 0
```

## Troubleshooting

### Common Issues

**1. Google Cloud authentication error**
```
google.auth.exceptions.DefaultCredentialsError
```
Solution: Ensure `GOOGLE_APPLICATION_CREDENTIALS` points to a valid JSON key file and the file exists.

**2. Voice not found**
```
400 Invalid voice name
```
Solution: Use one of the supported voices:
- `cmn-TW-Wavenet-A` (Female)
- `cmn-TW-Wavenet-B` (Male)
- `cmn-TW-Wavenet-C` (Male)

**3. SSML parsing error**
```
400 SSML is not well-formed
```
Solution: Ensure text doesn't contain XML special characters. Escape `<`, `>`, `&` as `&lt;`, `&gt;`, `&amp;`.

**4. Quota exceeded**
```
429 Quota exceeded
```
Solution: Check Google Cloud Console billing/quotas. WaveNet voices have stricter limits than Standard voices.

## Next Steps

1. Run `/speckit.tasks` to generate implementation tasks
2. Implement TTS provider abstraction
3. Add voice selection UI to Flutter app
4. Test with real stories
