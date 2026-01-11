"""Streaming Speech-to-Text Service.

T030 [US1] Implement streaming STT service using google-cloud-speech.
Provides real-time speech transcription for interactive story mode.
"""

import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List, Dict, Any, AsyncIterator
import uuid
import logging

from google.cloud import speech_v1 as speech
from google.api_core.exceptions import GoogleAPIError

logger = logging.getLogger(__name__)


@dataclass
class StreamingSTTConfig:
    """Configuration for Streaming Speech-to-Text.

    Attributes:
        language_code: Primary language for recognition (BCP-47 code).
        alternative_language_codes: Additional language hints.
        sample_rate_hertz: Audio sample rate.
        encoding: Audio encoding format.
        enable_automatic_punctuation: Add punctuation to transcripts.
        model: Recognition model to use.
        speech_contexts: Custom vocabulary for improved accuracy.
    """

    language_code: str = "zh-TW"  # Traditional Chinese (Taiwan)
    alternative_language_codes: List[str] = field(default_factory=list)
    sample_rate_hertz: int = 16000
    encoding: str = "OGG_OPUS"  # Opus codec as specified in FR-016
    enable_automatic_punctuation: bool = True
    model: str = "latest_short"  # Optimized for short utterances
    speech_contexts: List[Dict[str, Any]] = field(default_factory=list)
    single_utterance: bool = False  # Allow multiple utterances
    interim_results: bool = True  # Enable real-time feedback


@dataclass
class TranscriptionResult:
    """Result from speech transcription.

    Attributes:
        text: Transcribed text.
        is_final: Whether this is a final (vs interim) result.
        confidence: Confidence score (0.0 to 1.0).
        stability: Stability score for interim results.
        segment_id: Unique ID for this speech segment.
        timestamp: When this result was received.
    """

    text: str
    is_final: bool
    confidence: float = 0.0
    stability: float = 0.0
    segment_id: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.utcnow)

    @property
    def is_empty(self) -> bool:
        """Whether this result has no transcribed text."""
        return not self.text or self.text.strip() == ""

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "text": self.text,
            "is_final": self.is_final,
            "confidence": self.confidence,
            "stability": self.stability,
            "segment_id": self.segment_id,
            "timestamp": self.timestamp.isoformat() + "Z",
        }


