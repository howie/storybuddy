-- User Voice Preferences
CREATE TABLE IF NOT EXISTS voice_preferences (
    user_id TEXT PRIMARY KEY,
    default_voice_id TEXT REFERENCES voice_characters(id),
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
