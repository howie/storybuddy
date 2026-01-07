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