class StreamingSTTService:
    """Streaming Speech-to-Text service using Google Cloud Speech.

    Provides methods to:
    - Start/stop streaming recognition sessions
    - Send audio chunks for transcription
    - Receive interim and final transcription results
    - Update speech context for story-specific vocabulary
    """

    def __init__(self, config: Optional[StreamingSTTConfig] = None):
        """Initialize STT service.

        Args:
            config: STT configuration. Uses defaults if not provided.
        """
        self.config = config or StreamingSTTConfig()
        self._client: Optional[speech.SpeechClient] = None
        self._streaming: bool = False
        self._session_id: Optional[str] = None
        self._audio_queue: asyncio.Queue[bytes] = asyncio.Queue()
        self._result_queue: asyncio.Queue[TranscriptionResult] = asyncio.Queue()
        self._stop_event: asyncio.Event = asyncio.Event()
        self._stream_task: Optional[asyncio.Task] = None

    @property
    def is_streaming(self) -> bool:
        """Whether a streaming session is active."""
        return self._streaming

    async def _ensure_client(self) -> speech.SpeechClient:
        """Get or create Speech client."""
        if self._client is None:
            self._client = speech.SpeechClient()
        return self._client

    def _build_streaming_config(self) -> speech.StreamingRecognitionConfig:
        """Build the streaming recognition configuration."""
        # Map encoding string to enum
        encoding_map = {
            "OGG_OPUS": speech.RecognitionConfig.AudioEncoding.OGG_OPUS,
            "LINEAR16": speech.RecognitionConfig.AudioEncoding.LINEAR16,
            "FLAC": speech.RecognitionConfig.AudioEncoding.FLAC,
        }
        encoding = encoding_map.get(
            self.config.encoding,
            speech.RecognitionConfig.AudioEncoding.OGG_OPUS,
        )

        # Build speech contexts
        speech_contexts = []
        for ctx in self.config.speech_contexts:
            speech_contexts.append(
                speech.SpeechContext(
                    phrases=ctx.get("phrases", []),
                    boost=ctx.get("boost", 0),
                )
            )

        recognition_config = speech.RecognitionConfig(
            encoding=encoding,
            sample_rate_hertz=self.config.sample_rate_hertz,
            language_code=self.config.language_code,
            alternative_language_codes=self.config.alternative_language_codes,
            enable_automatic_punctuation=self.config.enable_automatic_punctuation,
            model=self.config.model,
            speech_contexts=speech_contexts,
        )

        return speech.StreamingRecognitionConfig(
            config=recognition_config,
            single_utterance=self.config.single_utterance,
            interim_results=self.config.interim_results,
        )

    async def start_session(self, session_id: str) -> str:
        """Start a streaming recognition session.

        Args:
            session_id: Unique ID for this session.

        Returns:
            The session ID.

        Raises:
            Exception: If a session is already active.
        """
        if self._streaming:
            raise Exception("Cannot start session: already streaming")

        self._session_id = session_id
        self._streaming = True
        self._stop_event.clear()
        self._audio_queue = asyncio.Queue()
        self._result_queue = asyncio.Queue()

        # Start the streaming task
        self._stream_task = asyncio.create_task(self._run_stream())

        logger.info(f"Started STT session: {session_id}")
        return session_id

    async def stop_session(self) -> None:
        """Stop the current streaming session."""
        if not self._streaming:
            return

        self._stop_event.set()
        self._streaming = False

        # Cancel the stream task
        if self._stream_task and not self._stream_task.done():
            self._stream_task.cancel()
            try:
                await self._stream_task
            except asyncio.CancelledError:
                pass

        logger.info(f"Stopped STT session: {self._session_id}")
        self._session_id = None

    async def send_audio(self, audio_chunk: bytes) -> None:
        """Send an audio chunk for transcription.

        Args:
            audio_chunk: Raw audio bytes.

        Raises:
            Exception: If no session is active.
        """
        if not self._streaming:
            raise Exception("Cannot send audio: no active session")

        await self._audio_queue.put(audio_chunk)

    async def get_results(self) -> AsyncIterator[TranscriptionResult]:
        """Iterate over transcription results.

        Yields:
            TranscriptionResult objects as they become available.
        """
        while self._streaming or not self._result_queue.empty():
            try:
                result = await asyncio.wait_for(
                    self._result_queue.get(),
                    timeout=0.5,
                )
                yield result
            except asyncio.TimeoutError:
                continue

    async def _run_stream(self) -> None:
        """Run the streaming recognition loop."""
        try:
            client = await self._ensure_client()
            streaming_config = self._build_streaming_config()

            # Create request generator
            async def request_generator():
                # First request: config only
                yield speech.StreamingRecognizeRequest(
                    streaming_config=streaming_config
                )

                # Subsequent requests: audio content
                while not self._stop_event.is_set():
                    try:
                        audio = await asyncio.wait_for(
                            self._audio_queue.get(),
                            timeout=0.1,
                        )
                        yield speech.StreamingRecognizeRequest(audio_content=audio)
                    except asyncio.TimeoutError:
                        continue

            # Convert async generator to sync for the API
            # Note: In production, use streaming_recognize with async support
            # This is a simplified implementation
            requests = []
            async for req in request_generator():
                requests.append(req)
                if len(requests) >= 10:  # Process in batches
                    break

            # Process responses
            responses = client.streaming_recognize(iter(requests))

            for response in responses:
                if self._stop_event.is_set():
                    break

                for result in response.results:
                    if not result.alternatives:
                        continue

                    alternative = result.alternatives[0]
                    transcription = TranscriptionResult(
                        text=alternative.transcript,
                        is_final=result.is_final,
                        confidence=alternative.confidence if result.is_final else 0.0,
                        stability=result.stability if hasattr(result, 'stability') else 0.0,
                        segment_id=str(uuid.uuid4()) if result.is_final else None,
                    )

                    await self._result_queue.put(transcription)

        except GoogleAPIError as e:
            logger.error(f"Google Cloud Speech API error: {e}")
            error_result = TranscriptionResult(
                text="",
                is_final=True,
                confidence=0.0,
            )
            await self._result_queue.put(error_result)
            raise

        except asyncio.CancelledError:
            logger.info("STT stream cancelled")
            raise

        except Exception as e:
            logger.error(f"Unexpected error in STT stream: {e}")
            raise

    async def update_speech_context(
        self,
        phrases: List[str],
        boost: float = 20.0,
    ) -> None:
        """Update speech context for improved recognition.

        Use this to add story-specific vocabulary that should be
        recognized more accurately.

        Args:
            phrases: List of phrases/words to boost.
            boost: Boost value (default 20, higher = more boost).
        """
        self.config.speech_contexts = [
            {"phrases": phrases, "boost": boost}
        ]
        logger.info(f"Updated speech context with {len(phrases)} phrases")

    async def _handle_timeout(self) -> None:
        """Handle streaming timeout (5 minute limit).

        Google Cloud Speech has a 5-minute streaming limit.
        This method handles the timeout by restarting the stream.
        """
        if self._streaming:
            logger.info("Handling STT timeout, restarting stream")
            session_id = self._session_id
            await self.stop_session()
            await self.start_session(session_id)
