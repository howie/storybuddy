"""Retention Service for automated cleanup of expired recordings.

T063 [US3] Add 30-day retention cleanup job.
Implements FR-019: Recording retention period with automatic cleanup.
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional, Callable, Awaitable
from dataclasses import dataclass

from src.services.interaction.recording_service import (
    RecordingService,
    get_recording_service,
)

logger = logging.getLogger(__name__)


@dataclass
class RetentionServiceConfig:
    """Configuration for Retention Service."""

    # How often to run cleanup (in seconds)
    cleanup_interval_seconds: int = 3600  # 1 hour
    # Default retention period (in days)
    default_retention_days: int = 30
    # Whether to run cleanup on startup
    cleanup_on_startup: bool = True
    # Maximum recordings to delete per cleanup run
    max_deletions_per_run: int = 1000


class RetentionService:
    """Service for managing retention of recordings.

    Runs periodic cleanup jobs to delete recordings that exceed
    their retention period (default 30 days per FR-019).
    """

    def __init__(
        self,
        config: Optional[RetentionServiceConfig] = None,
        recording_service: Optional[RecordingService] = None,
    ):
        """Initialize Retention Service.

        Args:
            config: Service configuration.
            recording_service: Recording service to use for cleanup.
        """
        self.config = config or RetentionServiceConfig()
        self._recording_service = recording_service
        self._cleanup_task: Optional[asyncio.Task] = None
        self._is_running = False
        self._last_cleanup: Optional[datetime] = None
        self._cleanup_callbacks: list[Callable[[int], Awaitable[None]]] = []

    @property
    def recording_service(self) -> RecordingService:
        """Get recording service (lazy initialization)."""
        if self._recording_service is None:
            self._recording_service = get_recording_service()
        return self._recording_service

    async def start(self) -> None:
        """Start the retention service (cleanup job).

        Begins periodic cleanup of expired recordings.
        """
        if self._is_running:
            logger.warning("Retention service already running")
            return

        self._is_running = True
        logger.info("Starting retention service")

        # Run initial cleanup if configured
        if self.config.cleanup_on_startup:
            await self.run_cleanup()

        # Start background task
        self._cleanup_task = asyncio.create_task(self._cleanup_loop())

    async def stop(self) -> None:
        """Stop the retention service."""
        self._is_running = False

        if self._cleanup_task:
            self._cleanup_task.cancel()
            try:
                await self._cleanup_task
            except asyncio.CancelledError:
                pass

        logger.info("Retention service stopped")

    async def _cleanup_loop(self) -> None:
        """Background loop for periodic cleanup."""
        while self._is_running:
            try:
                await asyncio.sleep(self.config.cleanup_interval_seconds)

                if self._is_running:
                    await self.run_cleanup()

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in cleanup loop: {e}")
                # Continue running despite errors
                await asyncio.sleep(60)  # Wait before retrying

    async def run_cleanup(self) -> int:
        """Run a single cleanup operation.

        Deletes all recordings that have exceeded their retention period.

        Returns:
            Number of recordings deleted.
        """
        logger.info("Starting retention cleanup")
        start_time = datetime.utcnow()

        try:
            deleted = await self.recording_service.cleanup_expired()

            self._last_cleanup = datetime.utcnow()
            duration_ms = int((self._last_cleanup - start_time).total_seconds() * 1000)

            logger.info(
                f"Retention cleanup complete: {deleted} recordings deleted "
                f"in {duration_ms}ms"
            )

            # Notify callbacks
            for callback in self._cleanup_callbacks:
                try:
                    await callback(deleted)
                except Exception as e:
                    logger.error(f"Cleanup callback error: {e}")

            return deleted

        except Exception as e:
            logger.error(f"Retention cleanup failed: {e}")
            raise

    def register_cleanup_callback(
        self,
        callback: Callable[[int], Awaitable[None]],
    ) -> None:
        """Register a callback to be called after each cleanup.

        Args:
            callback: Async function that takes the number of deleted recordings.
        """
        self._cleanup_callbacks.append(callback)

    def unregister_cleanup_callback(
        self,
        callback: Callable[[int], Awaitable[None]],
    ) -> None:
        """Unregister a cleanup callback.

        Args:
            callback: Previously registered callback.
        """
        if callback in self._cleanup_callbacks:
            self._cleanup_callbacks.remove(callback)

    @property
    def is_running(self) -> bool:
        """Check if the service is running."""
        return self._is_running

    @property
    def last_cleanup(self) -> Optional[datetime]:
        """Get timestamp of last cleanup run."""
        return self._last_cleanup

    def get_status(self) -> dict:
        """Get service status information.

        Returns:
            Status dictionary.
        """
        return {
            "isRunning": self._is_running,
            "cleanupIntervalSeconds": self.config.cleanup_interval_seconds,
            "defaultRetentionDays": self.config.default_retention_days,
            "lastCleanup": (
                self._last_cleanup.isoformat() + "Z"
                if self._last_cleanup else None
            ),
            "nextCleanup": (
                (
                    self._last_cleanup +
                    timedelta(seconds=self.config.cleanup_interval_seconds)
                ).isoformat() + "Z"
                if self._last_cleanup else None
            ),
        }


# Singleton instance
_retention_service: Optional[RetentionService] = None


def get_retention_service() -> RetentionService:
    """Get or create the global retention service instance."""
    global _retention_service
    if _retention_service is None:
        _retention_service = RetentionService()
    return _retention_service


async def start_retention_service() -> RetentionService:
    """Start the retention service.

    Convenience function for application startup.
    """
    service = get_retention_service()
    await service.start()
    return service


async def stop_retention_service() -> None:
    """Stop the retention service.

    Convenience function for application shutdown.
    """
    global _retention_service
    if _retention_service:
        await _retention_service.stop()
        _retention_service = None
