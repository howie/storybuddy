# Research: Interactive Story Mode

**Date**: 2026-01-10
**Feature**: 006-interactive-story-mode

## Research Tasks

Based on Technical Context unknowns and dependencies from the plan.

---

## 1. WebSocket Real-time Audio Streaming

### Research Question
如何在 FastAPI (Python) 和 Flutter 之間實現即時雙向音訊串流？

### Decision: FastAPI WebSocket + web_socket_channel (Flutter)

### Rationale
- FastAPI 原生支援 WebSocket，與現有架構一致
- Flutter `web_socket_channel` 套件成熟穩定，支援二進位資料傳輸
- 相比 gRPC，WebSocket 更簡單且足以滿足單一家庭使用的 MVP 需求

### Implementation Pattern

**Backend (FastAPI)**:
```python
from fastapi import WebSocket
from fastapi.websockets import WebSocketDisconnect

@app.websocket("/ws/interaction/{session_id}")
async def interaction_websocket(websocket: WebSocket, session_id: str):
    await websocket.accept()
    try:
        while True:
            # Receive audio chunk (binary)
            audio_data = await websocket.receive_bytes()
            # Process and respond
            response = await process_audio(audio_data, session_id)
            await websocket.send_json(response)
    except WebSocketDisconnect:
        await cleanup_session(session_id)
```

**Frontend (Flutter)**:
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('wss://api.example.com/ws/interaction/$sessionId'),
);

// Send audio
channel.sink.add(audioBytes);

// Receive responses
channel.stream.listen((message) {
  final response = jsonDecode(message);
  // Handle AI response
});
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| gRPC Streaming | 增加複雜度，需額外 protobuf 設定，MVP 不需要 |
| Socket.IO | 額外依賴，WebSocket 已足夠 |
| HTTP Long Polling | 延遲過高，不符合 3 秒回應目標 |

---

## 2. Google Speech-to-Text Streaming API

### Research Question
如何使用 Google Speech-to-Text 進行即時語音辨識，支援 Opus 編碼？

### Decision: google-cloud-speech Python SDK with streaming_recognize

### Rationale
- Google STT 支援 Opus 編碼的即時串流辨識
- 支援繁體中文 (zh-TW)
- 提供 interim results（中間結果），可即時顯示辨識進度
- 成本合理：$0.006/15 秒（標準模式）

### Implementation Pattern

```python
from google.cloud import speech

client = speech.SpeechClient()

config = speech.RecognitionConfig(
    encoding=speech.RecognitionConfig.AudioEncoding.OGG_OPUS,
    sample_rate_hertz=16000,
    language_code="zh-TW",
    enable_automatic_punctuation=True,
)

streaming_config = speech.StreamingRecognitionConfig(
    config=config,
    interim_results=True,
)

def request_generator(audio_stream):
    yield speech.StreamingRecognizeRequest(streaming_config=streaming_config)
    for chunk in audio_stream:
        yield speech.StreamingRecognizeRequest(audio_content=chunk)

responses = client.streaming_recognize(request_generator(audio_stream))

for response in responses:
    for result in response.results:
        if result.is_final:
            yield result.alternatives[0].transcript
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Azure Speech-to-Text | 專案已使用 Google Cloud，保持一致性 |
| Whisper (OpenAI) | 非即時串流，延遲過高 |
| Deepgram | 額外整合成本，Google 已足夠 |

---

## 3. Opus Audio Encoding in Flutter

### Research Question
Flutter 如何錄製並編碼 Opus 16kHz 音訊進行即時串流？

### Decision: record 套件 + opus_flutter 編碼

### Rationale
- `record` 套件已在專案中使用，支援多種輸出格式
- `opus_flutter` 提供原生 Opus 編碼支援
- 16kHz 採樣率對語音辨識足夠，且頻寬友好

### Implementation Pattern

```dart
import 'package:record/record.dart';
import 'package:opus_flutter/opus_flutter.dart';

class AudioStreamer {
  final _recorder = AudioRecorder();
  final _opus = OpusEncoder(
    sampleRate: 16000,
    channels: 1,
    application: Application.voip,
  );

