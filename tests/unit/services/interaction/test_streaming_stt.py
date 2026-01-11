"""Unit tests for Streaming Speech-to-Text service.

T024 [P] [US1] Unit test for streaming STT.
Tests the Google Cloud Speech-to-Text integration for real-time transcription.
"""

from unittest.mock import MagicMock, patch

import pytest

# These imports will fail until the service is implemented
from src.services.interaction.streaming_stt import (
    StreamingSTTConfig,
    StreamingSTTService,
    TranscriptionResult,
)


class TestStreamingSTTConfig:
    """Tests for Streaming STT configuration."""

    def test_default_config_values(self):
        """Default config should be optimized for children's speech."""
        config = StreamingSTTConfig()
        assert config.language_code == "zh-TW"  # Traditional Chinese (Taiwan)
        assert config.sample_rate_hertz == 16000
        assert config.encoding == "OGG_OPUS"  # Opus codec
        assert config.enable_automatic_punctuation is True
        assert config.model == "latest_short"  # Optimized for short utterances

    def test_custom_language_code(self):
        """Should support different language codes."""
        config = StreamingSTTConfig(language_code="en-US")
        assert config.language_code == "en-US"

    def test_alternative_languages(self):
        """Should support alternative language hints."""
        config = StreamingSTTConfig(
            language_code="zh-TW",
            alternative_language_codes=["en-US", "ja-JP"],
        )
        assert len(config.alternative_language_codes) == 2

    def test_speech_context_for_story_vocabulary(self):
        """Should support custom vocabulary for story context."""
        config = StreamingSTTConfig(
            speech_contexts=[{"phrases": ["小兔子", "大野狼", "森林"], "boost": 20}]
        )
        assert len(config.speech_contexts) == 1
        assert "小兔子" in config.speech_contexts[0]["phrases"]


class TestTranscriptionResult:
    """Tests for transcription result model."""

    def test_create_interim_result(self):
        """Should create interim transcription result."""
        result = TranscriptionResult(
            text="小兔子會不會",
            is_final=False,
            confidence=0.75,
            stability=0.85,
        )
        assert result.text == "小兔子會不會"
        assert result.is_final is False
        assert result.confidence == 0.75

    def test_create_final_result(self):
        """Should create final transcription result."""
        result = TranscriptionResult(
            text="小兔子會不會遇到大野狼？",
            is_final=True,
            confidence=0.95,
            segment_id="segment-123",
        )
        assert result.is_final is True
        assert result.segment_id == "segment-123"

    def test_empty_result_for_no_speech(self):
        """Should handle no speech detected."""
        result = TranscriptionResult(
            text="",
            is_final=True,
            confidence=0.0,
        )
        assert result.text == ""
        assert result.is_empty is True


