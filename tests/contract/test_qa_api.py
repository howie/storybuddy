"""Contract tests for Q&A API endpoints.

Tests verify the API conforms to the OpenAPI contract at:
/docs/features/000-StoryBuddy-mvp/contracts/openapi.yaml
"""

from uuid import uuid4

import pytest
from httpx import AsyncClient


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Test Parent", "email": f"test_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "Test Story for Q&A",
            "content": "Once upon a time, there was a brave little rabbit who lived in a forest. "
            "The rabbit had many friends including a wise owl and a friendly deer. "
            "One day, they went on an adventure together.",
            "source": "imported",
        },
    )
    return response.json()


@pytest.fixture
async def sample_qa_session(client: AsyncClient, sample_story: dict) -> dict:
    """Create a sample Q&A session for testing."""
    response = await client.post(
        "/api/v1/qa/sessions",
        json={"story_id": sample_story["id"]},
    )
    return response.json()


class TestStartQASession:
    """Tests for POST /api/v1/qa/sessions endpoint."""

    @pytest.mark.asyncio
    async def test_start_session_success(self, client: AsyncClient, sample_story: dict) -> None:
        """Test starting a new Q&A session."""
        response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )

        assert response.status_code == 201
        data = response.json()

        assert "id" in data
        assert data["story_id"] == sample_story["id"]
        assert data["status"] == "active"
        assert data["message_count"] == 0
        assert "started_at" in data
        assert data["ended_at"] is None

    @pytest.mark.asyncio
    async def test_start_session_story_not_found(self, client: AsyncClient) -> None:
        """Test starting a session with non-existent story."""
        response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": str(uuid4())},
        )

        assert response.status_code == 404


class TestGetQASession:
    """Tests for GET /api/v1/qa/sessions/{session_id} endpoint."""

    @pytest.mark.asyncio
    async def test_get_session_success(self, client: AsyncClient, sample_qa_session: dict) -> None:
        """Test getting a Q&A session by ID."""
        response = await client.get(f"/api/v1/qa/sessions/{sample_qa_session['id']}")

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == sample_qa_session["id"]
        assert "messages" in data
        assert isinstance(data["messages"], list)

    @pytest.mark.asyncio
    async def test_get_session_not_found(self, client: AsyncClient) -> None:
        """Test getting a non-existent session."""
        response = await client.get(f"/api/v1/qa/sessions/{uuid4()}")

        assert response.status_code == 404


class TestEndQASession:
    """Tests for PATCH /api/v1/qa/sessions/{session_id} endpoint."""

    @pytest.mark.asyncio
    async def test_end_session_success(self, client: AsyncClient, sample_qa_session: dict) -> None:
        """Test ending a Q&A session."""
        response = await client.patch(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}",
            json={"status": "completed"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "completed"
        assert data["ended_at"] is not None

    @pytest.mark.asyncio
    async def test_end_session_timeout(self, client: AsyncClient, sample_qa_session: dict) -> None:
        """Test ending a session with timeout status."""
        response = await client.patch(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}",
            json={"status": "timeout"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "timeout"

    @pytest.mark.asyncio
    async def test_end_session_not_found(self, client: AsyncClient) -> None:
        """Test ending a non-existent session."""
        response = await client.patch(
            f"/api/v1/qa/sessions/{uuid4()}",
            json={"status": "completed"},
        )

        assert response.status_code == 404


class TestSendQAMessage:
    """Tests for POST /api/v1/qa/sessions/{session_id}/messages endpoint."""

    @pytest.mark.asyncio
    async def test_send_message_success(self, client: AsyncClient, sample_qa_session: dict) -> None:
        """Test sending a question and receiving a response."""
        response = await client.post(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}/messages",
            json={"content": "Who lived in the forest?"},
        )

        assert response.status_code == 200
        data = response.json()

        assert "user_message" in data
        assert "assistant_message" in data
        assert "is_in_scope" in data

        # User message should be the child's question
        assert data["user_message"]["role"] == "child"
        assert data["user_message"]["content"] == "Who lived in the forest?"

        # Assistant message should be present
        assert data["assistant_message"]["role"] == "assistant"
        assert len(data["assistant_message"]["content"]) > 0

    @pytest.mark.asyncio
    async def test_send_message_session_not_found(self, client: AsyncClient) -> None:
        """Test sending message to non-existent session."""
        response = await client.post(
            f"/api/v1/qa/sessions/{uuid4()}/messages",
            json={"content": "Test question"},
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_send_message_session_completed(
        self, client: AsyncClient, sample_qa_session: dict
    ) -> None:
        """Test sending message to a completed session."""
        # First, end the session
        await client.patch(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}",
            json={"status": "completed"},
        )

        # Try to send a message
        response = await client.post(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}/messages",
            json={"content": "Test question"},
        )

        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_message_limit_enforcement(
        self, client: AsyncClient, sample_qa_session: dict
    ) -> None:
        """Test that message limit (10) is enforced."""
        # Send 10 messages (5 exchanges)
        for i in range(5):
            response = await client.post(
                f"/api/v1/qa/sessions/{sample_qa_session['id']}/messages",
                json={"content": f"Question {i + 1}"},
            )
            assert response.status_code == 200

        # The 6th exchange should fail (would be 11-12 messages)
        response = await client.post(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}/messages",
            json={"content": "One more question"},
        )

        assert response.status_code == 400
        data = response.json()
        assert "limit" in data["detail"].lower()


class TestQASessionMessages:
    """Tests for Q&A session with messages."""

    @pytest.mark.asyncio
    async def test_get_session_with_messages(
        self, client: AsyncClient, sample_qa_session: dict
    ) -> None:
        """Test getting a session includes all messages."""
        # Send a message
        await client.post(
            f"/api/v1/qa/sessions/{sample_qa_session['id']}/messages",
            json={"content": "What was the rabbit like?"},
        )

        # Get the session
        response = await client.get(f"/api/v1/qa/sessions/{sample_qa_session['id']}")

        assert response.status_code == 200
        data = response.json()

        assert len(data["messages"]) == 2  # user message + assistant response
        assert data["message_count"] == 2
