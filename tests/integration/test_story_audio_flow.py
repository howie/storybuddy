"""Integration tests for story audio generation flow.

Tests the complete workflow from story creation through audio generation.
"""

from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from src.db.repository import VoiceProfileRepository
from src.models import VoiceProfileStatus
from src.models.voice import VoiceProfileCreate, VoiceProfileUpdate


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Audio Test Parent", "email": f"audio_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "Test Story for Audio",
            "content": "Once upon a time, there was a little rabbit who loved to explore the forest. "
            "Every day, the rabbit would hop along the path, looking for new friends.",
            "source": "imported",
        },
    )
    return response.json()


@pytest.fixture
async def ready_voice_profile(sample_parent: dict) -> dict:
    """Create a voice profile with 'ready' status for testing."""
    # Create a voice profile directly in database with ready status
    profile = await VoiceProfileRepository.create(
        VoiceProfileCreate(parent_id=UUID(sample_parent["id"]), name="Ready Voice")
    )

    # Update it to ready status with mock ElevenLabs voice ID
    updated = await VoiceProfileRepository.update(
        profile.id,
        VoiceProfileUpdate(
            status=VoiceProfileStatus.READY,
            elevenlabs_voice_id="test_voice_id_for_audio",
        ),
    )

    return {"id": str(updated.id), "status": updated.status.value} if updated else {}


class TestStoryAudioGenerationFlow:
    """Integration tests for story audio generation."""

    @pytest.mark.asyncio
    async def test_complete_audio_generation_flow(
        self,
        client: AsyncClient,
        sample_story: dict,
        ready_voice_profile: dict,
    ) -> None:
        """Test the complete flow from story to audio generation request."""
        # Step 1: Verify story exists and has no audio
        story_response = await client.get(f"/api/v1/stories/{sample_story['id']}")
        assert story_response.status_code == 200
        story_data = story_response.json()
        assert story_data["audio_file_path"] is None
        assert story_data["audio_generated_at"] is None

        # Step 2: Request audio generation
        generate_response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": ready_voice_profile["id"]},
        )

        # Should accept the request (background processing)
        assert generate_response.status_code == 202
        generate_data = generate_response.json()
        assert generate_data["story_id"] == sample_story["id"]
        assert generate_data["status"] == "processing"

    @pytest.mark.asyncio
    async def test_audio_generation_with_pending_voice_fails(
        self,
        client: AsyncClient,
        sample_story: dict,
        sample_parent: dict,
    ) -> None:
        """Test that audio generation fails with pending voice profile."""
        # Create a pending voice profile
        voice_response = await client.post(
            "/api/v1/voice-profiles",
            json={
                "parent_id": sample_parent["id"],
                "name": "Pending Voice",
            },
        )
        pending_profile = voice_response.json()

        # Try to generate audio
        generate_response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": pending_profile["id"]},
        )

        # Should fail because voice is not ready
        assert generate_response.status_code == 400
        assert "not ready" in generate_response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_audio_generation_with_invalid_story(
        self,
        client: AsyncClient,
        ready_voice_profile: dict,
    ) -> None:
        """Test audio generation with non-existent story."""
        generate_response = await client.post(
            f"/api/v1/stories/{uuid4()}/audio",
            json={"voice_profile_id": ready_voice_profile["id"]},
        )

        assert generate_response.status_code == 404

    @pytest.mark.asyncio
    async def test_audio_generation_with_invalid_voice(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test audio generation with non-existent voice profile."""
        generate_response = await client.post(
            f"/api/v1/stories/{sample_story['id']}/audio",
            json={"voice_profile_id": str(uuid4())},
        )

        assert generate_response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_audio_before_generation(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test getting audio before it has been generated."""
        audio_response = await client.get(f"/api/v1/stories/{sample_story['id']}/audio")

        # Should return 404 because no audio exists yet
        assert audio_response.status_code == 404
        assert "not" in audio_response.json()["detail"].lower()
        assert "generated" in audio_response.json()["detail"].lower()


class TestStoryMetadata:
    """Integration tests for story metadata related to audio."""

    @pytest.mark.asyncio
    async def test_story_includes_audio_metadata_fields(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test that stories include audio-related metadata."""
        response = await client.get(f"/api/v1/stories/{sample_story['id']}")

        assert response.status_code == 200
        data = response.json()

        # Verify required audio metadata fields
        assert "audio_file_path" in data
        assert "audio_generated_at" in data
        assert "word_count" in data
        assert "estimated_duration_minutes" in data

        # Word count should be calculated
        assert data["word_count"] > 0

        # Estimated duration should be calculated
        assert data["estimated_duration_minutes"] >= 1

    @pytest.mark.asyncio
    async def test_word_count_updates_on_content_change(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test that word count updates when content changes."""
        original_word_count = sample_story["word_count"]

        # Update with longer content
        new_content = sample_story["content"] + " " * 500 + "Additional content here."
        update_response = await client.put(
            f"/api/v1/stories/{sample_story['id']}",
            json={"content": new_content},
        )

        assert update_response.status_code == 200
        updated_data = update_response.json()

        # Word count should have changed
        assert updated_data["word_count"] != original_word_count
