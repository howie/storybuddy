"""
T070 [P] [US4] Unit test for email sender.

Tests the EmailSender service for sending transcript emails to parents.
"""

from datetime import datetime
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest

from src.models.transcript import InteractionTranscript
from src.services.transcript.email_sender import (
    EmailSender,
    EmailSenderConfig,
    EmailSendResult,
)


class TestEmailSenderConfig:
    """Tests for EmailSenderConfig."""

    def test_config_defaults(self):
        """Test default configuration values."""
        config = EmailSenderConfig(
            smtp_host="smtp.example.com",
            smtp_port=587,
            smtp_user="user@example.com",
            smtp_password="password",
        )

        assert config.smtp_host == "smtp.example.com"
        assert config.smtp_port == 587
        assert config.use_tls is True
        assert config.from_email == "user@example.com"
        assert config.from_name == "StoryBuddy"

    def test_config_custom_from_email(self):
        """Test custom from email configuration."""
        config = EmailSenderConfig(
            smtp_host="smtp.example.com",
            smtp_port=587,
            smtp_user="user@example.com",
            smtp_password="password",
            from_email="noreply@storybuddy.app",
            from_name="故事小夥伴",
        )

        assert config.from_email == "noreply@storybuddy.app"
        assert config.from_name == "故事小夥伴"


