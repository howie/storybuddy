# WebSocket Protocol: Interactive Story Mode

**Version**: 1.0.0
**Date**: 2026-01-10

## Overview

This document describes the WebSocket protocol for real-time audio streaming during interactive story mode.

## Connection

### Endpoint
```
wss://api.storybuddy.app/v1/ws/interaction/{sessionId}
```

### Authentication
Include JWT token in the connection URL as query parameter:
```
wss://api.storybuddy.app/v1/ws/interaction/{sessionId}?token={jwt_token}
```

### Connection Lifecycle
1. Client connects with valid session ID and token
2. Server sends `connection_established` message
3. Client can start sending audio data
4. Either party can close the connection

## Message Format

All messages are JSON except for audio data which is binary.

### Client → Server Messages

#### 1. Audio Data (Binary)
Raw binary data containing Opus-encoded audio frames.

**Format**: Binary (Opus 16kHz, mono, 20ms frames)

**Frequency**: Every 20ms during speech

---

#### 2. Control Messages (JSON)

##### Start Listening
Notify server that client is ready to receive speech.
```json
{
  "type": "start_listening",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### Stop Listening
Notify server that client stopped listening (e.g., app backgrounded).
```json
{
  "type": "stop_listening",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### Speech Started
Client detected speech activity.
```json
{
  "type": "speech_started",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### Speech Ended
Client detected end of speech (silence threshold reached).
```json
{
  "type": "speech_ended",
  "timestamp": "2026-01-10T12:00:00.000Z",
  "durationMs": 2500
}
```

##### Interrupt AI
Client wants to interrupt AI response (child started speaking).
```json
{
  "type": "interrupt_ai",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### Pause Session
```json
{
  "type": "pause_session",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### Resume Session
```json
{
  "type": "resume_session",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

##### End Session
```json
{
  "type": "end_session",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

---

### Server → Client Messages

#### 1. Connection Established
Sent immediately after successful connection.
```json
{
  "type": "connection_established",
  "sessionId": "uuid",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 2. Transcription Progress
Interim transcription results (real-time feedback).
```json
{
  "type": "transcription_progress",
  "text": "小兔子會不會...",
  "isFinal": false,
  "confidence": 0.85,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 3. Transcription Final
Final transcription result.
```json
{
  "type": "transcription_final",
  "text": "小兔子會不會遇到大野狼？",
  "confidence": 0.95,
  "segmentId": "uuid",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 4. AI Response Started
AI has started generating a response.
```json
{
  "type": "ai_response_started",
  "responseId": "uuid",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 5. AI Response Text
AI response text (for display).
```json
{
  "type": "ai_response_text",
  "responseId": "uuid",
  "text": "小兔子很勇敢喔！牠會小心地穿過森林...",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 6. AI Response Audio
TTS audio data URL or streaming chunks.
```json
{
  "type": "ai_response_audio",
  "responseId": "uuid",
  "audioUrl": "https://storage.example.com/audio/response-uuid.mp3",
  "durationMs": 3500,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

Or for streaming audio (binary follows):
```json
{
  "type": "ai_response_audio_stream",
  "responseId": "uuid",
  "chunkIndex": 0,
  "totalChunks": 10,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```
Followed by binary audio data.

#### 7. AI Response Completed
AI response playback should be complete.
```json
{
  "type": "ai_response_completed",
  "responseId": "uuid",
  "wasInterrupted": false,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 8. Resume Story
Signal to resume story playback.
```json
{
  "type": "resume_story",
  "resumePosition": 125.5,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 9. Session Status Changed
```json
{
  "type": "session_status_changed",
  "status": "paused",
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 10. Session Ended
```json
{
  "type": "session_ended",
  "transcriptId": "uuid",
  "turnCount": 5,
  "totalDurationMs": 180000,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

#### 11. Error
```json
{
  "type": "error",
  "code": "transcription_failed",
  "message": "Speech recognition service unavailable",
  "recoverable": true,
  "timestamp": "2026-01-10T12:00:00.000Z"
}
```

**Error Codes**:
| Code | Description | Recoverable |
|------|-------------|-------------|
| `transcription_failed` | Speech recognition error | Yes |
| `ai_response_failed` | AI generation error | Yes |
| `tts_failed` | TTS generation error | Yes |
| `session_expired` | Session timeout | No |
| `unauthorized` | Invalid token | No |
| `rate_limited` | Too many requests | Yes |

---

## Sequence Diagrams

### Normal Interaction Flow

```
Client                              Server
  │                                    │
  │─────── WebSocket Connect ─────────►│
  │◄───── connection_established ──────│
  │                                    │
  │─────── start_listening ───────────►│
  │                                    │
  │  [Child starts speaking]           │
  │─────── speech_started ────────────►│
  │═══════ audio (binary) ════════════►│
  │═══════ audio (binary) ════════════►│
  │◄───── transcription_progress ──────│
  │═══════ audio (binary) ════════════►│
  │◄───── transcription_progress ──────│
  │                                    │
  │  [Child stops speaking]            │
  │─────── speech_ended ──────────────►│
  │◄───── transcription_final ─────────│
  │                                    │
  │◄───── ai_response_started ─────────│
  │◄───── ai_response_text ────────────│
  │◄───── ai_response_audio ───────────│
  │                                    │
  │  [AI audio playback complete]      │
  │◄───── ai_response_completed ───────│
  │◄───── resume_story ────────────────│
  │                                    │
```

### Interruption Flow

```
Client                              Server
  │                                    │
  │  [AI is responding]                │
  │◄───── ai_response_audio ───────────│
  │                                    │
  │  [Child interrupts]                │
  │─────── interrupt_ai ──────────────►│
  │◄─── ai_response_completed ─────────│
  │      (wasInterrupted: true)        │
  │                                    │
  │─────── speech_started ────────────►│
  │═══════ audio (binary) ════════════►│
  │  [Continue with new speech...]     │
  │                                    │
```

---

## Error Handling

### Connection Errors
- If connection fails, client should retry with exponential backoff
- Max retries: 5
- Initial delay: 1 second
- Max delay: 30 seconds

### Message Errors
- If server returns `recoverable: true` error, client can retry the operation
- If `recoverable: false`, client should close connection and notify user

### Timeout
- Server will close idle connections after 60 seconds
- Client should send periodic ping messages (every 30 seconds)

---

## Rate Limits

| Operation | Limit |
|-----------|-------|
| Audio chunks | 50/second |
| Control messages | 10/second |
| Reconnections | 3/minute |

---

## Security Considerations

1. **Token Validation**: Server validates JWT on every connection
2. **Session Ownership**: Server verifies session belongs to authenticated user
3. **Audio Content**: Audio is not stored unless `recordingEnabled` is true
4. **TLS Required**: All WebSocket connections must use WSS (TLS)
