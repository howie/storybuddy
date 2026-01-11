"""
T074 [US4] Implement transcript generator.

Generates formatted transcripts from interaction session data.
"""

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional

from jinja2 import Environment, FileSystemLoader

from src.models.enums import TriggerType
from src.models.interaction import AIResponse, InteractionSession, VoiceSegment
from src.models.transcript import InteractionTranscript


@dataclass
class TranscriptEntry:
    """A single entry in the transcript."""

    speaker_type: str  # "child", "ai", or "system"
    text: str
    timestamp: str
    was_interrupted: bool = False
    timestamp_ms: int = 0


class TranscriptGenerator:
    """
    Generates formatted transcripts from interaction sessions.

    Combines voice segments and AI responses into a chronological
    transcript with both plain text and HTML formats.
    """

    def __init__(self, templates_dir: Optional[Path] = None):
        """
        Initialize the generator.

        Args:
            templates_dir: Path to Jinja2 templates directory.
                          Defaults to templates/ in this package.
        """
        if templates_dir is None:
            templates_dir = Path(__file__).parent / "templates"

        self._env = Environment(
            loader=FileSystemLoader(templates_dir),
            autoescape=True,
        )

    def generate(
        self,
        session: InteractionSession,
        voice_segments: list[VoiceSegment],
        ai_responses: list[AIResponse],
        story_title: Optional[str] = None,
    ) -> InteractionTranscript:
        """
        Generate a transcript from session data.

        Args:
            session: The interaction session.
            voice_segments: Child's voice segments with transcriptions.
            ai_responses: AI responses during the session.
            story_title: Optional title of the story.

        Returns:
            Complete InteractionTranscript with plain text and HTML content.
        """
        # Build chronological list of entries
        entries = self._build_entries(session, voice_segments, ai_responses)

        # Generate plain text
        plain_text = self._generate_plain_text(entries, session)

        # Generate HTML
        html_content = self._generate_html(
            entries=entries,
            session=session,
            story_title=story_title or "互動故事",
        )

        # Calculate total duration
        total_duration_ms = 0
        if session.ended_at and session.started_at:
            total_duration_ms = int(
                (session.ended_at - session.started_at).total_seconds() * 1000
            )

        return InteractionTranscript(
            session_id=session.id,
            plain_text=plain_text,
            html_content=html_content,
            turn_count=len(voice_segments),
            total_duration_ms=total_duration_ms,
        )

    def _build_entries(
        self,
        session: InteractionSession,
        voice_segments: list[VoiceSegment],
        ai_responses: list[AIResponse],
    ) -> list[TranscriptEntry]:
        """Build a chronological list of transcript entries."""
        entries: list[TranscriptEntry] = []
        session_start = session.started_at

        # Create entries from voice segments
        for segment in voice_segments:
            timestamp_ms = int(
                (segment.started_at - session_start).total_seconds() * 1000
            )
            text = segment.transcript if segment.transcript else "[語音] 無法辨識"

            entries.append(
                TranscriptEntry(
                    speaker_type="child",
                    text=text,
                    timestamp=self._format_timestamp(timestamp_ms),
                    timestamp_ms=timestamp_ms,
                )
            )

        # Create entries from AI responses
        for response in ai_responses:
            # Find the associated segment to get timestamp
            timestamp_ms = 0
            if response.voice_segment_id:
                for segment in voice_segments:
                    if segment.id == response.voice_segment_id:
                        # AI response comes after segment ends
                        timestamp_ms = int(
                            (segment.ended_at - session_start).total_seconds() * 1000
                        )
                        break
            else:
                # For non-speech triggers, use creation time
                timestamp_ms = int(
                    (response.created_at - session_start).total_seconds() * 1000
                )

            # Determine if this is a system message
            speaker_type = "ai"
            if response.trigger_type == TriggerType.STORY_EVENT:
                speaker_type = "system"

            text = response.text
            if response.was_interrupted:
                text = f"{text} [中斷於 {response.interrupted_at_ms}ms]"

            entries.append(
                TranscriptEntry(
                    speaker_type=speaker_type,
                    text=text,
                    timestamp=self._format_timestamp(timestamp_ms),
                    was_interrupted=response.was_interrupted,
                    timestamp_ms=timestamp_ms,
                )
            )

        # Sort by timestamp
        entries.sort(key=lambda e: e.timestamp_ms)

        return entries

    def _format_timestamp(self, ms: int) -> str:
        """Format milliseconds as [MM:SS] timestamp."""
        total_seconds = ms // 1000
        minutes = total_seconds // 60
        seconds = total_seconds % 60
        return f"[{minutes:02d}:{seconds:02d}]"

    def _generate_plain_text(
        self,
        entries: list[TranscriptEntry],
        session: InteractionSession,
    ) -> str:
        """Generate plain text transcript."""
        if not entries:
            return "（此次互動沒有對話紀錄）"

        lines = []

        for entry in entries:
            speaker_label = self._get_speaker_label(entry.speaker_type)
            interrupt_marker = " [中斷]" if entry.was_interrupted else ""

            lines.append(f"{entry.timestamp} {speaker_label}：{entry.text}{interrupt_marker}")

        return "\n".join(lines)

    def _get_speaker_label(self, speaker_type: str) -> str:
        """Get display label for speaker type."""
        labels = {
            "child": "孩子",
            "ai": "AI",
            "system": "系統",
        }
        return labels.get(speaker_type, speaker_type)

    def _generate_html(
        self,
        entries: list[TranscriptEntry],
        session: InteractionSession,
        story_title: str,
    ) -> str:
        """Generate HTML transcript using template."""
        try:
            template = self._env.get_template("transcript_email.html")
        except Exception:
            # Fallback to simple HTML if template not found
            return self._generate_simple_html(entries, session, story_title)

        # Calculate duration text
        duration_text = self._format_duration(session)

        # Prepare template data
        template_entries = [
            {
                "speaker_type": entry.speaker_type,
                "text": entry.text,
                "timestamp": entry.timestamp,
                "was_interrupted": entry.was_interrupted,
            }
            for entry in entries
        ]

        return template.render(
            story_title=story_title,
            session_date=session.started_at.strftime("%Y年%m月%d日 %H:%M"),
            duration_text=duration_text,
            turn_count=len([e for e in entries if e.speaker_type == "child"]),
            entries=template_entries,
            unsubscribe_url="https://app.storybuddy.app/settings/notifications",
            current_year=datetime.now().year,
        )

    def _generate_simple_html(
        self,
        entries: list[TranscriptEntry],
        session: InteractionSession,
        story_title: str,
    ) -> str:
        """Generate simple HTML fallback when template unavailable."""
        html_parts = [
            "<!DOCTYPE html>",
            '<html lang="zh-TW">',
            "<head>",
            '<meta charset="UTF-8">',
            f"<title>{story_title} - 互動紀錄</title>",
            "<style>",
            "body { font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }",
            ".entry { margin: 10px 0; padding: 10px; border-radius: 8px; }",
            ".entry-child { background: #e8f5e9; }",
            ".entry-ai { background: #e3f2fd; }",
            ".entry-system { background: #fff3e0; }",
            ".timestamp { color: #666; font-size: 12px; }",
            ".interrupted { color: #c62828; font-size: 11px; }",
            "</style>",
            "</head>",
            "<body>",
            f"<h1>{story_title}</h1>",
            f"<p>日期：{session.started_at.strftime('%Y年%m月%d日 %H:%M')}</p>",
            f"<p>時長：{self._format_duration(session)}</p>",
            "<hr>",
        ]

        if entries:
            for entry in entries:
                speaker = self._get_speaker_label(entry.speaker_type)
                interrupt = '<span class="interrupted"> [中斷]</span>' if entry.was_interrupted else ""
                html_parts.append(
                    f'<div class="entry entry-{entry.speaker_type}">'
                    f'<span class="timestamp">{entry.timestamp}</span> '
                    f"<strong>{speaker}</strong>{interrupt}：{entry.text}"
                    "</div>"
                )
        else:
            html_parts.append("<p>（此次互動沒有對話紀錄）</p>")

        html_parts.extend(["</body>", "</html>"])
        return "\n".join(html_parts)

    def _format_duration(self, session: InteractionSession) -> str:
        """Format session duration as human-readable text."""
        if not session.ended_at or not session.started_at:
            return "未知"

        total_seconds = int(
            (session.ended_at - session.started_at).total_seconds()
        )

        if total_seconds < 60:
            return f"{total_seconds} 秒"

        minutes = total_seconds // 60
        seconds = total_seconds % 60

        if seconds > 0:
            return f"{minutes} 分 {seconds} 秒"
        return f"{minutes} 分鐘"
