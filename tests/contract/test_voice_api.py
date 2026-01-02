"""Contract tests for Voice Profile API endpoints."""

from typing import Any
from uuid import uuid4

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestVoiceProfileAPI:
    """Tests for /api/v1/voice-profiles endpoints."""

    async def test_create_voice_profile_success(
        self,
        client: AsyncClient,
        sample_parent_data: dict[str, Any],
        sample_voice_profile_data: dict[str, str],
    ) -> None:
        """POST /api/v1/voice-profiles - creates a voice profile successfully."""
        # First create a parent
        parent_response = await client.post(
            "/api/v1/parents", json=sample_parent_data
        )
        assert parent_response.status_code == 201
        parent_id = parent_response.json()["id"]

        # Create voice profile
        response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, **sample_voice_profile_data},
        )

        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["name"] == sample_voice_profile_data["name"]
        assert data["parent_id"] == parent_id
        assert data["status"] == "pending"
        assert data["elevenlabs_voice_id"] is None
        assert data["sample_duration_seconds"] is None

    async def test_create_voice_profile_parent_not_found(
        self,
        client: AsyncClient,
        sample_voice_profile_data: dict[str, str],
    ) -> None:
        """POST /api/v1/voice-profiles - returns 404 for non-existent parent."""
        response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": str(uuid4()), **sample_voice_profile_data},
        )
        assert response.status_code == 404

    async def test_get_voice_profile_success(
        self,
        client: AsyncClient,
        sample_parent_data: dict[str, Any],
        sample_voice_profile_data: dict[str, str],
    ) -> None:
        """GET /api/v1/voice-profiles/{id} - returns voice profile details."""
        # Create parent and voice profile
        parent_response = await client.post(
            "/api/v1/parents", json=sample_parent_data
        )
        parent_id = parent_response.json()["id"]

        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, **sample_voice_profile_data},
        )
        profile_id = create_response.json()["id"]

        # Get voice profile
        response = await client.get(f"/api/v1/voice-profiles/{profile_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == profile_id
        assert data["name"] == sample_voice_profile_data["name"]

    async def test_get_voice_profile_not_found(
        self, client: AsyncClient
    ) -> None:
        """GET /api/v1/voice-profiles/{id} - returns 404 for non-existent profile."""
        response = await client.get(f"/api/v1/voice-profiles/{uuid4()}")
        assert response.status_code == 404

    async def test_list_voice_profiles(
        self,
        client: AsyncClient,
        sample_parent_data: dict[str, Any],
    ) -> None:
        """GET /api/v1/voice-profiles - lists voice profiles for parent."""
        # Create parent and two voice profiles
        parent_response = await client.post(
            "/api/v1/parents", json=sample_parent_data
        )
        parent_id = parent_response.json()["id"]

        await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, "name": "爸爸"},
        )
        await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, "name": "媽媽"},
        )

        # List voice profiles
        response = await client.get(
            f"/api/v1/voice-profiles?parent_id={parent_id}"
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        names = {p["name"] for p in data}
        assert names == {"爸爸", "媽媽"}

    async def test_delete_voice_profile(
        self,
        client: AsyncClient,
        sample_parent_data: dict[str, Any],
        sample_voice_profile_data: dict[str, str],
    ) -> None:
        """DELETE /api/v1/voice-profiles/{id} - deletes voice profile."""
        # Create parent and voice profile
        parent_response = await client.post(
            "/api/v1/parents", json=sample_parent_data
        )
        parent_id = parent_response.json()["id"]

        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, **sample_voice_profile_data},
        )
        profile_id = create_response.json()["id"]

        # Delete voice profile
        delete_response = await client.delete(
            f"/api/v1/voice-profiles/{profile_id}"
        )
        assert delete_response.status_code == 204

        # Verify deletion
        get_response = await client.get(
            f"/api/v1/voice-profiles/{profile_id}"
        )
        assert get_response.status_code == 404


@pytest.mark.asyncio
class TestVoiceUploadAPI:
    """Tests for /api/v1/voice-profiles/{id}/upload endpoint."""

    async def test_upload_voice_sample_profile_not_found(
        self, client: AsyncClient
    ) -> None:
        """POST /api/v1/voice-profiles/{id}/upload - returns 404 for non-existent profile."""
        # Create a minimal audio file for testing
        audio_content = b"RIFF" + b"\x00" * 1000  # Minimal WAV-like content

        response = await client.post(
            f"/api/v1/voice-profiles/{uuid4()}/upload",
            files={"audio": ("sample.wav", audio_content, "audio/wav")},
        )
        assert response.status_code == 404


@pytest.mark.asyncio
class TestVoicePreviewAPI:
    """Tests for /api/v1/voice-profiles/{id}/preview endpoint."""

    async def test_preview_profile_not_found(
        self, client: AsyncClient
    ) -> None:
        """POST /api/v1/voice-profiles/{id}/preview - returns 404 for non-existent profile."""
        response = await client.post(
            f"/api/v1/voice-profiles/{uuid4()}/preview",
            json={"text": "測試預覽文字"},
        )
        assert response.status_code == 404

    async def test_preview_profile_not_ready(
        self,
        client: AsyncClient,
        sample_parent_data: dict[str, Any],
        sample_voice_profile_data: dict[str, str],
    ) -> None:
        """POST /api/v1/voice-profiles/{id}/preview - returns 400 if profile not ready."""
        # Create parent and voice profile (status will be 'pending')
        parent_response = await client.post(
            "/api/v1/parents", json=sample_parent_data
        )
        parent_id = parent_response.json()["id"]

        create_response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, **sample_voice_profile_data},
        )
        profile_id = create_response.json()["id"]

        # Try to preview (should fail because status is 'pending')
        response = await client.post(
            f"/api/v1/voice-profiles/{profile_id}/preview",
            json={"text": "測試預覽文字"},
        )
        assert response.status_code == 400
        assert "not ready" in response.json()["detail"].lower()
