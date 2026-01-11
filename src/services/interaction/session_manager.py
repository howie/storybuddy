"""Interaction Session Manager.

T031 [US1] Implement session manager.
T078 [US4] Generate transcript on session end.
Manages the lifecycle of interactive story sessions.
"""

import logging
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from src.db.repository import (
    AIResponseRepository,
    InteractionSessionRepository,
    NoiseCalibrationRepository,
    VoiceSegmentRepository,
)
from src.models.enums import SessionMode, SessionStatus
from src.services.interaction.streaming_stt import StreamingSTTService, TranscriptionResult
from src.services.interaction.vad_service import CalibrationResult, VADService
from src.services.transcript import TranscriptGenerator, get_scheduler

logger = logging.getLogger(__name__)

# Type alias for event handlers
EventHandler = Callable[[dict[str, Any]], Awaitable[None]]


@dataclass
class SessionState:
    """Current state of an interaction session.

    Tracks the session status, mode, and audio processing state.
    """

    session_id: str
    story_id: str
    parent_id: str
    mode: SessionMode = SessionMode.INTERACTIVE
    status: SessionStatus = SessionStatus.CALIBRATING
    story_position_ms: int = 0
    is_child_speaking: bool = False
    is_ai_responding: bool = False
    current_segment_id: str | None = None
    started_at: datetime = field(default_factory=datetime.utcnow)
    calibration: CalibrationResult | None = None

    def activate(self) -> None:
        """Transition to active status."""
        if self.status not in [SessionStatus.CALIBRATING, SessionStatus.PAUSED]:
            raise ValueError(f"Invalid transition: cannot activate from {self.status}")
        self.status = SessionStatus.ACTIVE

    def pause(self) -> None:
        """Transition to paused status."""
        if self.status != SessionStatus.ACTIVE:
            raise ValueError(f"Invalid transition: cannot pause from {self.status}")
        self.status = SessionStatus.PAUSED

    def resume(self) -> None:
        """Resume from paused status."""
        if self.status != SessionStatus.PAUSED:
            raise ValueError(f"Invalid transition: cannot resume from {self.status}")
        self.status = SessionStatus.ACTIVE

    def complete(self) -> None:
        """Mark session as completed."""
        self.status = SessionStatus.COMPLETED

    def set_error(self) -> None:
        """Mark session as having an error."""
        self.status = SessionStatus.ERROR

    def update_position(self, position_ms: int) -> None:
        """Update story playback position."""
        self.story_position_ms = position_ms


@dataclass
class SessionEvent:
    """Event emitted during session lifecycle."""

    type: str
    session_id: str
    data: dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "type": self.type,
            "sessionId": self.session_id,
            "data": self.data,
            "timestamp": self.timestamp.isoformat() + "Z",
        }


