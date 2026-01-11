"""
T075 [US4] Implement email sender with SMTP.

Sends transcript emails to parents using SMTP.
"""

import asyncio
import logging
import re
import smtplib
import ssl
from dataclasses import dataclass, field
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional
from uuid import uuid4

from src.models.transcript import InteractionTranscript

logger = logging.getLogger(__name__)


@dataclass
class EmailSenderConfig:
    """Configuration for the email sender."""

    smtp_host: str
    smtp_port: int
    smtp_user: str
    smtp_password: str
    use_tls: bool = True
    from_email: Optional[str] = None
    from_name: str = "StoryBuddy"
    timeout: int = 30
    max_retries: int = 3
    retry_delay: float = 1.0

    def __post_init__(self):
        if self.from_email is None:
            self.from_email = self.smtp_user


@dataclass
class EmailSendResult:
    """Result of an email send operation."""

    success: bool
    message_id: Optional[str] = None
    error: Optional[str] = None


class EmailSender:
    """
    Sends transcript emails to parents via SMTP.

    Supports both single transcript emails and batch digest emails.
    """

    # Email validation regex pattern
    _EMAIL_PATTERN = re.compile(
        r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    )

    def __init__(self, config: EmailSenderConfig):
        """
        Initialize the email sender.

        Args:
            config: SMTP configuration settings.
        """
        self._config = config

    def validate_email(self, email: Optional[str]) -> bool:
        """
        Validate email address format.

        Args:
            email: Email address to validate.

        Returns:
            True if valid, False otherwise.
        """
        if not email:
            return False
        return bool(self._EMAIL_PATTERN.match(email))

    async def send_transcript_email(
        self,
        to_email: str,
        transcript: InteractionTranscript,
        story_title: str,
        max_retries: Optional[int] = None,
    ) -> EmailSendResult:
        """
        Send a single transcript email.

        Args:
            to_email: Recipient email address.
            transcript: The transcript to send.
            story_title: Title of the story.
            max_retries: Override default max retries.

        Returns:
            EmailSendResult indicating success or failure.
        """
        if not self.validate_email(to_email):
            return EmailSendResult(
                success=False,
                error="無效的電子郵件地址",
            )

        subject = f"📚 {story_title} - 互動紀錄"

        # Format duration
        duration_minutes = transcript.total_duration_ms // 60000
        duration_seconds = (transcript.total_duration_ms % 60000) // 1000
        duration_text = f"{duration_minutes}分{duration_seconds}秒"

        # Create plain text version
        text_body = f"""
{story_title} - 互動紀錄

日期：{transcript.created_at.strftime('%Y年%m月%d日 %H:%M')}
時長：{duration_text}
對話回合：{transcript.turn_count} 回合

---

{transcript.plain_text}

---

此郵件由 StoryBuddy 自動發送。
"""

        # Use HTML content from transcript
        html_body = transcript.html_content

        retries = max_retries if max_retries is not None else self._config.max_retries
        last_error: Optional[str] = None

        for attempt in range(retries):
            try:
                message_id = await self._send_email(
                    to_email=to_email,
                    subject=subject,
                    text_body=text_body,
                    html_body=html_body,
                )
                return EmailSendResult(
                    success=True,
                    message_id=message_id,
                )
            except Exception as e:
                last_error = str(e)
                logger.warning(
                    f"Email send attempt {attempt + 1} failed: {e}"
                )
                if attempt < retries - 1:
                    await asyncio.sleep(
                        self._config.retry_delay * (attempt + 1)
                    )

        return EmailSendResult(
            success=False,
            error=f"發送失敗: {last_error}",
        )

    async def send_batch_transcript_email(
        self,
        to_email: str,
        transcripts: list[InteractionTranscript],
        story_titles: list[str],
        digest_title: str,
    ) -> EmailSendResult:
        """
        Send a batch digest email with multiple transcripts.

        Args:
            to_email: Recipient email address.
            transcripts: List of transcripts to include.
            story_titles: Corresponding story titles.
            digest_title: Title for the digest email.

        Returns:
            EmailSendResult indicating success or failure.
        """
        if not transcripts:
            return EmailSendResult(
                success=False,
                error="沒有要發送的紀錄",
            )

        if not self.validate_email(to_email):
            return EmailSendResult(
                success=False,
                error="無效的電子郵件地址",
            )

        subject = f"📚 {digest_title}"

        # Build combined content
        text_parts = [f"{digest_title}\n", "=" * 40 + "\n\n"]
        html_parts = [
            "<!DOCTYPE html>",
            '<html lang="zh-TW">',
            "<head>",
            '<meta charset="UTF-8">',
            f"<title>{digest_title}</title>",
            "<style>",
            "body { font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }",
            ".story-section { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 8px; }",
            ".story-title { color: #6366f1; font-size: 18px; margin-bottom: 10px; }",
            "</style>",
            "</head>",
            "<body>",
            f"<h1>{digest_title}</h1>",
        ]

        for transcript, title in zip(transcripts, story_titles):
            duration_min = transcript.total_duration_ms // 60000

            text_parts.append(f"📖 {title}\n")
            text_parts.append(f"時長：{duration_min} 分鐘 | 對話：{transcript.turn_count} 回合\n")
            text_parts.append("-" * 30 + "\n")
            text_parts.append(transcript.plain_text)
            text_parts.append("\n\n" + "=" * 40 + "\n\n")

            html_parts.append('<div class="story-section">')
            html_parts.append(f'<div class="story-title">📖 {title}</div>')
            html_parts.append(f"<p>時長：{duration_min} 分鐘 | 對話：{transcript.turn_count} 回合</p>")
            html_parts.append("<hr>")
            html_parts.append(transcript.html_content)
            html_parts.append("</div>")

        html_parts.extend([
            "<hr>",
            "<p style='color: #666; font-size: 12px;'>此郵件由 StoryBuddy 自動發送。</p>",
            "</body>",
            "</html>",
        ])

        text_body = "".join(text_parts)
        html_body = "\n".join(html_parts)

        try:
            message_id = await self._send_email(
                to_email=to_email,
                subject=subject,
                text_body=text_body,
                html_body=html_body,
            )
            return EmailSendResult(
                success=True,
                message_id=message_id,
            )
        except Exception as e:
            logger.error(f"Batch email send failed: {e}")
            return EmailSendResult(
                success=False,
                error=f"發送失敗: {e}",
            )

    async def _send_email(
        self,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: str,
    ) -> str:
        """
        Send an email via SMTP.

        Args:
            to_email: Recipient address.
            subject: Email subject.
            text_body: Plain text content.
            html_body: HTML content.

        Returns:
            Message ID of the sent email.

        Raises:
            Exception: If sending fails.
        """
        message_id = f"<{uuid4()}@storybuddy.app>"

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{self._config.from_name} <{self._config.from_email}>"
        msg["To"] = to_email
        msg["Message-ID"] = message_id

        # Attach plain text and HTML parts
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
        msg.attach(MIMEText(html_body, "html", "utf-8"))

        # Run SMTP in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            self._send_smtp,
            to_email,
            msg,
        )

        logger.info(f"Email sent successfully to {to_email}, message_id={message_id}")
        return message_id

    def _send_smtp(self, to_email: str, msg: MIMEMultipart) -> None:
        """
        Send email via SMTP (blocking operation).

        Args:
            to_email: Recipient address.
            msg: MIME message to send.
        """
        context = ssl.create_default_context() if self._config.use_tls else None

        with smtplib.SMTP(
            self._config.smtp_host,
            self._config.smtp_port,
            timeout=self._config.timeout,
        ) as server:
            if self._config.use_tls:
                server.starttls(context=context)

            server.login(self._config.smtp_user, self._config.smtp_password)
            server.sendmail(
                self._config.from_email,
                to_email,
                msg.as_string(),
            )
