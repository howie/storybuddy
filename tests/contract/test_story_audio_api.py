"""Contract tests for Story Audio API endpoints.

Tests verify the API conforms to the OpenAPI contract at:
/docs/features/000-StoryBuddy-mvp/contracts/openapi.yaml
"""

import pytest
from httpx import AsyncClient
from uuid import uuid4


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Test Parent", "email": f"test_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_voice_profile(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample voice profile for testing (pending status)."""
    response = await client.post(
        "/api/v1/voice-profiles",
        json={"parent_id": sample_parent["id"], "name": "Test Voice"},
    )
    return response.json()


@pytest.fixture
async def ready_voice_profile(client: AsyncClient, sample_parent: dict, test_db: None) -> dict:
    """Create a voice profile with 'ready' status for testing."""
    from uuid import UUID
    from src.db.repository import VoiceProfileRepository
    from src.models.voice import VoiceProfileCreate, VoiceProfileUpdate
    from src.models import VoiceProfileStatus

    # Create a voice profile
    profile = await VoiceProfileRepository.create(
        VoiceProfileCreate(parent_id=UUID(sample_parent["id"]), name="Ready Voice")
    )

    # Update it to ready status
    updated = await VoiceProfileRepository.update(
        profile.id,
        VoiceProfileUpdate(
            status=VoiceProfileStatus.READY,
            elevenlabs_voice_id="test_voice_id_123",
        ),
    )

    return {"id": str(updated.id), "status": updated.status.value} if updated else {}


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "Test Story",
            "content": "This is a test story content for audio generation.",
            "source": "imported",
        },
    )
    return response.json()


class TestGenerateStoryAudio:
    """Tests for POST /api/v1/stories/{story_id}/audio endpoint."""

    @pytest.mark.asyncio
    async def test_generate_audio_success(
        self,
        client: AsyncClient,
        sample_story: dict,
        ready_voice_profile: dict,
    ) -> None:
        """Test initiating audio generation for a story."""
        response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": ready_voice_profile["id"]},
        )

        # Per OpenAPI: returns 202 Accepted with processing status
        assert response.status_code == 202
        data = response.json()

        assert data["story_id"] == sample_story["id"]
        assert data["status"] == "processing"

    @pytest.mark.asyncio
    async def test_generate_audio_story_not_found(
        self,
        client: AsyncClient,
        sample_voice_profile: dict,
    ) -> None:
        """Test audio generation for non-existent story."""
        response = await client.post(
            f"/api/v1/stories/{uuid4()}/audio",
            json={"voice_profile_id": sample_voice_profile["id"]},
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_generate_audio_voice_profile_not_found(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test audio generation with non-existent voice profile."""
        response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": str(uuid4())},
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_generate_audio_voice_not_ready(
        self,
        client: AsyncClient,
        sample_story: dict,
        sample_voice_profile: dict,
    ) -> None:
        """Test audio generation with voice profile not in 'ready' status."""
        # Voice profile is in 'pending' status by default
        response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": sample_voice_profile["id"]},
        )

        # Should return 400 because voice is not ready
        assert response.status_code == 400
        data = response.json()
        assert "not ready" in data["detail"].lower()


class TestGetStoryAudio:
    """Tests for GET /api/v1/stories/{story_id}/audio endpoint."""

    @pytest.mark.asyncio
    async def test_get_audio_no_audio_generated(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test getting audio when none has been generated."""
        response = await client.get(
            f"/api/v1/stories/{sample_story['id']}/audio"
        )

        # No audio has been generated yet
        assert response.status_code == 404
        data = response.json()
        assert "not" in data["detail"].lower() and "generated" in data["detail"].lower()

    @pytest.mark.asyncio
    async def test_get_audio_story_not_found(
        self,
        client: AsyncClient,
    ) -> None:
        """Test getting audio for non-existent story."""
        response = await client.get(
            f"/api/v1/stories/{uuid4()}/audio"
        )

        assert response.status_code == 404


class TestStoryAudioStatus:
    """Tests for checking story audio generation status."""

    @pytest.mark.asyncio
    async def test_story_includes_audio_metadata(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test that story response includes audio-related metadata."""
        response = await client.get(f"/api/v1/stories/{sample_story['id']}")

        assert response.status_code == 200
        data = response.json()

        # Verify audio metadata fields exist
        assert "audio_file_path" in data
        assert "audio_generated_at" in data
        assert "word_count" in data
        assert "estimated_duration_minutes" in data

        # Initially, no audio is generated
        assert data["audio_file_path"] is None
        assert data["audio_generated_at"] is None
