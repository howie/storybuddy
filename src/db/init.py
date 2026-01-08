"""Database initialization and schema management for StoryBuddy."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import aiosqlite

from src.config import get_settings

settings = get_settings()

# SQLite schema from data-model.md
SCHEMA = """
-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- Parent
CREATE TABLE IF NOT EXISTS parent (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- VoiceProfile
CREATE TABLE IF NOT EXISTS voice_profile (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    elevenlabs_voice_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'failed')),
    sample_duration_seconds INTEGER CHECK (sample_duration_seconds IS NULL OR (sample_duration_seconds >= 30 AND sample_duration_seconds <= 180)),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_voice_profile_parent_id ON voice_profile(parent_id);
CREATE INDEX IF NOT EXISTS idx_voice_profile_status ON voice_profile(status);

-- VoiceAudio
CREATE TABLE IF NOT EXISTS voice_audio (
    id TEXT PRIMARY KEY,
    voice_profile_id TEXT NOT NULL REFERENCES voice_profile(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    duration_seconds INTEGER NOT NULL,
    format TEXT NOT NULL CHECK (format IN ('wav', 'mp3', 'm4a')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Story
CREATE TABLE IF NOT EXISTS story (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('imported', 'ai_generated')),
    keywords TEXT,
    word_count INTEGER NOT NULL CHECK (word_count <= 5000),
    estimated_duration_minutes INTEGER,
    audio_file_path TEXT,
    audio_generated_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_story_parent_id ON story(parent_id);
CREATE INDEX IF NOT EXISTS idx_story_source ON story(source);
CREATE INDEX IF NOT EXISTS idx_story_created_at ON story(created_at DESC);

-- QASession
CREATE TABLE IF NOT EXISTS qa_session (
    id TEXT PRIMARY KEY,
    story_id TEXT NOT NULL REFERENCES story(id) ON DELETE CASCADE,
    started_at TEXT NOT NULL DEFAULT (datetime('now')),
    ended_at TEXT,
    message_count INTEGER NOT NULL DEFAULT 0 CHECK (message_count <= 10),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'timeout'))
);

CREATE INDEX IF NOT EXISTS idx_qa_session_story_id ON qa_session(story_id);
CREATE INDEX IF NOT EXISTS idx_qa_session_started_at ON qa_session(started_at DESC);

-- QAMessage
CREATE TABLE IF NOT EXISTS qa_message (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES qa_session(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('child', 'assistant')),
    content TEXT NOT NULL,
    is_in_scope INTEGER,
    audio_input_path TEXT,
    audio_output_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    sequence INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_qa_message_session_id_sequence ON qa_message(session_id, sequence);

-- PendingQuestion
CREATE TABLE IF NOT EXISTS pending_question (
    id TEXT PRIMARY KEY,
    parent_id TEXT NOT NULL REFERENCES parent(id) ON DELETE CASCADE,
    story_id TEXT REFERENCES story(id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    asked_at TEXT NOT NULL DEFAULT (datetime('now')),
    answer TEXT,
    answer_audio_path TEXT,
    answered_at TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'answered'))
);


CREATE INDEX IF NOT EXISTS idx_pending_question_parent_id_status ON pending_question(parent_id, status);
CREATE INDEX IF NOT EXISTS idx_pending_question_asked_at ON pending_question(asked_at DESC);

-- Voice Kits
CREATE TABLE IF NOT EXISTS voice_kits (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    provider TEXT NOT NULL,
    version TEXT NOT NULL,
    download_size INTEGER DEFAULT 0,
    is_builtin INTEGER DEFAULT 1,
    is_downloaded INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Voice Characters
CREATE TABLE IF NOT EXISTS voice_characters (
    id TEXT PRIMARY KEY,
    kit_id TEXT NOT NULL REFERENCES voice_kits(id),
    name TEXT NOT NULL,
    provider_voice_id TEXT NOT NULL,
    ssml_options TEXT, -- JSON
    gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'neutral')),
    age_group TEXT NOT NULL CHECK (age_group IN ('child', 'adult', 'senior')),
    style TEXT NOT NULL CHECK (style IN ('narrator', 'character', 'both')),
    preview_url TEXT,
    preview_text TEXT,
    UNIQUE(kit_id, name)
);

CREATE INDEX IF NOT EXISTS idx_voice_characters_kit ON voice_characters(kit_id);

-- User Voice Preferences
CREATE TABLE IF NOT EXISTS voice_preferences (
    user_id TEXT PRIMARY KEY,
    default_voice_id TEXT REFERENCES voice_characters(id),
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Story Voice Mappings (from T041 but included in init.py for completeness/future proofing if desired, though task says T041 is later. I will omit T041 table here to follow phase structure strictly? No, init.py should ideally have full schema if possible, but I will stick to what I added in migrations.)
"""


@asynccontextmanager
async def get_db_connection() -> AsyncGenerator[aiosqlite.Connection, None]:
    """Get a database connection as an async context manager."""
    db_path = str(settings.db_path)
    conn = await aiosqlite.connect(db_path)
    await conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = aiosqlite.Row
    try:
        yield conn
    finally:
        await conn.close()


async def init_database() -> None:
    """Initialize the database schema."""
    settings.ensure_directories()
    db_path = str(settings.db_path)

    async with aiosqlite.connect(db_path) as db:
        await db.execute("PRAGMA foreign_keys = ON")
        await db.executescript(SCHEMA)
        await db.commit()


async def reset_database() -> None:
    """Reset the database by dropping all tables and recreating them.

    WARNING: This will delete all data!
    """
    settings.ensure_directories()
    db_path = str(settings.db_path)

    async with aiosqlite.connect(db_path) as db:
        # Drop all tables in reverse dependency order
        tables = [
            "pending_question",
            "qa_message",
            "qa_session",
            "story",
            "voice_audio",
            "voice_profile",
            "parent",
            "voice_preferences",
            "voice_characters",
            "voice_kits",
        ]

        for table in tables:
            await db.execute(f"DROP TABLE IF EXISTS {table}")

        await db.commit()

    # Recreate schema
    await init_database()


if __name__ == "__main__":
    import asyncio

    asyncio.run(init_database())
    print("Database initialized successfully!")