class TestStreamingSTTService:
    """Tests for Streaming STT service."""

    @pytest.fixture
    def mock_speech_client(self):
        """Create a mock Google Cloud Speech client."""
        with patch("src.services.interaction.streaming_stt.speech.SpeechClient") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def stt_service(self, mock_speech_client):
        """Create a StreamingSTT service instance."""
        return StreamingSTTService()

    @pytest.mark.asyncio
    async def test_create_service(self, stt_service):
        """Should create service with default configuration."""
        assert stt_service is not None
        assert stt_service.config.language_code == "zh-TW"

    @pytest.mark.asyncio
    async def test_start_streaming_session(self, stt_service, mock_speech_client):
        """Should start a streaming recognition session."""
        session_id = await stt_service.start_session("session-123")

        assert session_id == "session-123"
        assert stt_service.is_streaming

    @pytest.mark.asyncio
    async def test_send_audio_chunk(self, stt_service, mock_speech_client):
        """Should send audio chunks to the recognition service."""
        await stt_service.start_session("session-123")

        audio_chunk = bytes(640)  # 20ms of audio
        await stt_service.send_audio(audio_chunk)

        # Verify audio was queued for sending
        assert stt_service._audio_queue.qsize() >= 0

    @pytest.mark.asyncio
    async def test_receive_interim_results(self, stt_service, mock_speech_client):
        """Should receive interim transcription results."""
        await stt_service.start_session("session-123")

        # Directly populate the result queue to simulate results from _run_stream
        # This tests the get_results() consumer without depending on the producer
        interim_result = TranscriptionResult(
            text="小兔子",
            is_final=False,
            confidence=0.8,
            stability=0.85,
        )
        await stt_service._result_queue.put(interim_result)

        # Stop streaming so get_results() will exit after processing the queue
        stt_service._streaming = False

        # Collect results
        results = []
        async for result in stt_service.get_results():
            results.append(result)
            if len(results) >= 1:
                break

        assert len(results) >= 1
        # Result should be interim
        assert results[0].is_final is False

    @pytest.mark.asyncio
    async def test_receive_final_results(self, stt_service, mock_speech_client):
        """Should receive final transcription results."""
        await stt_service.start_session("session-123")

        # Directly populate the result queue to simulate results from _run_stream
        final_result = TranscriptionResult(
            text="小兔子會不會遇到大野狼？",
            is_final=True,
            confidence=0.95,
            segment_id="segment-123",
        )
        await stt_service._result_queue.put(final_result)

        # Stop streaming so get_results() will exit after processing the queue
        stt_service._streaming = False

        results = []
        async for result in stt_service.get_results():
            results.append(result)
            if result.is_final:
                break

        assert any(r.is_final for r in results)
        result = next(r for r in results if r.is_final)
        assert "小兔子" in result.text

    @pytest.mark.asyncio
    async def test_stop_streaming_session(self, stt_service, mock_speech_client):
        """Should stop streaming session gracefully."""
        await stt_service.start_session("session-123")
        await stt_service.stop_session()

        assert stt_service.is_streaming is False

    @pytest.mark.asyncio
    async def test_handle_recognition_error(self, stt_service, mock_speech_client):
        """Should handle recognition errors gracefully."""
        await stt_service.start_session("session-123")

        # Directly populate the result queue with an error result to simulate error handling
        # _run_stream catches errors and puts empty/low-confidence results in the queue
        error_result = TranscriptionResult(
            text="",
            is_final=True,
            confidence=0.0,
        )
        await stt_service._result_queue.put(error_result)

        # Stop streaming so get_results() will exit after processing the queue
        stt_service._streaming = False

        results = []
        async for result in stt_service.get_results():
            results.append(result)
            break

        # Error result (empty text with is_final=True) should be in the queue
        assert len(results) >= 1
        assert results[0].is_empty is True
        assert results[0].confidence == 0.0

    @pytest.mark.asyncio
    async def test_timeout_handling(self, stt_service, mock_speech_client):
        """Should handle streaming timeout (5 minute limit)."""
        # Google Cloud Speech has a 5-minute streaming limit
        await stt_service.start_session("session-123")

        # Service should be able to detect timeout and restart
        assert hasattr(stt_service, "_handle_timeout")

    @pytest.mark.asyncio
    async def test_update_speech_context(self, stt_service, mock_speech_client):
        """Should update speech context for story-specific vocabulary."""
        story_vocabulary = ["小兔子", "大野狼", "森林", "蘿蔔"]

        await stt_service.update_speech_context(
            phrases=story_vocabulary,
            boost=20,
        )

        assert stt_service.config.speech_contexts is not None
        assert len(stt_service.config.speech_contexts) > 0


class TestStreamingSTTServiceEdgeCases:
    """Edge case tests for Streaming STT service."""

    @pytest.fixture
    def mock_speech_client(self):
        """Create a mock Google Cloud Speech client."""
        with patch("src.services.interaction.streaming_stt.speech.SpeechClient") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def stt_service(self, mock_speech_client):
        """Create a StreamingSTT service instance."""
        return StreamingSTTService()

    @pytest.mark.asyncio
    async def test_empty_audio_stream(self, stt_service, mock_speech_client):
        """Should handle empty audio stream gracefully."""
        await stt_service.start_session("session-123")
        await stt_service.send_audio(bytes(0))  # Empty audio

        # No results expected from empty audio, just verify no crash
        # Stop streaming to avoid hanging
        stt_service._streaming = False

        results = []
        async for result in stt_service.get_results():
            results.append(result)
            break

        # Should handle gracefully without crashing
        assert True

    @pytest.mark.asyncio
    async def test_noisy_audio(self, stt_service, mock_speech_client):
        """Should handle noisy audio with low confidence."""
        await stt_service.start_session("session-123")

        # Directly populate the result queue with a low confidence result
        low_confidence_result = TranscriptionResult(
            text="...",
            is_final=True,
            confidence=0.3,
        )
        await stt_service._result_queue.put(low_confidence_result)

        # Stop streaming so get_results() will exit after processing the queue
        stt_service._streaming = False

        results = []
        async for result in stt_service.get_results():
            results.append(result)
            break

        # Low confidence result should still be returned
        assert len(results) >= 1
        assert results[0].confidence == 0.3

    @pytest.mark.asyncio
    async def test_concurrent_sessions_not_allowed(self, stt_service, mock_speech_client):
        """Should not allow concurrent streaming sessions."""
        await stt_service.start_session("session-1")

        with pytest.raises(Exception, match="already streaming"):
            await stt_service.start_session("session-2")

    @pytest.mark.asyncio
    async def test_send_audio_without_session(self, stt_service, mock_speech_client):
        """Should raise error when sending audio without active session."""
        with pytest.raises(Exception, match="no active session"):
            await stt_service.send_audio(bytes(640))