  Stream<Uint8List> startStreaming() async* {
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    await for (final pcmChunk in _recorder.onAmplitudeChanged) {
      final opusFrame = _opus.encode(pcmChunk);
      yield opusFrame;
    }
  }
}
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| 直接傳送 PCM | 頻寬消耗過高 (256 kbps vs 20-40 kbps) |
| AAC 編碼 | 延遲較高，不適合即時語音 |
| WebM/Opus 容器 | 增加解析複雜度，裸 Opus 幀更簡單 |

---

## 4. Voice Activity Detection (VAD)

### Research Question
如何準確偵測使用者是否在說話，避免環境噪音誤觸發？

### Decision: WebRTC VAD (py-webrtcvad) + 本地振幅預過濾

### Rationale
- WebRTC VAD 是業界標準，準確率高
- 支援三種敏感度級別（0-3）
- 可在客戶端預過濾，減少不必要的網路傳輸

### Implementation Pattern

**Backend (Python)**:
```python
import webrtcvad

vad = webrtcvad.Vad(2)  # Mode 2: balanced

def is_speech(audio_frame: bytes, sample_rate: int = 16000) -> bool:
    """
    audio_frame: 10, 20, or 30 ms of audio at 16kHz
    """
    return vad.is_speech(audio_frame, sample_rate)

def process_audio_stream(audio_chunks):
    speech_buffer = []
    silence_count = 0
    SILENCE_THRESHOLD = 15  # ~1.5 seconds at 100ms chunks

    for chunk in audio_chunks:
        if is_speech(chunk):
            speech_buffer.append(chunk)
            silence_count = 0
        else:
            silence_count += 1
            if speech_buffer and silence_count >= SILENCE_THRESHOLD:
                yield b''.join(speech_buffer)
                speech_buffer = []
```

**Frontend (Flutter) - 振幅預過濾**:
```dart
class VadService {
  double _noiseFloor = -50.0; // dB, 校準後更新

  bool isLikelySpeech(double amplitudeDb) {
    return amplitudeDb > _noiseFloor + 10; // 高於噪音底線 10dB
  }

  void calibrate(List<double> samples) {
    _noiseFloor = samples.reduce((a, b) => a + b) / samples.length;
  }
}
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Silero VAD | 更精確但需額外 ML 模型載入 |
| 純振幅閾值 | 準確率不足，易受環境影響 |
| Google VAD API | 增加延遲，本地處理更快 |

---

## 5. Automatic Noise Calibration

### Research Question
如何在互動模式開始前自動校準環境噪音，動態調整偵測閾值？

### Decision: 2-3 秒採樣 + 百分位數計算

### Rationale
- 簡單有效，無需複雜 ML 模型
- 可整合在「準備中」UI 動畫期間
- 使用 90th 百分位數作為噪音底線，比平均值更穩健

### Implementation Pattern

```dart
class NoiseCalibration {
  static const int calibrationDurationMs = 2500;
  static const int sampleIntervalMs = 50;

  Future<double> calibrate(Stream<double> amplitudeStream) async {
    final samples = <double>[];
    final completer = Completer<double>();

    final timer = Timer(
      Duration(milliseconds: calibrationDurationMs),
      () {
        samples.sort();
        // 90th percentile as noise floor
        final percentile90Index = (samples.length * 0.9).floor();
        final noiseFloor = samples[percentile90Index];
        completer.complete(noiseFloor);
      },
    );

    final subscription = amplitudeStream.listen((amplitude) {
      samples.add(amplitude);
    });

    final result = await completer.future;
    await subscription.cancel();
    timer.cancel();

    return result;
  }
}
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| 固定閾值 | 無法適應不同環境 |
| 持續動態調整 | 可能在說話時錯誤調整閾值 |
| ML 噪音模型 | MVP 階段過於複雜 |

---

## 6. Safe AI Response Generation

### Research Question
如何確保 AI 回應限制在兒童安全的對話範圍內？

### Decision: Claude API with constrained system prompt + content filtering