class SessionManager:
    """Manages interactive story session lifecycle.

    Coordinates between:
    - VAD service for speech detection
    - STT service for transcription
    - Database repositories for persistence
    - Event handlers for real-time updates
    """

    def __init__(
        self,
        repository: InteractionSessionRepository | None = None,
        vad_service: VADService | None = None,
        stt_service: StreamingSTTService | None = None,
        transcript_generator: TranscriptGenerator | None = None,
    ):
        """Initialize session manager.

        Args:
            repository: Database repository for sessions.
            vad_service: Voice activity detection service.
            stt_service: Speech-to-text service.
            transcript_generator: Transcript generator service.
        """
        self._repository = repository or InteractionSessionRepository()
        self._vad_service = vad_service or VADService()
        self._stt_service = stt_service or StreamingSTTService()
        self._segment_repository = VoiceSegmentRepository()
        self._calibration_repository = NoiseCalibrationRepository()
        self._response_repository = AIResponseRepository()
        self._transcript_generator = transcript_generator or TranscriptGenerator()

        # Active sessions by ID
        self._sessions: dict[str, SessionState] = {}

        # Event subscribers
        self._event_handlers: list[EventHandler] = []

        # Calibration audio buffers
        self._calibration_buffers: dict[str, list[bytes]] = {}

    def subscribe(self, handler: EventHandler) -> None:
        """Subscribe to session events.

        Args:
            handler: Async function to call with event data.
        """
        self._event_handlers.append(handler)

    def unsubscribe(self, handler: EventHandler) -> None:
        """Unsubscribe from session events."""
        if handler in self._event_handlers:
            self._event_handlers.remove(handler)

    async def _emit_event(self, event: SessionEvent) -> None:
        """Emit an event to all subscribers."""
        for handler in self._event_handlers:
            try:
                await handler(event.to_dict())
            except Exception as e:
                logger.error(f"Error in event handler: {e}")

    async def create_session(
        self,
        story_id: str,
        parent_id: str,
        mode: SessionMode = SessionMode.INTERACTIVE,
    ) -> SessionState:
        """Create a new interaction session.

        Args:
            story_id: ID of the story being played.
            parent_id: ID of the parent user.
            mode: Session mode (interactive or passive).

        Returns:
            The created session state.
        """
        session_id = str(uuid.uuid4())

        # Create in database
        await self._repository.create(
            id=session_id,
            story_id=story_id,
            parent_id=parent_id,
            mode=mode,
        )

        # Create local state
        state = SessionState(
            session_id=session_id,
            story_id=story_id,
            parent_id=parent_id,
            mode=mode,
            status=SessionStatus.CALIBRATING
            if mode == SessionMode.INTERACTIVE
            else SessionStatus.ACTIVE,
        )
        self._sessions[session_id] = state
        self._calibration_buffers[session_id] = []

        # Emit event
        await self._emit_event(
            SessionEvent(
                type="session_created",
                session_id=session_id,
                data={"storyId": story_id, "mode": mode.value},
            )
        )

        logger.info(f"Created session {session_id} for story {story_id}")
        return state

    def get_state(self, session_id: str) -> SessionState | None:
        """Get the current state of a session.

        Args:
            session_id: Session ID to look up.

        Returns:
            Session state, or None if not found.
        """
        return self._sessions.get(session_id)

    async def process_calibration_audio(
        self,
        session_id: str,
        audio_frame: bytes,
    ) -> None:
        """Process audio during calibration phase.

        Args:
            session_id: Session ID.
            audio_frame: Audio frame for noise analysis.
        """
        if session_id not in self._calibration_buffers:
            self._calibration_buffers[session_id] = []

        self._calibration_buffers[session_id].append(audio_frame)

    async def complete_calibration(self, session_id: str) -> CalibrationResult:
        """Complete the calibration phase.

        Analyzes collected noise samples and activates the session.

        Args:
            session_id: Session ID.

        Returns:
            Calibration results.

        Raises:
            ValueError: If session not found or not calibrating.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        if state.status != SessionStatus.CALIBRATING:
            raise ValueError(f"Session not calibrating: {state.status}")

        frames = self._calibration_buffers.get(session_id, [])
        if not frames:
            # Use default calibration if no frames
            frames = [bytes(640) for _ in range(50)]  # 1 second of silence

        # Perform calibration
        result = self._vad_service.calibrate(frames)
        state.calibration = result

        # Save to database
        await self._calibration_repository.create(
            session_id=session_id,
            noise_floor_db=result.noise_floor_db,
            percentile_90=result.percentile_90,
            sample_count=result.sample_count,
            calibration_duration_ms=result.calibration_duration_ms,
        )

        # Clear buffer
        del self._calibration_buffers[session_id]

        logger.info(f"Calibration complete for session {session_id}: {result.noise_floor_db:.1f}dB")
        return result

    async def activate_session(self, session_id: str) -> None:
        """Activate a session after calibration.

        Args:
            session_id: Session ID.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        state.activate()
        await self._repository.update_status(session_id, SessionStatus.ACTIVE)

        # Start STT service
        await self._stt_service.start_session(session_id)

        # Reset VAD state
        self._vad_service.reset()

        await self._emit_event(
            SessionEvent(
                type="session_activated",
                session_id=session_id,
            )
        )

        logger.info(f"Session {session_id} activated")

    async def pause_session(self, session_id: str) -> None:
        """Pause an active session.

        Args:
            session_id: Session ID.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        state.pause()
        await self._repository.update_status(session_id, SessionStatus.PAUSED)

        await self._emit_event(
            SessionEvent(
                type="session_paused",
                session_id=session_id,
            )
        )

    async def resume_session(self, session_id: str) -> None:
        """Resume a paused session.

        Args:
            session_id: Session ID.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        state.resume()
        await self._repository.update_status(session_id, SessionStatus.ACTIVE)

        await self._emit_event(
            SessionEvent(
                type="session_resumed",
                session_id=session_id,
            )
        )

    async def end_session(self, session_id: str) -> dict[str, Any]:
        """End a session and cleanup resources.

        T078 [US4]: Generates transcript when session ends.

        Args:
            session_id: Session ID.

        Returns:
            Session summary data.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        # Stop STT
        await self._stt_service.stop_session()

        # Calculate duration
        ended_at = datetime.utcnow()
        duration_ms = int((ended_at - state.started_at).total_seconds() * 1000)

        # Update database
        await self._repository.end_session(session_id)

        # T078: Generate transcript on session end
        transcript_id = await self._generate_session_transcript(
            session_id=session_id,
            state=state,
            ended_at=ended_at,
        )

        # Prepare summary
        summary = {
            "sessionId": session_id,
            "durationMs": duration_ms,
            "status": SessionStatus.COMPLETED.value,
            "transcriptId": transcript_id,
        }

        # Remove from active sessions
        del self._sessions[session_id]

        await self._emit_event(
            SessionEvent(
                type="session_ended",
                session_id=session_id,
                data=summary,
            )
        )

        logger.info(
            f"Session {session_id} ended, duration: {duration_ms}ms, transcript: {transcript_id}"
        )
        return summary

    async def _generate_session_transcript(
        self,
        session_id: str,
        state: SessionState,
        ended_at: datetime,
    ) -> str | None:
        """Generate a transcript for the ended session.

        T078 [US4]: Called automatically when session ends.

        Args:
            session_id: Session ID.
            state: Session state.
            ended_at: Session end time.

        Returns:
            Transcript ID if generated, None on failure.
        """
        try:
            # Fetch voice segments and AI responses
            segments = await self._segment_repository.get_by_session(session_id)
            responses = await self._response_repository.get_by_session(session_id)

            # Convert to model objects
            from src.models.interaction import (
                AIResponse,
                InteractionSession,
                VoiceSegment,
            )

            session_model = InteractionSession(
                id=session_id,
                story_id=state.story_id,
                parent_id=state.parent_id,
                mode=state.mode,
                started_at=state.started_at,
                ended_at=ended_at,
                status=SessionStatus.COMPLETED,
            )

            segment_models = [VoiceSegment(**s) for s in segments]
            response_models = [AIResponse(**r) for r in responses]

            # Generate transcript
            transcript = self._transcript_generator.generate(
                session=session_model,
                voice_segments=segment_models,
                ai_responses=response_models,
            )

            # Save transcript to database
            await self._repository.save_transcript(
                transcript_id=str(transcript.id),
                session_id=session_id,
                parent_id=state.parent_id,
                story_id=state.story_id,
                plain_text=transcript.plain_text,
                html_content=transcript.html_content,
                turn_count=transcript.turn_count,
                total_duration_ms=transcript.total_duration_ms,
            )

            # Queue for email notification if scheduler is running
            scheduler = get_scheduler()
            if scheduler:
                await scheduler.queue_instant_notification(
                    transcript_id=str(transcript.id),
                    session_id=session_id,
                    parent_id=state.parent_id,
                )

            logger.info(f"Generated transcript {transcript.id} for session {session_id}")
            return str(transcript.id)

        except Exception as e:
            logger.error(f"Failed to generate transcript for session {session_id}: {e}")
            return None

    async def process_audio(
        self,
        session_id: str,
        audio_frame: bytes,
    ) -> dict[str, Any] | None:
        """Process an audio frame during active session.

        Args:
            session_id: Session ID.
            audio_frame: Audio frame bytes.

        Returns:
            VAD event if detected, None otherwise.
        """
        state = self._sessions.get(session_id)
        if not state or state.status != SessionStatus.ACTIVE:
            return None

        if state.mode != SessionMode.INTERACTIVE:
            return None

        # Process through VAD
        event = self._vad_service.process_frame(audio_frame)

        if event:
            if event["type"] == "speech_started":
                await self.handle_speech_started(session_id)
            elif event["type"] == "speech_ended":
                await self.handle_speech_ended(
                    session_id,
                    duration_ms=event.get("durationMs", 0),
                )

        # Send to STT if speaking
        if state.is_child_speaking:
            await self._stt_service.send_audio(audio_frame)

        return event

    async def handle_speech_started(self, session_id: str) -> None:
        """Handle speech started event.

        Args:
            session_id: Session ID.
        """
        state = self._sessions.get(session_id)
        if not state:
            return

        state.is_child_speaking = True
        state.current_segment_id = str(uuid.uuid4())

        await self._emit_event(
            SessionEvent(
                type="speech_started",
                session_id=session_id,
                data={"segmentId": state.current_segment_id},
            )
        )

    async def handle_speech_ended(
        self,
        session_id: str,
        duration_ms: int,
    ) -> TranscriptionResult | None:
        """Handle speech ended event.

        Args:
            session_id: Session ID.
            duration_ms: Duration of speech in milliseconds.

        Returns:
            Final transcription result, if available.
        """
        state = self._sessions.get(session_id)
        if not state:
            return None

        state.is_child_speaking = False

        # Get final transcription
        final_result = None
        async for result in self._stt_service.get_results():
            if result.is_final:
                final_result = result
                break

        await self._emit_event(
            SessionEvent(
                type="speech_ended",
                session_id=session_id,
                data={
                    "segmentId": state.current_segment_id,
                    "durationMs": duration_ms,
                    "transcription": final_result.to_dict() if final_result else None,
                },
            )
        )

        state.current_segment_id = None
        return final_result

    async def update_story_position(
        self,
        session_id: str,
        position_ms: int,
    ) -> None:
        """Update the story playback position.

        Args:
            session_id: Session ID.
            position_ms: Current position in milliseconds.
        """
        state = self._sessions.get(session_id)
        if state:
            state.update_position(position_ms)

    async def switch_mode(
        self,
        session_id: str,
        new_mode: SessionMode,
    ) -> None:
        """Switch session mode (FR-013).

        Handles the transition between interactive and passive modes:
        - Interactive → Passive: Close WebSocket, stop VAD
        - Passive → Interactive: Start calibration, prepare WebSocket

        Args:
            session_id: Session ID.
            new_mode: New mode to switch to.
        """
        state = self._sessions.get(session_id)
        if not state:
            raise ValueError(f"Session not found: {session_id}")

        if state.mode == new_mode:
            return

        old_mode = state.mode

        if old_mode == SessionMode.INTERACTIVE:
            # Switching to passive: cleanup interactive resources
            await self._stt_service.stop_session()
            self._vad_service.reset()
            state.is_child_speaking = False

        state.mode = new_mode

        if new_mode == SessionMode.INTERACTIVE:
            # Switching to interactive: need calibration
            state.status = SessionStatus.CALIBRATING
            self._calibration_buffers[session_id] = []

        await self._emit_event(
            SessionEvent(
                type="mode_switched",
                session_id=session_id,
                data={
                    "oldMode": old_mode.value,
                    "newMode": new_mode.value,
                },
            )
        )

        logger.info(f"Session {session_id} mode switched: {old_mode.value} → {new_mode.value}")

    async def send_audio(
        self,
        session_id: str,
        audio_frame: bytes,
    ) -> str | None:
        """Send audio to STT service.

        Args:
            session_id: Session ID.
            audio_frame: Audio frame bytes.

        Returns:
            Error message if failed, None on success.
        """
        try:
            await self._stt_service.send_audio(audio_frame)
            return None
        except Exception as e:
            logger.error(f"Failed to send audio: {e}")
            return str(e)

    async def handle_error(
        self,
        session_id: str,
        error: Exception,
        recoverable: bool = True,
    ) -> None:
        """Handle an error during session.

        Args:
            session_id: Session ID.
            error: The error that occurred.
            recoverable: Whether the error is recoverable.
        """
        state = self._sessions.get(session_id)
        if not state:
            return

        if not recoverable:
            state.set_error()
            await self._repository.update_status(session_id, SessionStatus.ERROR)

        await self._emit_event(
            SessionEvent(
                type="session_error",
                session_id=session_id,
                data={
                    "message": str(error),
                    "recoverable": recoverable,
                },
            )
        )

        logger.error(f"Session {session_id} error: {error}")

    async def _check_timeout(
        self,
        session_id: str,
        timeout_seconds: int = 60,
    ) -> None:
        """Check for session timeout.

        Args:
            session_id: Session ID.
            timeout_seconds: Timeout duration in seconds.
        """
        state = self._sessions.get(session_id)
        if not state:
            return

        # Implementation would check last activity time
        # and trigger timeout if exceeded
        pass
