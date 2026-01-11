"""
T069 [P] [US4] Unit test for transcript generator.

Tests the TranscriptGenerator service for creating formatted transcripts
from interaction sessions.
"""

from datetime import datetime, timedelta
from uuid import uuid4

import pytest

from src.models.enums import TriggerType
from src.models.interaction import AIResponse, InteractionSession, VoiceSegment
from src.models.transcript import InteractionTranscript
from src.services.transcript.generator import TranscriptGenerator


class TestTranscriptGenerator:
    """Test suite for TranscriptGenerator service."""

    @pytest.fixture
    def generator(self) -> TranscriptGenerator:
        """Create a transcript generator instance."""
        return TranscriptGenerator()

    @pytest.fixture
    def sample_session(self) -> InteractionSession:
        """Create a sample interaction session."""
        now = datetime.utcnow()
        return InteractionSession(
            id=uuid4(),
            story_id=uuid4(),
            parent_id=uuid4(),
            started_at=now - timedelta(minutes=10),
            ended_at=now,
        )

    @pytest.fixture
    def sample_voice_segments(self, sample_session: InteractionSession) -> list[VoiceSegment]:
        """Create sample voice segments."""
        base_time = sample_session.started_at
        segments = []

        for i in range(3):
            segment = VoiceSegment(
                id=uuid4(),
                session_id=sample_session.id,
                sequence=i + 1,
                started_at=base_time + timedelta(minutes=i * 2),
                ended_at=base_time + timedelta(minutes=i * 2, seconds=30),
                transcript=f"孩子的第{i + 1}段話：這是一個測試",
            )
            segments.append(segment)

        return segments

    @pytest.fixture
    def sample_ai_responses(
        self,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
    ) -> list[AIResponse]:
        """Create sample AI responses."""
        responses = []

        for i, segment in enumerate(sample_voice_segments):
            response = AIResponse(
                id=uuid4(),
                session_id=sample_session.id,
                voice_segment_id=segment.id,
                text=f"AI 的第{i + 1}段回應：謝謝你的分享！",
                trigger_type=TriggerType.CHILD_SPEECH,
                response_latency_ms=500,
            )
            responses.append(response)

        return responses

    def test_generate_transcript_creates_valid_transcript(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
        sample_ai_responses: list[AIResponse],
    ):
        """Test that generator creates a valid transcript from session data."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=sample_voice_segments,
            ai_responses=sample_ai_responses,
        )

        assert isinstance(transcript, InteractionTranscript)
        assert transcript.session_id == sample_session.id
        assert transcript.turn_count == len(sample_voice_segments)
        assert transcript.total_duration_ms > 0

    def test_generate_transcript_includes_plain_text(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
        sample_ai_responses: list[AIResponse],
    ):
        """Test that generated transcript includes plain text content."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=sample_voice_segments,
            ai_responses=sample_ai_responses,
        )

        # Plain text should contain all voice segments and responses
        assert "孩子的第1段話" in transcript.plain_text
        assert "AI 的第1段回應" in transcript.plain_text
        assert len(transcript.plain_text) > 0

    def test_generate_transcript_includes_html_content(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
        sample_ai_responses: list[AIResponse],
    ):
        """Test that generated transcript includes HTML content."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=sample_voice_segments,
            ai_responses=sample_ai_responses,
        )

        # HTML should have proper structure
        assert "<html" in transcript.html_content.lower()
        assert "孩子的第1段話" in transcript.html_content
        assert "AI 的第1段回應" in transcript.html_content

    def test_generate_transcript_empty_session(
        self, generator: TranscriptGenerator, sample_session: InteractionSession
    ):
        """Test that generator handles empty sessions gracefully."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=[],
            ai_responses=[],
        )

        assert transcript.turn_count == 0
        assert transcript.session_id == sample_session.id
        # Should still have valid content structure
        assert len(transcript.plain_text) > 0
        assert len(transcript.html_content) > 0

    def test_generate_transcript_orders_by_time(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
    ):
        """Test that transcript entries are ordered chronologically."""
        base_time = sample_session.started_at

        # Create segments out of order
        segments = [
            VoiceSegment(
                id=uuid4(),
                session_id=sample_session.id,
                sequence=2,
                started_at=base_time + timedelta(minutes=2),
                ended_at=base_time + timedelta(minutes=2, seconds=30),
                transcript="第二段",
            ),
            VoiceSegment(
                id=uuid4(),
                session_id=sample_session.id,
                sequence=1,
                started_at=base_time,
                ended_at=base_time + timedelta(seconds=30),
                transcript="第一段",
            ),
        ]

        responses = []
        for segment in segments:
            responses.append(
                AIResponse(
                    id=uuid4(),
                    session_id=sample_session.id,
                    voice_segment_id=segment.id,
                    text=f"回應 {segment.transcript}",
                    trigger_type=TriggerType.CHILD_SPEECH,
                )
            )

        transcript = generator.generate(
            session=sample_session,
            voice_segments=segments,
            ai_responses=responses,
        )

        # First segment should appear before second in output
        first_pos = transcript.plain_text.find("第一段")
        second_pos = transcript.plain_text.find("第二段")
        assert first_pos < second_pos

    def test_generate_transcript_calculates_duration(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
        sample_ai_responses: list[AIResponse],
    ):
        """Test that transcript correctly calculates total duration."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=sample_voice_segments,
            ai_responses=sample_ai_responses,
        )

        # Duration should be calculated from session start to end
        expected_duration_ms = int(
            (sample_session.ended_at - sample_session.started_at).total_seconds() * 1000
        )
        assert transcript.total_duration_ms == expected_duration_ms

    def test_generate_transcript_handles_interrupted_responses(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
    ):
        """Test that transcript marks interrupted responses."""
        base_time = sample_session.started_at

        segment = VoiceSegment(
            id=uuid4(),
            session_id=sample_session.id,
            sequence=1,
            started_at=base_time,
            ended_at=base_time + timedelta(seconds=30),
            transcript="孩子打斷了",
        )

        response = AIResponse(
            id=uuid4(),
            session_id=sample_session.id,
            voice_segment_id=segment.id,
            text="這是被打斷的回應",
            trigger_type=TriggerType.CHILD_SPEECH,
            was_interrupted=True,
            interrupted_at_ms=2000,
        )

        transcript = generator.generate(
            session=sample_session,
            voice_segments=[segment],
            ai_responses=[response],
        )

        # Interrupted response should be marked
        assert "打斷" in transcript.plain_text or "中斷" in transcript.plain_text

    def test_generate_transcript_handles_silence_triggers(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
    ):
        """Test that transcript includes AI responses triggered by silence."""
        response = AIResponse(
            id=uuid4(),
            session_id=sample_session.id,
            voice_segment_id=None,
            text="孩子好安靜呢，要不要聊聊故事？",
            trigger_type=TriggerType.SILENCE,
        )

        transcript = generator.generate(
            session=sample_session,
            voice_segments=[],
            ai_responses=[response],
        )

        assert "孩子好安靜" in transcript.plain_text

    def test_generate_transcript_handles_story_event_triggers(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
    ):
        """Test that transcript includes AI responses triggered by story events."""
        response = AIResponse(
            id=uuid4(),
            session_id=sample_session.id,
            voice_segment_id=None,
            text="故事來到了精彩的部分！",
            trigger_type=TriggerType.STORY_EVENT,
        )

        transcript = generator.generate(
            session=sample_session,
            voice_segments=[],
            ai_responses=[response],
        )

        assert "故事來到了" in transcript.plain_text

    def test_generate_transcript_includes_timestamps(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
        sample_voice_segments: list[VoiceSegment],
        sample_ai_responses: list[AIResponse],
    ):
        """Test that transcript includes timestamps for entries."""
        transcript = generator.generate(
            session=sample_session,
            voice_segments=sample_voice_segments,
            ai_responses=sample_ai_responses,
        )

        # Plain text should contain time markers
        # Format like [00:00] or [0:00]
        import re

        time_pattern = r"\[\d+:\d{2}\]"
        matches = re.findall(time_pattern, transcript.plain_text)
        assert len(matches) > 0, "Transcript should include timestamps"

    def test_generate_transcript_handles_missing_transcription(
        self,
        generator: TranscriptGenerator,
        sample_session: InteractionSession,
    ):
        """Test that transcript handles segments without transcription."""
        base_time = sample_session.started_at

        segment = VoiceSegment(
            id=uuid4(),
            session_id=sample_session.id,
            sequence=1,
            started_at=base_time,
            ended_at=base_time + timedelta(seconds=30),
            transcript=None,  # No transcription
        )

        response = AIResponse(
            id=uuid4(),
            session_id=sample_session.id,
            voice_segment_id=segment.id,
            text="AI 回應",
            trigger_type=TriggerType.CHILD_SPEECH,
        )

        transcript = generator.generate(
            session=sample_session,
            voice_segments=[segment],
            ai_responses=[response],
        )

        # Should handle missing transcription gracefully
        assert "無法辨識" in transcript.plain_text or "[語音]" in transcript.plain_text
        assert "AI 回應" in transcript.plain_text