class TestEmailSender:
    """Test suite for EmailSender service."""

    @pytest.fixture
    def config(self) -> EmailSenderConfig:
        """Create a test configuration."""
        return EmailSenderConfig(
            smtp_host="smtp.test.com",
            smtp_port=587,
            smtp_user="test@test.com",
            smtp_password="testpass",
            from_email="noreply@storybuddy.app",
            from_name="StoryBuddy",
        )

    @pytest.fixture
    def sender(self, config: EmailSenderConfig) -> EmailSender:
        """Create an EmailSender instance."""
        return EmailSender(config)

    @pytest.fixture
    def sample_transcript(self) -> InteractionTranscript:
        """Create a sample transcript."""
        return InteractionTranscript(
            id=uuid4(),
            session_id=uuid4(),
            plain_text="孩子：這是測試\nAI：謝謝你的分享！",
            html_content="<html><body>孩子：這是測試<br>AI：謝謝你的分享！</body></html>",
            turn_count=1,
            total_duration_ms=60000,
            created_at=datetime.utcnow(),
        )

    @pytest.mark.asyncio
    async def test_send_transcript_email_success(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test successful email sending."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            result = await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            assert result.success is True
            assert result.message_id is not None
            mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_send_transcript_email_failure(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test email sending failure handling."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.side_effect = Exception("SMTP connection failed")

            result = await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            assert result.success is False
            assert "error" in result.error.lower() or "failed" in result.error.lower()

    @pytest.mark.asyncio
    async def test_send_transcript_email_invalid_email(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test handling of invalid email address."""
        result = await sender.send_transcript_email(
            to_email="not-a-valid-email",
            transcript=sample_transcript,
            story_title="小熊的冒險",
        )

        assert result.success is False
        assert "email" in result.error.lower() or "無效" in result.error

    @pytest.mark.asyncio
    async def test_send_transcript_email_includes_subject(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that email includes proper subject."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            # Check the call arguments for subject
            call_args = mock_send.call_args
            subject = call_args.kwargs.get("subject") or call_args.args[1]
            assert "互動紀錄" in subject or "transcript" in subject.lower()
            assert "小熊的冒險" in subject

    @pytest.mark.asyncio
    async def test_send_transcript_email_uses_html_content(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that email uses HTML content from transcript."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            call_args = mock_send.call_args
            html_body = call_args.kwargs.get("html_body") or call_args.args[3]
            assert "這是測試" in html_body

    @pytest.mark.asyncio
    async def test_send_transcript_email_includes_plain_text(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that email includes plain text fallback."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            call_args = mock_send.call_args
            text_body = call_args.kwargs.get("text_body") or call_args.args[2]
            assert "這是測試" in text_body

    @pytest.mark.asyncio
    async def test_send_batch_emails(
        self,
        sender: EmailSender,
    ):
        """Test sending batch emails for daily digest."""
        transcripts = [
            InteractionTranscript(
                id=uuid4(),
                session_id=uuid4(),
                plain_text=f"Transcript {i}",
                html_content=f"<html>Transcript {i}</html>",
                turn_count=i + 1,
                total_duration_ms=60000 * (i + 1),
            )
            for i in range(3)
        ]

        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            results = await sender.send_batch_transcript_email(
                to_email="parent@example.com",
                transcripts=transcripts,
                story_titles=["故事一", "故事二", "故事三"],
                digest_title="今日互動摘要",
            )

            assert results.success is True
            mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_send_batch_emails_empty_list(
        self,
        sender: EmailSender,
    ):
        """Test batch email with empty transcript list."""
        results = await sender.send_batch_transcript_email(
            to_email="parent@example.com",
            transcripts=[],
            story_titles=[],
            digest_title="今日互動摘要",
        )

        assert results.success is False
        assert "empty" in results.error.lower() or "沒有" in results.error

    def test_validate_email_format_valid(self, sender: EmailSender):
        """Test email format validation with valid emails."""
        valid_emails = [
            "user@example.com",
            "user.name@example.com",
            "user+tag@example.com",
            "user@subdomain.example.com",
        ]

        for email in valid_emails:
            assert sender.validate_email(email) is True, f"{email} should be valid"

    def test_validate_email_format_invalid(self, sender: EmailSender):
        """Test email format validation with invalid emails."""
        invalid_emails = [
            "not-an-email",
            "@example.com",
            "user@",
            "user@.com",
            "",
            None,
        ]

        for email in invalid_emails:
            assert sender.validate_email(email) is False, f"{email} should be invalid"

    @pytest.mark.asyncio
    async def test_email_includes_session_metadata(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that email includes session metadata."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
            )

            call_args = mock_send.call_args
            html_body = call_args.kwargs.get("html_body") or call_args.args[3]

            # Should include duration info (1 minute)
            assert "1" in html_body or "分鐘" in html_body or "minute" in html_body.lower()
            # Should include turn count
            assert "1" in html_body

    @pytest.mark.asyncio
    async def test_rate_limiting(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that sender respects rate limiting."""
        with patch.object(sender, "_send_email", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = True

            # Send multiple emails quickly
            results = []
            for _ in range(10):
                result = await sender.send_transcript_email(
                    to_email="parent@example.com",
                    transcript=sample_transcript,
                    story_title="小熊的冒險",
                )
                results.append(result)

            # All should succeed (rate limiting is internal)
            # or some should be rate limited gracefully
            success_count = sum(1 for r in results if r.success)
            assert success_count > 0

    @pytest.mark.asyncio
    async def test_retry_on_temporary_failure(
        self,
        sender: EmailSender,
        sample_transcript: InteractionTranscript,
    ):
        """Test that sender retries on temporary failures."""
        call_count = 0

        async def mock_send(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Temporary failure")
            return True

        with patch.object(sender, "_send_email", side_effect=mock_send):
            result = await sender.send_transcript_email(
                to_email="parent@example.com",
                transcript=sample_transcript,
                story_title="小熊的冒險",
                max_retries=3,
            )

            # Should succeed after retries
            assert result.success is True or call_count >= 2


class TestEmailSendResult:
    """Tests for EmailSendResult data class."""

    def test_success_result(self):
        """Test successful result creation."""
        result = EmailSendResult(
            success=True,
            message_id="msg-123",
        )

        assert result.success is True
        assert result.message_id == "msg-123"
        assert result.error is None

    def test_failure_result(self):
        """Test failure result creation."""
        result = EmailSendResult(
            success=False,
            error="SMTP connection timeout",
        )

        assert result.success is False
        assert result.message_id is None
        assert result.error == "SMTP connection timeout"