### Rationale
- Claude 已在專案中使用
- System prompt 可嚴格限制回應範圍
- 可加入雙重檢查：回應前過濾敏感內容

### Implementation Pattern

```python
STORY_INTERACTION_SYSTEM_PROMPT = """
你是一個故事中的友善角色或旁白，正在與一個小朋友互動。

## 嚴格規則
1. 只回應與故事相關的問題
2. 使用適合 3-8 歲兒童的簡單語言
3. 保持友善、正面、鼓勵的語調
4. 如果問題與故事無關，溫和地把話題帶回故事
5. 絕對不提及暴力、恐怖、成人主題
6. 回應長度控制在 2-3 句話

## 當前故事上下文
{story_context}

## 當前故事角色
{character_name}: {character_description}
"""

async def generate_safe_response(
    user_input: str,
    story_context: str,
    character_name: str,
) -> str:
    response = await claude_client.messages.create(
        model="claude-3-haiku-20240307",  # 快速回應
        max_tokens=150,
        system=STORY_INTERACTION_SYSTEM_PROMPT.format(
            story_context=story_context,
            character_name=character_name,
            character_description=get_character_description(character_name),
        ),
        messages=[{"role": "user", "content": user_input}],
    )

    # 二次過濾確保安全
    filtered = content_filter(response.content[0].text)
    return filtered
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| GPT-4 | 回應較慢，成本較高 |
| 本地 LLM | 需要較大資源，MVP 不適合 |
| 規則式回應 | 缺乏彈性，體驗較差 |

---

## 7. HTML Email Template for Transcripts

### Research Question
互動紀錄郵件應使用什麼格式和樣式？

### Decision: Jinja2 HTML template with inline CSS

### Rationale
- HTML 郵件支援視覺化呈現（對話氣泡、頭像）
- 使用 inline CSS 確保郵件客戶端相容性
- Jinja2 已在 Python 生態系廣泛使用

### Implementation Pattern

```html
<!-- transcript_email.html -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>StoryBuddy 互動紀錄</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h1 style="color: #4A90D9;">{{ story_title }} - 互動紀錄</h1>
  <p style="color: #666;">{{ session_date }}</p>

  <div style="margin: 20px 0;">
    {% for turn in conversation %}
    <div style="margin: 10px 0; display: flex;
                flex-direction: {{ 'row-reverse' if turn.speaker == 'child' else 'row' }};">
      <img src="{{ turn.avatar_url }}"
           style="width: 40px; height: 40px; border-radius: 50%;" />
      <div style="background: {{ '#E3F2FD' if turn.speaker == 'child' else '#F5F5F5' }};
                  padding: 10px 15px; border-radius: 15px; max-width: 70%;">
        <strong>{{ turn.speaker_name }}</strong>
        <p style="margin: 5px 0;">{{ turn.text }}</p>
        <small style="color: #999;">{{ turn.timestamp }}</small>
      </div>
    </div>
    {% endfor %}
  </div>

  <footer style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
    <p style="color: #999; font-size: 12px;">
      此紀錄由 StoryBuddy 自動產生。
    </p>
  </footer>
</body>
</html>
```

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| 純文字郵件 | 視覺效果差，不符合規格要求 |
| PDF 附件 | 增加複雜度，開啟不便 |
| React Email | 過度工程化，Jinja2 足夠 |

---

## Summary of Decisions

| Research Topic | Decision | Key Dependencies |
|----------------|----------|------------------|
| Real-time Streaming | FastAPI WebSocket + web_socket_channel | `fastapi`, `web_socket_channel` |
| Speech Recognition | Google Speech-to-Text Streaming | `google-cloud-speech` |
| Audio Encoding | Opus 16kHz via opus_flutter | `record`, `opus_flutter` |
| Voice Activity Detection | WebRTC VAD + amplitude pre-filter | `webrtcvad`, `record` |
| Noise Calibration | 2-3 sec sampling + percentile | Custom implementation |
| AI Response | Claude Haiku with constrained prompt | `anthropic` |
| Email Template | Jinja2 HTML with inline CSS | `jinja2` |

All research items resolved. Ready for Phase 1: Design & Contracts.
