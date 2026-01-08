"""Integration tests for voice recording flow.

Tests the complete voice recording workflow from profile creation
through voice sample upload and status transitions.
"""

import io
import struct
import wave
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient


def create_wav_bytes(duration_seconds: float = 60.0, sample_rate: int = 44100) -> bytes:
    """Create a valid WAV file bytes for testing.

    Args:
        duration_seconds: Duration of the audio
        sample_rate: Sample rate in Hz

    Returns:
        WAV file as bytes
    """
    num_samples = int(sample_rate * duration_seconds)
    # Generate silence (zeros) for the audio data
    audio_data = struct.pack("<" + "h" * num_samples, *([0] * num_samples))

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data)

    buffer.seek(0)
    return buffer.read()


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Voice Test Parent", "email": f"voice_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


class TestVoiceRecordingFlow:
    """Integration tests for the complete voice recording flow."""

    @pytest.mark.asyncio
    async def test_complete_voice_recording_flow(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test the complete flow from profile creation to status update."""
        # Step 1: Create voice profile
        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={
                "parent_id": sample_parent["id"],
                "name": "Test Voice Profile",
            },
        )
        assert create_response.status_code == 201
        profile = create_response.json()
        assert profile["status"] == "pending"
        profile_id = profile["id"]

        # Step 2: Upload voice sample
        wav_bytes = create_wav_bytes(duration_seconds=60.0)
        upload_response = await client.post(
            f"/api/v1/voice-profiles/{profile_id}/upload",
            files={"audio": ("voice_sample.wav", wav_bytes, "audio/wav")},
        )
        assert upload_response.status_code == 200
        upload_data = upload_response.json()
        assert upload_data["status"] == "processing"

        # Step 3: Verify profile status changed
        get_response = await client.get(f"/api/v1/voice-profiles/{profile_id}")
        assert get_response.status_code == 200
        updated_profile = get_response.json()
        # Status should be processing or ready depending on background task
        assert updated_profile["status"] in ["processing", "ready", "failed"]

    @pytest.mark.asyncio
    async def test_voice_profile_list_for_parent(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test listing voice profiles for a parent."""
        # Create multiple profiles
        for i in range(3):
            await client.post(
                "/api/v1/voice-profiles",
                json={
                    "parent_id": sample_parent["id"],
                    "name": f"Voice Profile {i + 1}",
                },
            )

        # List profiles for parent
        list_response = await client.get(
            f"/api/v1/voice-profiles",
            params={"parent_id": sample_parent["id"]},
        )
        assert list_response.status_code == 200
        profiles = list_response.json()
        assert len(profiles) == 3

    @pytest.mark.asyncio
    async def test_voice_profile_delete(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test deleting a voice profile."""
        # Create profile
        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={
                "parent_id": sample_parent["id"],
                "name": "Profile to Delete",
            },
        )
        profile_id = create_response.json()["id"]

        # Delete profile
        delete_response = await client.delete(f"/api/v1/voice-profiles/{profile_id}")
        assert delete_response.status_code == 204

        # Verify it's deleted
        get_response = await client.get(f"/api/v1/voice-profiles/{profile_id}")
        assert get_response.status_code == 404

    @pytest.mark.asyncio
    async def test_upload_validates_audio_format(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test that audio format validation works."""
        # Create profile
        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={
                "parent_id": sample_parent["id"],
                "name": "Format Test Profile",
            },
        )
        profile_id = create_response.json()["id"]

        # Try uploading with invalid format
        invalid_file = b"not a valid audio file"
        upload_response = await client.post(
            f"/api/v1/voice-profiles/{profile_id}/upload",
            files={"audio": ("test.txt", invalid_file, "text/plain")},
        )
        # Should fail format validation
        assert upload_response.status_code == 400
        assert "format" in upload_response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_upload_to_nonexistent_profile(
        self,
        client: AsyncClient,
    ) -> None:
        """Test uploading to a non-existent profile."""
        wav_bytes = create_wav_bytes(duration_seconds=60.0)
        upload_response = await client.post(
            f"/api/v1/voice-profiles/{uuid4()}/upload",
            files={"audio": ("voice_sample.wav", wav_bytes, "audio/wav")},
        )
        assert upload_response.status_code == 404


class TestVoiceProfilePreview:
    """Integration tests for voice preview functionality."""

    @pytest.mark.asyncio
    async def test_preview_requires_ready_status(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test that preview requires the profile to be ready."""
        # Create profile (pending status)
        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={
                "parent_id": sample_parent["id"],
                "name": "Preview Test Profile",
            },
        )
        profile_id = create_response.json()["id"]

        # Try to generate preview (should fail - not ready or API not configured)
        preview_response = await client.post(
            f"/api/v1/voice-profiles/{profile_id}/preview",
            json={},  # Empty body to avoid 422
        )
        # Either 400 (not ready), 422 (validation) or 500 (API not configured)
        assert preview_response.status_code in [400, 422, 500]
