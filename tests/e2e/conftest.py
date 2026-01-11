"""Pytest configuration and fixtures for E2E tests.

This module provides:
- Async HTTP client for testing
- Database setup/teardown
- Sample data fixtures
- Mocks for external services (ElevenLabs, Azure, Claude)
"""

import asyncio
import io
import wave
from collections.abc import AsyncGenerator, Generator
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from src.db.init import init_database, reset_database
from src.main import app

# =============================================================================
# Event Loop & Database Fixtures
# =============================================================================


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def test_db() -> AsyncGenerator[None, None]:
    """Initialize a fresh test database for each test."""
    await reset_database()
    await init_database()
    yield
    await reset_database()


@pytest_asyncio.fixture
async def client(test_db: None) -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for testing."""
    transport = ASGITransport(app=app)  # type: ignore[arg-type]
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# =============================================================================
# External Service Mocks
# =============================================================================


@pytest.fixture
def mock_elevenlabs() -> Generator[MagicMock, None, None]:
    """Mock ElevenLabs API for voice cloning and TTS."""
    with patch("src.services.voice.ElevenLabsClient") as mock:
        mock_instance = MagicMock()
        mock.return_value = mock_instance

        # Mock voice cloning
        mock_instance.clone_voice = AsyncMock(return_value="mock_elevenlabs_voice_id")

        # Mock TTS generation
        mock_instance.generate_audio = AsyncMock(return_value=b"mock_audio_content")

        # Mock delete voice
        mock_instance.delete_voice = AsyncMock(return_value=True)

        yield mock_instance


@pytest.fixture
def mock_azure_speech() -> Generator[MagicMock, None, None]:
    """Mock Azure Speech Services for STT."""
    with patch("src.services.speech.AzureSpeechClient") as mock:
        mock_instance = MagicMock()
        mock.return_value = mock_instance

        # Mock speech-to-text
        mock_instance.transcribe = AsyncMock(return_value="This is the transcribed text")

        yield mock_instance


@pytest.fixture
def mock_claude() -> Generator[MagicMock, None, None]:
    """Mock Anthropic Claude for story generation and Q&A."""
    with patch("src.services.llm.ClaudeClient") as mock:
        mock_instance = MagicMock()
        mock.return_value = mock_instance

        # Mock story generation
        mock_instance.generate_story = AsyncMock(
            return_value={
                "title": "AI Generated Story",
                "content": "Once upon a time in a magical forest...",
            }
        )

        # Mock Q&A response
        mock_instance.answer_question = AsyncMock(
            return_value={
                "answer": "The brave rabbit lived in the forest with its friends.",
                "is_in_scope": True,
            }
        )

        yield mock_instance


@pytest.fixture
def mock_all_external_services(
    mock_elevenlabs: MagicMock,
    mock_azure_speech: MagicMock,
    mock_claude: MagicMock,
) -> dict[str, MagicMock]:
    """Combine all external service mocks."""
    return {
        "elevenlabs": mock_elevenlabs,
        "azure_speech": mock_azure_speech,
        "claude": mock_claude,
    }


# =============================================================================
# Sample Data Fixtures
# =============================================================================


@pytest.fixture
def sample_parent_data() -> dict[str, Any]:
    """Sample parent data for testing."""
    return {"name": "Test Parent", "email": f"test_{uuid4().hex[:8]}@example.com"}


@pytest.fixture
def sample_voice_profile_data() -> dict[str, str]:
    """Sample voice profile data for testing."""
    return {"name": "Dad Voice"}


@pytest.fixture
def sample_story_data() -> dict[str, Any]:
    """Sample story data for testing."""
    return {
        "title": "The Brave Little Rabbit",
        "content": (
            "Once upon a time, there was a brave little rabbit who lived in a forest. "
            "The rabbit had many friends including a wise owl and a friendly deer. "
            "One day, they went on an adventure together to find the magical rainbow bridge."
        ),
        "source": "imported",
    }


@pytest.fixture
def sample_story_data_chinese() -> dict[str, Any]:
    """Sample Chinese story data for testing."""
    return {
        "title": "小兔子歷險記",
        "content": (
            "從前從前，有一隻可愛的小兔子住在森林裡。"
            "小兔子有很多好朋友，包括聰明的貓頭鷹和友善的小鹿。"
            "有一天，他們一起去尋找傳說中的彩虹橋。"
        ),
        "source": "imported",
    }


# =============================================================================
# Created Resource Fixtures
# =============================================================================


@pytest_asyncio.fixture
async def created_parent(client: AsyncClient, sample_parent_data: dict[str, Any]) -> dict[str, Any]:
    """Create and return a parent for testing."""
    response = await client.post("/api/v1/parents", json=sample_parent_data)
    assert response.status_code == 201
    return response.json()


@pytest_asyncio.fixture
async def created_story(
    client: AsyncClient,
    created_parent: dict[str, Any],
    sample_story_data: dict[str, Any],
) -> dict[str, Any]:
    """Create and return a story for testing."""
    story_data = {**sample_story_data, "parent_id": created_parent["id"]}
    response = await client.post("/api/v1/stories", json=story_data)
    assert response.status_code == 201
    return response.json()


@pytest_asyncio.fixture
async def created_voice_profile(
    client: AsyncClient,
    created_parent: dict[str, Any],
    sample_voice_profile_data: dict[str, str],
) -> dict[str, Any]:
    """Create and return a voice profile for testing."""
    profile_data = {**sample_voice_profile_data, "parent_id": created_parent["id"]}
    response = await client.post("/api/v1/voice-profiles", json=profile_data)
    assert response.status_code == 201
    return response.json()


@pytest_asyncio.fixture
async def ready_voice_profile(
    client: AsyncClient, created_parent: dict[str, Any], test_db: None
) -> dict[str, Any]:
    """Create a voice profile with 'ready' status for testing audio generation."""
    from src.db.repository import VoiceProfileRepository
    from src.models import VoiceProfileStatus
    from src.models.voice import VoiceProfileCreate, VoiceProfileUpdate

    profile = await VoiceProfileRepository.create(
        VoiceProfileCreate(parent_id=UUID(created_parent["id"]), name="Ready Voice")
    )

    updated = await VoiceProfileRepository.update(
        profile.id,
        VoiceProfileUpdate(
            status=VoiceProfileStatus.READY,
            elevenlabs_voice_id="test_voice_id_123",
        ),
    )

    return (
        {
            "id": str(updated.id),
            "parent_id": str(updated.parent_id),
            "name": updated.name,
            "status": updated.status.value,
            "elevenlabs_voice_id": updated.elevenlabs_voice_id,
        }
        if updated
        else {}
    )


@pytest_asyncio.fixture
async def created_qa_session(client: AsyncClient, created_story: dict[str, Any]) -> dict[str, Any]:
    """Create and return a Q&A session for testing."""
    response = await client.post("/api/v1/qa/sessions", json={"story_id": created_story["id"]})
    assert response.status_code == 201
    return response.json()


# =============================================================================
# Audio File Fixtures
# =============================================================================


@pytest.fixture
def mock_wav_file() -> bytes:
    """Generate a minimal valid WAV file for testing (1 second, 16kHz, mono)."""
    sample_rate = 16000
    duration_seconds = 1
    num_samples = sample_rate * duration_seconds

    # Create silence (zeros)
    audio_data = b"\x00\x00" * num_samples

    # Create WAV file in memory
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data)

    return buffer.getvalue()


@pytest.fixture
def mock_wav_file_30s() -> bytes:
    """Generate a 30-second WAV file for voice sample upload testing."""
    sample_rate = 16000
    duration_seconds = 30
    num_samples = sample_rate * duration_seconds

    # Create simple audio pattern
    audio_data = b"\x00\x10" * num_samples

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data)

    return buffer.getvalue()


@pytest.fixture
def mock_wav_file_too_short() -> bytes:
    """Generate a too-short WAV file (10 seconds) for validation testing."""
    sample_rate = 16000
    duration_seconds = 10  # Too short (minimum is 30s)
    num_samples = sample_rate * duration_seconds

    audio_data = b"\x00\x00" * num_samples

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data)

    return buffer.getvalue()


@pytest.fixture
def mock_mp3_file() -> bytes:
    """Generate a minimal MP3-like file header for testing."""
    # Minimal MP3 frame header
    return b"\xff\xfb\x90\x00" + b"\x00" * 1000


@pytest.fixture
def mock_invalid_audio_file() -> bytes:
    """Generate an invalid audio file for testing."""
    return b"This is not a valid audio file content"


# =============================================================================
# Utility Fixtures
# =============================================================================


@pytest.fixture
def random_uuid() -> str:
    """Generate a random UUID string."""
    return str(uuid4())


@pytest.fixture
def long_string_100() -> str:
    """Generate a string longer than 100 characters."""
    return "a" * 101


@pytest.fixture
def long_string_200() -> str:
    """Generate a string longer than 200 characters."""
    return "a" * 201


@pytest.fixture
def long_string_500() -> str:
    """Generate a string longer than 500 characters."""
    return "a" * 501


@pytest.fixture
def long_content_5000() -> str:
    """Generate content longer than 5000 characters."""
    return "test " * 1001  # 5005 characters
