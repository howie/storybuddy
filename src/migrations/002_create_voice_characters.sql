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
