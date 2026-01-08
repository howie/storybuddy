"""Contract tests for Questions API endpoints.

Tests verify the API conforms to the OpenAPI contract at:
/docs/features/000-StoryBuddy-mvp/contracts/openapi.yaml
"""

from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from src.db.repository import PendingQuestionRepository
from src.models.question import PendingQuestionCreate


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Question Test Parent", "email": f"q_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "Test Story",
            "content": "A story for testing questions.",
            "source": "imported",
        },
    )
    return response.json()


@pytest.fixture
async def sample_pending_question(sample_parent: dict, sample_story: dict) -> dict:
    """Create a sample pending question for testing."""
    question = await PendingQuestionRepository.create(
        PendingQuestionCreate(
            parent_id=UUID(sample_parent["id"]),
            story_id=UUID(sample_story["id"]),
            qa_session_id=None,
            question="為什麼天空是藍色的？",
        )
    )
    return {
        "id": str(question.id),
        "parent_id": str(question.parent_id),
        "story_id": str(question.story_id),
        "question": question.question,
        "status": question.status.value,
    }


class TestGetPendingQuestions:
    """Tests for GET /api/v1/questions endpoint."""

    @pytest.mark.asyncio
    async def test_get_questions_success(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_pending_question: dict,
    ) -> None:
        """Test getting pending questions for a parent."""
        response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"]},
        )

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)
        assert len(data) >= 1

        # Find our question
        question = next((q for q in data if q["id"] == sample_pending_question["id"]), None)
        assert question is not None
        assert question["question"] == "為什麼天空是藍色的？"
        assert question["status"] == "pending"

    @pytest.mark.asyncio
    async def test_get_questions_empty(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test getting questions when none exist."""
        # Create a new parent with no questions
        new_parent_response = await client.post(
            "/api/v1/parents",
            json={"name": "Empty Parent", "email": f"empty_{uuid4().hex[:8]}@example.com"},
        )
        new_parent = new_parent_response.json()

        response = await client.get(
            "/api/v1/questions",
            params={"parent_id": new_parent["id"]},
        )

        assert response.status_code == 200
        data = response.json()
        assert data == []

    @pytest.mark.asyncio
    async def test_get_questions_requires_parent_id(
        self,
        client: AsyncClient,
    ) -> None:
        """Test that getting questions requires parent_id parameter."""
        response = await client.get("/api/v1/questions")

        # FastAPI returns 422 for missing required query params
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_get_questions_filter_by_status(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_pending_question: dict,
    ) -> None:
        """Test filtering questions by status."""
        # Get pending questions only
        response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"], "status": "pending"},
        )

        assert response.status_code == 200
        data = response.json()

        # All returned questions should be pending
        for question in data:
            assert question["status"] == "pending"


class TestGetSingleQuestion:
    """Tests for GET /api/v1/questions/{question_id} endpoint."""

    @pytest.mark.asyncio
    async def test_get_question_success(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_pending_question: dict,
    ) -> None:
        """Test getting a single question by ID."""
        response = await client.get(
            f"/api/v1/questions/{sample_pending_question['id']}",
        )

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == sample_pending_question["id"]
        assert data["question"] == "為什麼天空是藍色的？"

    @pytest.mark.asyncio
    async def test_get_question_not_found(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test getting a non-existent question."""
        response = await client.get(
            f"/api/v1/questions/{uuid4()}",
        )

        assert response.status_code == 404


class TestAnswerQuestion:
    """Tests for POST /api/v1/questions/{question_id}/answer endpoint."""

    @pytest.mark.asyncio
    async def test_answer_question_with_text(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_pending_question: dict,
    ) -> None:
        """Test answering a question with text."""
        response = await client.post(
            f"/api/v1/questions/{sample_pending_question['id']}/answer",
            json={"answer": "因為陽光在大氣中散射，藍色光散射得最多！"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "answered"
        assert data["answer"] == "因為陽光在大氣中散射，藍色光散射得最多！"
        assert data["answered_at"] is not None

    @pytest.mark.asyncio
    async def test_answer_question_not_found(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test answering a non-existent question."""
        response = await client.post(
            f"/api/v1/questions/{uuid4()}/answer",
            json={"answer": "Test answer"},
        )

        assert response.status_code == 404


class TestQuestionLifecycle:
    """Integration tests for question lifecycle."""

    @pytest.mark.asyncio
    async def test_question_status_changes_after_answer(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_pending_question: dict,
    ) -> None:
        """Test that question status changes from pending to answered."""
        # Verify initial status
        get_response = await client.get(
            f"/api/v1/questions/{sample_pending_question['id']}",
        )
        assert get_response.json()["status"] == "pending"

        # Answer the question
        await client.post(
            f"/api/v1/questions/{sample_pending_question['id']}/answer",
            json={"answer": "Test answer"},
        )

        # Verify status changed
        get_response = await client.get(
            f"/api/v1/questions/{sample_pending_question['id']}",
        )
        assert get_response.json()["status"] == "answered"

    @pytest.mark.asyncio
    async def test_answered_questions_filtered_correctly(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test that answered questions are filtered correctly."""
        # Create two questions
        q1 = await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="Question 1",
            )
        )
        await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="Question 2",
            )
        )

        # Answer one question
        await client.post(
            f"/api/v1/questions/{q1.id}/answer",
            json={"answer": "Answer 1"},
        )

        # Filter by pending - should not include answered
        pending_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"], "status": "pending"},
        )
        pending_questions = pending_response.json()

        # Question 1 should not be in pending list
        q1_in_pending = any(q["id"] == str(q1.id) for q in pending_questions)
        assert not q1_in_pending

        # Filter by answered - should include answered
        answered_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"], "status": "answered"},
        )
        answered_questions = answered_response.json()

        # Question 1 should be in answered list
        q1_in_answered = any(q["id"] == str(q1.id) for q in answered_questions)
        assert q1_in_answered
