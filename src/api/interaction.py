"""WebSocket API for Interactive Story Mode.

T032 [US1] Implement WebSocket endpoint for interaction.
T033 [US1] Add WebSocket message handlers.
T053 [US2] Integrate AI responder with WebSocket handler.

Provides real-time bidirectional communication for:
- Audio streaming from client
- Speech detection events
- Transcription results
- AI responses
"""

import asyncio
import json
from datetime import datetime
from typing import Optional, Dict, Any, List
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, HTTPException
from fastapi.websockets import WebSocketState

from src.services.interaction.session_manager import SessionManager, SessionState
from src.services.interaction.ai_responder import (
    AIResponder,
    ResponseContext,
    TriggerType,
    AIResponse,
)
from src.models.enums import SessionMode, SessionStatus

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/ws", tags=["interaction"])

# Global service instances
_session_manager: Optional[SessionManager] = None
_ai_responder: Optional[AIResponder] = None

# Session context storage for AI responses
_session_contexts: Dict[str, Dict[str, Any]] = {}


def get_session_manager() -> SessionManager:
    """Get or create the global session manager."""
    global _session_manager
    if _session_manager is None:
        _session_manager = SessionManager()
    return _session_manager


def get_ai_responder() -> AIResponder:
    """Get or create the global AI responder."""
    global _ai_responder
    if _ai_responder is None:
        _ai_responder = AIResponder()
    return _ai_responder


def get_session_context(session_id: str) -> Dict[str, Any]:
    """Get or create session context for AI responses."""
    if session_id not in _session_contexts:
        _session_contexts[session_id] = {
            "story_id": "",
            "story_title": "",
            "story_synopsis": "",
            "characters": [],
            "current_scene": "",
            "conversation_history": [],
        }
    return _session_contexts[session_id]


def update_session_context(
    session_id: str,
    story_id: Optional[str] = None,
    story_title: Optional[str] = None,
    story_synopsis: Optional[str] = None,
    characters: Optional[List[str]] = None,
    current_scene: Optional[str] = None,
) -> None:
    """Update session context with story information."""
    context = get_session_context(session_id)
    if story_id is not None:
        context["story_id"] = story_id
    if story_title is not None:
        context["story_title"] = story_title
    if story_synopsis is not None:
        context["story_synopsis"] = story_synopsis
    if characters is not None:
        context["characters"] = characters
    if current_scene is not None:
        context["current_scene"] = current_scene


def add_conversation_turn(session_id: str, role: str, text: str) -> None:
    """Add a conversation turn to session history."""
    context = get_session_context(session_id)
    context["conversation_history"].append({"role": role, "text": text})
    # Keep only last 10 turns
    if len(context["conversation_history"]) > 10:
        context["conversation_history"] = context["conversation_history"][-10:]


def cleanup_session_context(session_id: str) -> None:
    """Remove session context when session ends."""
    if session_id in _session_contexts:
        del _session_contexts[session_id]


class WebSocketConnection:
    """Manages a single WebSocket connection for an interaction session."""

    def __init__(self, websocket: WebSocket, session_id: str, token: str):
        """Initialize connection.

        Args:
            websocket: The WebSocket connection.
            session_id: Session ID for this connection.
            token: JWT token for authentication.
        """
        self.websocket = websocket
        self.session_id = session_id
        self.token = token
        self.is_connected = False
        self._last_activity = datetime.utcnow()
        self._heartbeat_task: Optional[asyncio.Task] = None

    async def accept(self) -> None:
        """Accept the WebSocket connection."""
        await self.websocket.accept()
        self.is_connected = True
        self._last_activity = datetime.utcnow()

    async def send_json(self, data: Dict[str, Any]) -> None:
        """Send JSON message to client."""
        if self.is_connected:
            await self.websocket.send_json(data)
            self._last_activity = datetime.utcnow()

    async def send_bytes(self, data: bytes) -> None:
        """Send binary data to client."""
        if self.is_connected:
            await self.websocket.send_bytes(data)
            self._last_activity = datetime.utcnow()

    async def close(self, code: int = 1000, reason: str = "") -> None:
        """Close the WebSocket connection."""
        if self.is_connected:
            try:
                await self.websocket.close(code, reason)
            except Exception:
                pass
            self.is_connected = False

        if self._heartbeat_task:
            self._heartbeat_task.cancel()

    def start_heartbeat(self) -> None:
        """Start heartbeat monitoring (T096-B: 60s idle timeout)."""
        self._heartbeat_task = asyncio.create_task(self._heartbeat_loop())

    async def _heartbeat_loop(self) -> None:
        """Monitor for idle connections."""
        while self.is_connected:
            await asyncio.sleep(30)  # Check every 30 seconds
            elapsed = (datetime.utcnow() - self._last_activity).total_seconds()
            if elapsed > 60:  # 60 second timeout
                logger.warning(f"Connection timeout for session {self.session_id}")
                await self.send_json({
                    "type": "error",
                    "code": "session_expired",
                    "message": "Connection timed out due to inactivity",
                    "recoverable": False,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                })
                await self.close(1000, "Idle timeout")
                break


