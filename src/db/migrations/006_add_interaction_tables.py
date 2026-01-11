"""
Migration: Add interaction tables for interactive story mode.

Feature: 006-interactive-story-mode
Date: 2026-01-10
"""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass


# Revision identifiers
revision = "006_interaction"
down_revision = None  # Update this to the previous migration
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create interaction-related tables."""
    import sqlalchemy as sa
    from alembic import op

    # InteractionSession table
    op.create_table(
        "interaction_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("story_id", sa.String(36), sa.ForeignKey("stories.id"), nullable=False),
        sa.Column("parent_id", sa.String(36), sa.ForeignKey("parents.id"), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column("mode", sa.String(20), nullable=False),  # 'interactive' | 'passive'
        sa.Column(
            "status", sa.String(20), nullable=False
        ),  # 'calibrating' | 'active' | 'paused' | 'completed' | 'error'
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    # VoiceSegment table
    op.create_table(
        "voice_segments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("interaction_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=False),
        sa.Column("transcript", sa.Text(), nullable=True),
        sa.Column("audio_url", sa.String(500), nullable=True),
        sa.Column("is_recorded", sa.Boolean(), nullable=False, default=False),
        sa.Column("audio_format", sa.String(20), nullable=False, default="opus"),
        sa.Column("duration_ms", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    # AIResponse table
    op.create_table(
        "ai_responses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("interaction_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "voice_segment_id",
            sa.String(36),
            sa.ForeignKey("voice_segments.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("audio_url", sa.String(500), nullable=True),
        sa.Column(
            "trigger_type", sa.String(20), nullable=False
        ),  # 'child_speech' | 'story_prompt' | 'timeout'
        sa.Column("was_interrupted", sa.Boolean(), nullable=False, default=False),
        sa.Column("interrupted_at_ms", sa.Integer(), nullable=True),
        sa.Column("response_latency_ms", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    # InteractionTranscript table
    op.create_table(
        "interaction_transcripts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("interaction_sessions.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("plain_text", sa.Text(), nullable=False),
        sa.Column("html_content", sa.Text(), nullable=False),
        sa.Column("turn_count", sa.Integer(), nullable=False),
        sa.Column("total_duration_ms", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("email_sent_at", sa.DateTime(), nullable=True),
    )

    # InteractionSettings table
    op.create_table(
        "interaction_settings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "parent_id",
            sa.String(36),
            sa.ForeignKey("parents.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("recording_enabled", sa.Boolean(), nullable=False, default=False),
        sa.Column("email_notifications", sa.Boolean(), nullable=False, default=True),
        sa.Column("notification_email", sa.String(255), nullable=True),
        sa.Column(
            "notification_frequency", sa.String(20), nullable=False, default="daily"
        ),  # 'instant' | 'daily' | 'weekly'
        sa.Column("interruption_threshold_ms", sa.Integer(), nullable=False, default=500),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    # NoiseCalibration table
    op.create_table(
        "noise_calibrations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("interaction_sessions.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("noise_floor_db", sa.Float(), nullable=False),
        sa.Column("calibrated_at", sa.DateTime(), nullable=False),
        sa.Column("sample_count", sa.Integer(), nullable=False),
        sa.Column("percentile_90", sa.Float(), nullable=False),
        sa.Column("calibration_duration_ms", sa.Integer(), nullable=False),
    )

    # Create indexes for performance
    op.create_index("idx_interaction_sessions_story_id", "interaction_sessions", ["story_id"])
    op.create_index("idx_interaction_sessions_parent_id", "interaction_sessions", ["parent_id"])
    op.create_index("idx_interaction_sessions_status", "interaction_sessions", ["status"])
    op.create_index("idx_voice_segments_session_id", "voice_segments", ["session_id"])
    op.create_index("idx_ai_responses_session_id", "ai_responses", ["session_id"])
    op.create_index(
        "idx_interaction_transcripts_email_sent_at", "interaction_transcripts", ["email_sent_at"]
    )


def downgrade() -> None:
    """Drop interaction-related tables."""
    from alembic import op

    # Drop indexes
    op.drop_index("idx_interaction_transcripts_email_sent_at")
    op.drop_index("idx_ai_responses_session_id")
    op.drop_index("idx_voice_segments_session_id")
    op.drop_index("idx_interaction_sessions_status")
    op.drop_index("idx_interaction_sessions_parent_id")
    op.drop_index("idx_interaction_sessions_story_id")

    # Drop tables in reverse order of creation
    op.drop_table("noise_calibrations")
    op.drop_table("interaction_settings")
    op.drop_table("interaction_transcripts")
    op.drop_table("ai_responses")
    op.drop_table("voice_segments")
    op.drop_table("interaction_sessions")
