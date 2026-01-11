"""
T077 [US4] Implement scheduled email job.

Handles instant, daily, and weekly email notifications for transcripts.
"""

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Callable, Optional

from src.db.repository import Repository
from src.models.enums import NotificationFrequency
from src.models.transcript import InteractionTranscript
from src.services.transcript.email_sender import EmailSender
from src.services.transcript.generator import TranscriptGenerator

logger = logging.getLogger(__name__)


@dataclass
class SchedulerConfig:
    """Configuration for the transcript scheduler."""

    check_interval_seconds: int = 60  # How often to check for pending emails
    daily_send_hour: int = 9  # Hour (0-23) to send daily digests
    weekly_send_day: int = 0  # Day of week (0=Monday) to send weekly digests
    weekly_send_hour: int = 9
    batch_size: int = 10  # Max emails to send per check cycle


@dataclass
class PendingTranscript:
    """A transcript pending email notification."""

    transcript_id: str
    session_id: str
    parent_id: str
    parent_email: str
    story_title: str
    created_at: datetime
    frequency: NotificationFrequency


class TranscriptScheduler:
    """
    Manages scheduled email notifications for transcripts.

    Supports three notification frequencies:
    - INSTANT: Send immediately when transcript is generated
    - DAILY: Batch and send at configured daily time
    - WEEKLY: Batch and send at configured weekly time
    """

    def __init__(
        self,
        repository: Repository,
        email_sender: EmailSender,
        generator: TranscriptGenerator,
        config: Optional[SchedulerConfig] = None,
    ):
        """
        Initialize the scheduler.

        Args:
            repository: Database repository for transcript data.
            email_sender: Email sender service.
            generator: Transcript generator service.
            config: Scheduler configuration.
        """
        self._repository = repository
        self._email_sender = email_sender
        self._generator = generator
        self._config = config or SchedulerConfig()
        self._running = False
        self._task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        """Start the scheduler background task."""
        if self._running:
            return

        self._running = True
        self._task = asyncio.create_task(self._run_loop())
        logger.info("Transcript scheduler started")

    async def stop(self) -> None:
        """Stop the scheduler."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
        logger.info("Transcript scheduler stopped")

    async def _run_loop(self) -> None:
        """Main scheduler loop."""
        while self._running:
            try:
                await self._process_pending_emails()
            except Exception as e:
                logger.error(f"Error in scheduler loop: {e}")

            await asyncio.sleep(self._config.check_interval_seconds)

    async def _process_pending_emails(self) -> None:
        """Process pending email notifications."""
        now = datetime.utcnow()

        # Process instant notifications
        await self._process_instant_notifications()

        # Check if it's time for daily digest
        if self._is_daily_send_time(now):
            await self._process_daily_digests()

        # Check if it's time for weekly digest
        if self._is_weekly_send_time(now):
            await self._process_weekly_digests()

    def _is_daily_send_time(self, now: datetime) -> bool:
        """Check if it's time to send daily digests."""
        return (
            now.hour == self._config.daily_send_hour
            and now.minute < 2  # Within first 2 minutes of the hour
        )

    def _is_weekly_send_time(self, now: datetime) -> bool:
        """Check if it's time to send weekly digests."""
        return (
            now.weekday() == self._config.weekly_send_day
            and now.hour == self._config.weekly_send_hour
            and now.minute < 2
        )

    async def _process_instant_notifications(self) -> None:
        """Send instant email notifications for new transcripts."""
        pending = await self._repository.get_pending_instant_notifications(
            limit=self._config.batch_size
        )

        for item in pending:
            try:
                await self._send_single_transcript_email(item)
            except Exception as e:
                logger.error(
                    f"Failed to send instant notification for {item.transcript_id}: {e}"
                )

    async def _process_daily_digests(self) -> None:
        """Send daily digest emails."""
        # Get all parents with daily frequency who have unsent transcripts
        parents = await self._repository.get_parents_with_pending_digests(
            frequency=NotificationFrequency.DAILY,
            since=datetime.utcnow() - timedelta(days=1),
        )

        for parent_id, parent_email in parents:
            try:
                await self._send_digest_email(
                    parent_id=parent_id,
                    parent_email=parent_email,
                    since=datetime.utcnow() - timedelta(days=1),
                    digest_title="今日互動摘要",
                )
            except Exception as e:
                logger.error(
                    f"Failed to send daily digest for parent {parent_id}: {e}"
                )

    async def _process_weekly_digests(self) -> None:
        """Send weekly digest emails."""
        parents = await self._repository.get_parents_with_pending_digests(
            frequency=NotificationFrequency.WEEKLY,
            since=datetime.utcnow() - timedelta(days=7),
        )

        for parent_id, parent_email in parents:
            try:
                await self._send_digest_email(
                    parent_id=parent_id,
                    parent_email=parent_email,
                    since=datetime.utcnow() - timedelta(days=7),
                    digest_title="本週互動摘要",
                )
            except Exception as e:
                logger.error(
                    f"Failed to send weekly digest for parent {parent_id}: {e}"
                )

    async def _send_single_transcript_email(
        self, pending: PendingTranscript
    ) -> None:
        """Send email for a single transcript."""
        transcript_data = await self._repository.get_transcript(pending.transcript_id)
        if not transcript_data:
            logger.warning(f"Transcript {pending.transcript_id} not found")
            return

        transcript = InteractionTranscript(
            id=pending.transcript_id,
            session_id=pending.session_id,
            plain_text=transcript_data["plain_text"],
            html_content=transcript_data["html_content"],
            turn_count=transcript_data["turn_count"],
            total_duration_ms=transcript_data["total_duration_ms"],
            created_at=pending.created_at,
        )

        result = await self._email_sender.send_transcript_email(
            to_email=pending.parent_email,
            transcript=transcript,
            story_title=pending.story_title,
        )

        if result.success:
            await self._repository.mark_transcript_email_sent(pending.transcript_id)
            logger.info(f"Instant notification sent for transcript {pending.transcript_id}")
        else:
            logger.error(
                f"Failed to send email for transcript {pending.transcript_id}: {result.error}"
            )

    async def _send_digest_email(
        self,
        parent_id: str,
        parent_email: str,
        since: datetime,
        digest_title: str,
    ) -> None:
        """Send a digest email with multiple transcripts."""
        # Get all unsent transcripts for this parent since the given time
        transcript_data = await self._repository.get_unsent_transcripts(
            parent_id=parent_id,
            since=since,
        )

        if not transcript_data:
            return

        transcripts = []
        story_titles = []

        for data in transcript_data:
            transcripts.append(
                InteractionTranscript(
                    id=data["transcript_id"],
                    session_id=data["session_id"],
                    plain_text=data["plain_text"],
                    html_content=data["html_content"],
                    turn_count=data["turn_count"],
                    total_duration_ms=data["total_duration_ms"],
                    created_at=datetime.fromisoformat(data["created_at"]),
                )
            )
            story_titles.append(data.get("story_title", "互動故事"))

        result = await self._email_sender.send_batch_transcript_email(
            to_email=parent_email,
            transcripts=transcripts,
            story_titles=story_titles,
            digest_title=digest_title,
        )

        if result.success:
            # Mark all transcripts as sent
            for data in transcript_data:
                await self._repository.mark_transcript_email_sent(data["transcript_id"])
            logger.info(
                f"Digest email sent to {parent_email} with {len(transcripts)} transcripts"
            )
        else:
            logger.error(f"Failed to send digest to {parent_email}: {result.error}")

    async def queue_instant_notification(
        self,
        transcript_id: str,
        session_id: str,
        parent_id: str,
    ) -> None:
        """
        Queue an instant notification for a transcript.

        Called when a new transcript is generated and the parent
        has instant notification enabled.
        """
        # Get parent settings to check notification preference
        settings = await self._repository.get_interaction_settings(parent_id)
        if not settings:
            return

        if not settings.get("email_notifications", True):
            return

        frequency = NotificationFrequency(
            settings.get("notification_frequency", "daily")
        )

        if frequency == NotificationFrequency.INSTANT:
            # Mark for immediate processing
            await self._repository.queue_instant_notification(
                transcript_id=transcript_id,
                session_id=session_id,
                parent_id=parent_id,
            )


# Global scheduler instance
_scheduler: Optional[TranscriptScheduler] = None


def get_scheduler() -> Optional[TranscriptScheduler]:
    """Get the global scheduler instance."""
    return _scheduler


async def start_transcript_scheduler(
    repository: Repository,
    email_sender: EmailSender,
    generator: TranscriptGenerator,
    config: Optional[SchedulerConfig] = None,
) -> TranscriptScheduler:
    """
    Start the transcript scheduler.

    Args:
        repository: Database repository.
        email_sender: Email sender service.
        generator: Transcript generator.
        config: Optional scheduler configuration.

    Returns:
        The started scheduler instance.
    """
    global _scheduler

    if _scheduler is not None:
        await _scheduler.stop()

    _scheduler = TranscriptScheduler(
        repository=repository,
        email_sender=email_sender,
        generator=generator,
        config=config,
    )
    await _scheduler.start()
    return _scheduler


async def stop_transcript_scheduler() -> None:
    """Stop the transcript scheduler."""
    global _scheduler

    if _scheduler is not None:
        await _scheduler.stop()
        _scheduler = None