async def validate_token(token: str) -> bool:
    """Validate JWT token.

    Args:
        token: JWT token to validate.

    Returns:
        True if valid, False otherwise.
    """
    # TODO: Implement actual JWT validation
    # For now, accept any non-empty token
    return bool(token and token != "invalid-token")


async def validate_session(session_id: str) -> bool:
    """Validate that session exists.

    Args:
        session_id: Session ID to validate.

    Returns:
        True if valid, False otherwise.
    """
    # TODO: Check session exists in database
    return session_id and session_id != "nonexistent"


@router.websocket("/interaction/{session_id}")
async def websocket_interaction(
    websocket: WebSocket,
    session_id: str,
    token: Optional[str] = Query(None),
):
    """WebSocket endpoint for interactive story mode.

    Handles:
    - Connection establishment and authentication
    - Binary audio data from client
    - JSON control messages
    - Real-time transcription and AI responses

    Args:
        websocket: WebSocket connection.
        session_id: Session ID to connect to.
        token: JWT authentication token.
    """
    # Validate token
    if not token or not await validate_token(token):
        await websocket.close(4001, "Unauthorized")
        return

    # Validate session
    if not await validate_session(session_id):
        await websocket.close(4004, "Session not found")
        return

    connection = WebSocketConnection(websocket, session_id, token)
    manager = get_session_manager()

    try:
        await connection.accept()
        connection.start_heartbeat()

        # Send connection established message
        await connection.send_json({
            "type": "connection_established",
            "sessionId": session_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        # Subscribe to session events
        async def event_handler(event: Dict[str, Any]) -> None:
            if event.get("sessionId") == session_id and connection.is_connected:
                await connection.send_json(event)

        manager.subscribe(event_handler)

        # Message handling loop
        while connection.is_connected:
            try:
                message = await websocket.receive()

                if message["type"] == "websocket.disconnect":
                    break

                if "bytes" in message:
                    # Binary audio data
                    await handle_audio_data(manager, session_id, message["bytes"])

                elif "text" in message:
                    # JSON control message
                    try:
                        data = json.loads(message["text"])
                        await handle_control_message(
                            connection, manager, session_id, data
                        )
                    except json.JSONDecodeError:
                        await connection.send_json({
                            "type": "error",
                            "code": "invalid_message",
                            "message": "Invalid JSON format",
                            "recoverable": True,
                            "timestamp": datetime.utcnow().isoformat() + "Z",
                        })

            except WebSocketDisconnect:
                break

    except Exception as e:
        logger.error(f"WebSocket error for session {session_id}: {e}")

    finally:
        manager.unsubscribe(event_handler)
        await connection.close()
        logger.info(f"WebSocket closed for session {session_id}")


async def handle_audio_data(
    manager: SessionManager,
    session_id: str,
    audio_data: bytes,
) -> None:
    """Handle binary audio data from client.

    Args:
        manager: Session manager.
        session_id: Session ID.
        audio_data: Raw audio bytes.
    """
    state = manager.get_state(session_id)
    if not state:
        return

    if state.status == SessionStatus.CALIBRATING:
        await manager.process_calibration_audio(session_id, audio_data)
    elif state.status == SessionStatus.ACTIVE:
        await manager.process_audio(session_id, audio_data)


async def handle_control_message(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle JSON control messages from client.

    Args:
        connection: WebSocket connection.
        manager: Session manager.
        session_id: Session ID.
        message: Parsed JSON message.
    """
    message_type = message.get("type", "")
    timestamp = datetime.utcnow().isoformat() + "Z"

    handlers = {
        "start_listening": handle_start_listening,
        "stop_listening": handle_stop_listening,
        "speech_started": handle_speech_started,
        "speech_ended": handle_speech_ended,
        "interrupt_ai": handle_interrupt_ai,
        "pause_session": handle_pause_session,
        "resume_session": handle_resume_session,
        "end_session": handle_end_session,
        "update_context": handle_update_context,
        "ping": handle_ping,
        # T088 [US5] Calibration handlers
        "start_calibration": handle_start_calibration,
        "complete_calibration": handle_complete_calibration,
    }

    handler = handlers.get(message_type)
    if handler:
        await handler(connection, manager, session_id, message)
    else:
        await connection.send_json({
            "type": "error",
            "code": "unknown_message_type",
            "message": f"Unknown message type: {message_type}",
            "recoverable": True,
            "timestamp": timestamp,
        })


async def handle_start_listening(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle start_listening message."""
    # Client is ready to receive speech
    logger.debug(f"Session {session_id}: start_listening")


async def handle_stop_listening(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle stop_listening message."""
    # Client stopped listening (e.g., app backgrounded)
    logger.debug(f"Session {session_id}: stop_listening")


async def handle_speech_started(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle speech_started message from client VAD."""
    await manager.handle_speech_started(session_id)


async def handle_speech_ended(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle speech_ended message from client VAD.

    T053 [US2] Generate AI response after transcription.
    """
    duration_ms = message.get("durationMs", 0)
    result = await manager.handle_speech_ended(session_id, duration_ms)

    if result and result.text:
        # Send transcription result
        await connection.send_json({
            "type": "transcription_final",
            "text": result.text,
            "confidence": result.confidence,
            "segmentId": result.segment_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        # Add child's speech to conversation history
        add_conversation_turn(session_id, "child", result.text)

        # Generate AI response
        ai_responder = get_ai_responder()
        session_context = get_session_context(session_id)

        context = ResponseContext(
            session_id=session_id,
            story_id=session_context.get("story_id", ""),
            story_title=session_context.get("story_title", ""),
            story_synopsis=session_context.get("story_synopsis", ""),
            characters=session_context.get("characters", []),
            current_scene=session_context.get("current_scene", ""),
            conversation_history=session_context.get("conversation_history", []),
        )

        # Notify client that AI is processing
        await connection.send_json({
            "type": "ai_processing_started",
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        # Generate response
        ai_response = await ai_responder.respond(
            child_text=result.text,
            context=context,
        )

        # Add AI response to conversation history
        if ai_response.text:
            add_conversation_turn(session_id, "ai", ai_response.text)

        # Send AI response to client
        await connection.send_json({
            "type": "ai_response",
            "responseId": ai_response.response_id,
            "text": ai_response.text,
            "wasRedirected": ai_response.was_redirected,
            "isFallback": ai_response.is_fallback,
            "processingTimeMs": ai_response.processing_time_ms,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        # TODO: T054 - Generate TTS audio for AI response


async def handle_interrupt_ai(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle interrupt_ai message - child started speaking during AI response.

    T053 [US2] Implement AI interruption logic (FR-015).
    """
    ai_responder = get_ai_responder()

    # Cancel current AI response generation
    cancelled_response = await ai_responder.cancel_current_response()

    response_id = "unknown"
    if cancelled_response:
        response_id = cancelled_response.response_id

    await connection.send_json({
        "type": "ai_response_completed",
        "responseId": response_id,
        "wasInterrupted": True,
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })

    logger.info(f"AI response interrupted for session {session_id}")


async def handle_pause_session(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle pause_session message."""
    await manager.pause_session(session_id)
    await connection.send_json({
        "type": "session_status_changed",
        "status": "paused",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })


async def handle_resume_session(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle resume_session message."""
    await manager.resume_session(session_id)
    await connection.send_json({
        "type": "session_status_changed",
        "status": "active",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })


async def handle_end_session(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle end_session message."""
    # Get conversation history for turn count
    session_context = get_session_context(session_id)
    conversation_history = session_context.get("conversation_history", [])
    turn_count = len([t for t in conversation_history if t.get("role") == "child"])

    summary = await manager.end_session(session_id)

    # Cleanup session context
    cleanup_session_context(session_id)

    await connection.send_json({
        "type": "session_ended",
        "transcriptId": f"transcript-{session_id}",  # Would be actual transcript ID
        "turnCount": turn_count,
        "totalDurationMs": summary.get("durationMs", 0),
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })


async def handle_update_context(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle update_context message - update story context for AI responses.

    T053 [US2] Update context for AI response generation.
    """
    update_session_context(
        session_id=session_id,
        story_id=message.get("storyId"),
        story_title=message.get("storyTitle"),
        story_synopsis=message.get("storySynopsis"),
        characters=message.get("characters"),
        current_scene=message.get("currentScene"),
    )

    await connection.send_json({
        "type": "context_updated",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })

    logger.debug(f"Context updated for session {session_id}")


async def handle_ping(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle ping message (heartbeat)."""
    await connection.send_json({
        "type": "pong",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })


async def handle_start_calibration(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle start_calibration message.

    T088 [US5] Start noise calibration phase.
    Client should send audio frames after this, which will be collected
    for noise floor estimation.
    """
    state = manager.get_state(session_id)
    if not state:
        await connection.send_json({
            "type": "error",
            "code": "session_not_found",
            "message": "Session not found",
            "recoverable": False,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        return

    if state.status != SessionStatus.CALIBRATING:
        await connection.send_json({
            "type": "error",
            "code": "invalid_state",
            "message": f"Cannot start calibration: session is {state.status.value}",
            "recoverable": True,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        return

    await connection.send_json({
        "type": "calibration_started",
        "sessionId": session_id,
        "durationMs": 2000,  # Recommended calibration duration
        "instructions": "Please remain quiet for 2 seconds",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })

    logger.info(f"Calibration started for session {session_id}")


async def handle_complete_calibration(
    connection: WebSocketConnection,
    manager: SessionManager,
    session_id: str,
    message: Dict[str, Any],
) -> None:
    """Handle complete_calibration message.

    T088 [US5] Complete noise calibration and activate session.
    Analyzes collected noise samples and transitions to active state.
    """
    state = manager.get_state(session_id)
    if not state:
        await connection.send_json({
            "type": "error",
            "code": "session_not_found",
            "message": "Session not found",
            "recoverable": False,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        return

    if state.status != SessionStatus.CALIBRATING:
        await connection.send_json({
            "type": "error",
            "code": "invalid_state",
            "message": f"Cannot complete calibration: session is {state.status.value}",
            "recoverable": True,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        return

    try:
        # Complete calibration and get results
        calibration_result = await manager.complete_calibration(session_id)

        # Send calibration result to client
        await connection.send_json({
            "type": "calibration_completed",
            "sessionId": session_id,
            "noiseFloorDb": calibration_result.noise_floor_db,
            "percentile90": calibration_result.percentile_90,
            "sampleCount": calibration_result.sample_count,
            "calibrationDurationMs": calibration_result.calibration_duration_ms,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        # Activate the session
        await manager.activate_session(session_id)

        await connection.send_json({
            "type": "session_status_changed",
            "status": "active",
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })

        logger.info(
            f"Calibration completed for session {session_id}: "
            f"noise_floor={calibration_result.noise_floor_db:.1f}dB"
        )

    except ValueError as e:
        await connection.send_json({
            "type": "error",
            "code": "calibration_failed",
            "message": str(e),
            "recoverable": True,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        logger.error(f"Calibration failed for session {session_id}: {e}")
