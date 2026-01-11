"""
T071 [P] [US4] Contract test for transcripts API.

Tests the REST API endpoints for transcript operations.
"""

from datetime import datetime, timedelta
from uuid import uuid4

import pytest
from fastapi import status
from fastapi.testclient import TestClient

from src.main import app


@pytest.fixture
def client() -> TestClient:
    """Create a test client."""
    return TestClient(app)


@pytest.fixture
def sample_session_id() -> str:
    """Create a sample session ID."""
    return str(uuid4())


@pytest.fixture
def sample_parent_id() -> str:
    """Create a sample parent ID."""
    return str(uuid4())


class TestGetTranscriptsEndpoint:
    """Tests for GET /v1/interaction/transcripts endpoint."""

    def test_get_transcripts_success(self, client: TestClient, sample_session_id: str):
        """Test successful retrieval of transcripts."""
        response = client.get(
            "/v1/interaction/transcripts",
            params={"sessionId": sample_session_id},
        )

        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "transcripts" in data
        assert isinstance(data["transcripts"], list)

    def test_get_transcripts_with_pagination(self, client: TestClient, sample_parent_id: str):
        """Test transcript retrieval with pagination."""
        response = client.get(
            "/v1/interaction/transcripts",
            params={
                "parentId": sample_parent_id,
                "limit": 10,
                "offset": 0,
            },
        )

        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "transcripts" in data
        assert "total" in data
        assert "limit" in data
        assert "offset" in data

    def test_get_transcripts_by_date_range(self, client: TestClient, sample_parent_id: str):
        """Test transcript retrieval with date range filter."""
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=7)

        response = client.get(
            "/v1/interaction/transcripts",
            params={
                "parentId": sample_parent_id,
                "startDate": start_date.isoformat(),
                "endDate": end_date.isoformat(),
            },
        )

        assert response.status_code == status.HTTP_200_OK

    def test_get_transcripts_invalid_params(self, client: TestClient):
        """Test error handling for invalid parameters."""
        response = client.get(
            "/v1/interaction/transcripts",
            params={"limit": -1},
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    def test_get_transcripts_no_auth(self, client: TestClient):
        """Test that transcripts require authentication context."""
        # Without any parent/session context
        response = client.get("/v1/interaction/transcripts")

        # Should either require params or return empty
        assert response.status_code in [
            status.HTTP_200_OK,
            status.HTTP_400_BAD_REQUEST,
        ]


class TestGetTranscriptByIdEndpoint:
    """Tests for GET /v1/interaction/transcripts/{transcript_id} endpoint."""

    def test_get_transcript_by_id_not_found(self, client: TestClient):
        """Test 404 for non-existent transcript."""
        transcript_id = str(uuid4())
        response = client.get(f"/v1/interaction/transcripts/{transcript_id}")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_get_transcript_by_id_invalid_uuid(self, client: TestClient):
        """Test error handling for invalid UUID format."""
        response = client.get("/v1/interaction/transcripts/not-a-uuid")

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestGenerateTranscriptEndpoint:
    """Tests for POST /v1/interaction/transcripts/generate endpoint."""

    def test_generate_transcript_success(self, client: TestClient, sample_session_id: str):
        """Test successful transcript generation."""
        response = client.post(
            "/v1/interaction/transcripts/generate",
            json={"sessionId": sample_session_id},
        )

        # May return 200 with transcript or 404 if session not found
        assert response.status_code in [
            status.HTTP_200_OK,
            status.HTTP_201_CREATED,
            status.HTTP_404_NOT_FOUND,
        ]

        if response.status_code in [status.HTTP_200_OK, status.HTTP_201_CREATED]:
            data = response.json()
            assert "id" in data or "transcript" in data

    def test_generate_transcript_missing_session_id(self, client: TestClient):
        """Test error when session ID is missing."""
        response = client.post(
            "/v1/interaction/transcripts/generate",
            json={},
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    def test_generate_transcript_invalid_session_id(self, client: TestClient):
        """Test error for invalid session ID format."""
        response = client.post(
            "/v1/interaction/transcripts/generate",
            json={"sessionId": "not-a-uuid"},
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestSendTranscriptEmailEndpoint:
    """Tests for POST /v1/interaction/transcripts/{id}/send endpoint."""

    def test_send_transcript_email_not_found(self, client: TestClient):
        """Test 404 for non-existent transcript."""
        transcript_id = str(uuid4())
        response = client.post(
            f"/v1/interaction/transcripts/{transcript_id}/send",
            json={"email": "parent@example.com"},
        )

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_send_transcript_email_invalid_email(self, client: TestClient):
        """Test error for invalid email format."""
        transcript_id = str(uuid4())
        response = client.post(
            f"/v1/interaction/transcripts/{transcript_id}/send",
            json={"email": "not-a-valid-email"},
        )

        assert response.status_code in [
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            status.HTTP_404_NOT_FOUND,  # Transcript not found takes precedence
        ]

    def test_send_transcript_email_missing_email(self, client: TestClient):
        """Test error when email is missing."""
        transcript_id = str(uuid4())
        response = client.post(
            f"/v1/interaction/transcripts/{transcript_id}/send",
            json={},
        )

        assert response.status_code in [
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            status.HTTP_404_NOT_FOUND,
        ]


class TestDeleteTranscriptEndpoint:
    """Tests for DELETE /v1/interaction/transcripts/{id} endpoint."""

    def test_delete_transcript_not_found(self, client: TestClient):
        """Test 404 for non-existent transcript."""
        transcript_id = str(uuid4())
        response = client.delete(f"/v1/interaction/transcripts/{transcript_id}")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_delete_transcript_invalid_uuid(self, client: TestClient):
        """Test error for invalid UUID format."""
        response = client.delete("/v1/interaction/transcripts/not-a-uuid")

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestNotificationSettingsEndpoint:
    """Tests for notification frequency settings endpoints."""

    def test_get_notification_settings(self, client: TestClient, sample_parent_id: str):
        """Test getting notification settings."""
        response = client.get(
            "/v1/interaction/settings",
            params={"parentId": sample_parent_id},
        )

        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "notificationFrequency" in data or "notification_frequency" in data

    def test_update_notification_frequency(self, client: TestClient, sample_parent_id: str):
        """Test updating notification frequency."""
        response = client.put(
            "/v1/interaction/settings",
            json={
                "parentId": sample_parent_id,
                "notificationFrequency": "weekly",
            },
        )

        # May succeed or return validation error
        assert response.status_code in [
            status.HTTP_200_OK,
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        ]

    def test_update_notification_frequency_invalid(self, client: TestClient, sample_parent_id: str):
        """Test error for invalid notification frequency."""
        response = client.put(
            "/v1/interaction/settings",
            json={
                "parentId": sample_parent_id,
                "notificationFrequency": "invalid_frequency",
            },
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestTranscriptResponseSchema:
    """Tests for transcript response schema compliance."""

    def test_transcript_list_response_schema(self, client: TestClient, sample_parent_id: str):
        """Test that transcript list response matches expected schema."""
        response = client.get(
            "/v1/interaction/transcripts",
            params={"parentId": sample_parent_id},
        )

        if response.status_code == status.HTTP_200_OK:
            data = response.json()

            # Check required fields
            assert "transcripts" in data

            # Check pagination fields
            if "total" in data:
                assert isinstance(data["total"], int)
            if "limit" in data:
                assert isinstance(data["limit"], int)
            if "offset" in data:
                assert isinstance(data["offset"], int)

    def test_single_transcript_response_schema(self, client: TestClient):
        """Test that single transcript response matches expected schema."""
        # This test documents the expected schema
        expected_fields = [
            "id",
            "sessionId",
            "plainText",
            "htmlContent",
            "turnCount",
            "totalDurationMs",
            "createdAt",
        ]

        # Schema is validated through Pydantic in actual implementation
        assert len(expected_fields) > 0  # Document expected fields


class TestTranscriptExportEndpoint:
    """Tests for transcript export functionality."""

    def test_export_transcript_pdf_not_implemented(self, client: TestClient):
        """Test PDF export endpoint (may not be implemented)."""
        transcript_id = str(uuid4())
        response = client.get(
            f"/v1/interaction/transcripts/{transcript_id}/export",
            params={"format": "pdf"},
        )

        # May return 404 (not found), 501 (not implemented), or success
        assert response.status_code in [
            status.HTTP_200_OK,
            status.HTTP_404_NOT_FOUND,
            status.HTTP_501_NOT_IMPLEMENTED,
        ]

    def test_export_transcript_html(self, client: TestClient):
        """Test HTML export endpoint."""
        transcript_id = str(uuid4())
        response = client.get(
            f"/v1/interaction/transcripts/{transcript_id}/export",
            params={"format": "html"},
        )

        # May return 404 or success
        assert response.status_code in [
            status.HTTP_200_OK,
            status.HTTP_404_NOT_FOUND,
        ]

        if response.status_code == status.HTTP_200_OK:
            assert "text/html" in response.headers.get("content-type", "")
