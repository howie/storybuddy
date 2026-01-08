import pytest
import shutil
from pathlib import Path
from src.services.tts.cache import TTSCache

@pytest.fixture
def cache_dir(tmp_path):
    """Create a temporary cache directory."""
    d = tmp_path / "tts_cache"
    d.mkdir()
    return d

@pytest.fixture
def tts_cache(cache_dir):
    return TTSCache(cache_dir=str(cache_dir))

def test_cache_key_generation(tts_cache):
    """Test consistent key generation."""
    key1 = tts_cache._generate_key("hello world", "voice-1", {"pitch": "high"})
    key2 = tts_cache._generate_key("hello world", "voice-1", {"pitch": "high"})
    key3 = tts_cache._generate_key("hello world", "voice-1", {"pitch": "low"})
    
    assert key1 == key2
    assert key1 != key3

def test_cache_miss(tts_cache):
    """Test getting non-existent item."""
    result = tts_cache.get("hello", "voice-1")
    assert result is None

def test_cache_set_and_get(tts_cache):
    """Test saving and retrieving audio."""
    audio_data = b"fake_audio_bytes"
    
    # Save
    tts_cache.set("hello", "voice-1", {}, audio_data)
    
    # Retrieve
    result = tts_cache.get("hello", "voice-1", {})
    assert result == audio_data

def test_cache_persistence(tts_cache, cache_dir):
    """Test that cache persists to disk."""
    audio_data = b"persist_me"
    tts_cache.set("persist", "voice-1", {}, audio_data)
    
    # New instance same dir
    new_cache = TTSCache(cache_dir=str(cache_dir))
    assert new_cache.get("persist", "voice-1", {}) == audio_data
