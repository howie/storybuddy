"""Contract tests for Interaction Settings API.

T058 [P] [US3] Contract test for settings API.
Tests the REST API contract for interaction settings.
"""

import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import Mock, patch, MagicMock

from src.main import app


class TestInteractionSettingsContract:
    """Contract tests for Interaction Settings API."""

    @pytest.fixture
    def mock_auth(self):
        """Mock authentication middleware."""
        with patch("src.api.transcripts.verify_token") as mock:
            mock.return_value = {
                "parent_id": "parent-123",
                "user_id": "user-123",
            }
            yield mock

    @pytest.fixture
    def mock_repository(self):
        """Mock repository for settings."""
        with patch("src.api.transcripts.get_repository") as mock:
            repo = MagicMock()
            mock.return_value = repo
            yield repo

    @pytest.mark.asyncio
    async def test_get_settings_returns_correct_structure(
        self, mock_auth, mock_repository
    ):
        """GET /v1/interaction/settings should return correct structure."""
        mock_repository.get_interaction_settings.return_value = {
            "recording_enabled": False,
            "auto_transcribe": True,
            "retention_days": 30,
        }

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.get(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
            )

        assert response.status_code == 200
        data = response.json()

        # Verify required fields
        assert "recordingEnabled" in data
        assert "autoTranscribe" in data
        assert "retentionDays" in data

        # Verify types
        assert isinstance(data["recordingEnabled"], bool)
        assert isinstance(data["retentionDays"], int)

    @pytest.mark.asyncio
    async def test_get_settings_default_values(self, mock_auth, mock_repository):
        """GET should return default values for new users."""
        mock_repository.get_interaction_settings.return_value = None

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.get(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
            )

        assert response.status_code == 200
        data = response.json()

        # Default: recording disabled for privacy
        assert data["recordingEnabled"] is False
        # Default: 30 day retention
        assert data["retentionDays"] == 30

    @pytest.mark.asyncio
    async def test_update_settings_accepts_correct_format(
        self, mock_auth, mock_repository
    ):
        """PUT /v1/interaction/settings should accept correct format."""
        mock_repository.update_interaction_settings.return_value = True

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "recordingEnabled": True,
                    "autoTranscribe": True,
                    "retentionDays": 7,
                },
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_update_settings_partial_update(self, mock_auth, mock_repository):
        """PUT should allow partial updates."""
        mock_repository.update_interaction_settings.return_value = True

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "recordingEnabled": True,
                    # Other fields omitted
                },
            )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_update_settings_validates_retention_days(
        self, mock_auth, mock_repository
    ):
        """PUT should validate retention days range."""
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            # Test invalid retention period (too short)
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "retentionDays": 0,  # Invalid
                },
            )

        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_settings_requires_authentication(self):
        """Settings endpoints should require authentication."""
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            # GET without auth
            response = await client.get("/v1/interaction/settings")
            assert response.status_code == 401

            # PUT without auth
            response = await client.put(
                "/v1/interaction/settings",
                json={"recordingEnabled": True},
            )
            assert response.status_code == 401


class TestInteractionSettingsFieldValidation:
    """Field validation tests for settings API."""

    @pytest.fixture
    def mock_auth(self):
        """Mock authentication middleware."""
        with patch("src.api.transcripts.verify_token") as mock:
            mock.return_value = {
                "parent_id": "parent-123",
                "user_id": "user-123",
            }
            yield mock

    @pytest.fixture
    def mock_repository(self):
        """Mock repository for settings."""
        with patch("src.api.transcripts.get_repository") as mock:
            repo = MagicMock()
            mock.return_value = repo
            yield repo

    @pytest.mark.asyncio
    async def test_recording_enabled_must_be_boolean(
        self, mock_auth, mock_repository
    ):
        """recordingEnabled must be boolean."""
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "recordingEnabled": "yes",  # Invalid type
                },
            )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_retention_days_range(self, mock_auth, mock_repository):
        """retentionDays must be within valid range (1-365)."""
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            # Too high
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "retentionDays": 500,
                },
            )

        assert response.status_code == 422


class TestInteractionSettingsResponseFormat:
    """Tests for API response format consistency."""

    @pytest.fixture
    def mock_auth(self):
        """Mock authentication middleware."""
        with patch("src.api.transcripts.verify_token") as mock:
            mock.return_value = {
                "parent_id": "parent-123",
                "user_id": "user-123",
            }
            yield mock

    @pytest.fixture
    def mock_repository(self):
        """Mock repository for settings."""
        with patch("src.api.transcripts.get_repository") as mock:
            repo = MagicMock()
            mock.return_value = repo
            yield repo

    @pytest.mark.asyncio
    async def test_response_uses_camel_case(self, mock_auth, mock_repository):
        """Response should use camelCase for field names."""
        mock_repository.get_interaction_settings.return_value = {
            "recording_enabled": True,
            "auto_transcribe": True,
            "retention_days": 30,
        }

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.get(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
            )

        data = response.json()

        # Should be camelCase, not snake_case
        assert "recordingEnabled" in data
        assert "recording_enabled" not in data
        assert "autoTranscribe" in data
        assert "retentionDays" in data

    @pytest.mark.asyncio
    async def test_update_response_includes_updated_values(
        self, mock_auth, mock_repository
    ):
        """PUT response should include the updated values."""
        mock_repository.update_interaction_settings.return_value = True
        mock_repository.get_interaction_settings.return_value = {
            "recording_enabled": True,
            "auto_transcribe": True,
            "retention_days": 7,
        }

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.put(
                "/v1/interaction/settings",
                headers={"Authorization": "Bearer valid-token"},
                json={
                    "recordingEnabled": True,
                    "retentionDays": 7,
                },
            )

        data = response.json()
        assert data["success"] is True
        # Optionally includes updated settings
        if "settings" in data:
            assert data["settings"]["recordingEnabled"] is True
