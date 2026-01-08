"""Integration tests for pending questions flow.

Tests the complete workflow for out-of-scope questions from Q&A sessions.
"""

from unittest.mock import AsyncMock, patch
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from src.db.repository import PendingQuestionRepository
from src.models.question import PendingQuestionCreate
from src.services.qa_handler import QAResponse


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Pending Q Parent", "email": f"pq_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "小熊找朋友",
            "content": "從前有一隻小熊，牠住在森林裡。小熊很想交朋友，於是牠開始了一段冒險。",
            "source": "imported",
        },
    )
    return response.json()


class TestPendingQuestionsFlow:
    """Integration tests for the complete pending questions workflow."""

    @pytest.mark.asyncio
    async def test_complete_pending_question_flow(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test complete flow: Q&A out-of-scope -> pending -> parent answers."""
        # Step 1: Start Q&A session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )
        session = session_response.json()

        # Step 2: Ask an out-of-scope question (triggers pending question creation)
        mock_response = QAResponse(
            answer="這個問題很有趣！我需要請爸爸媽媽幫忙回答喔！",
            is_in_scope=False,
            should_save_question=True,
        )

        with patch("src.api.qa.get_qa_service") as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            await client.post(
                f"/api/v1/qa/sessions/{session['id']}/messages",
                json={"content": "世界上最大的動物是什麼？"},
            )

        # Step 3: Parent views pending questions
        questions_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"]},
        )
        assert questions_response.status_code == 200
        questions = questions_response.json()
        assert len(questions) >= 1

        # Find our question
        our_question = next(
            (q for q in questions if "最大的動物" in q["question"]),
            None,
        )
        assert our_question is not None
        assert our_question["status"] == "pending"

        # Step 4: Parent answers the question
        answer_response = await client.post(
            f"/api/v1/questions/{our_question['id']}/answer",
            json={"answer": "世界上最大的動物是藍鯨，牠可以長到30米長呢！"},
        )
        assert answer_response.status_code == 200
        answered = answer_response.json()
        assert answered["status"] == "answered"
        assert "藍鯨" in answered["answer"]

    @pytest.mark.asyncio
    async def test_multiple_out_of_scope_questions(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test handling multiple out-of-scope questions."""
        # Start Q&A session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )
        session = session_response.json()

        out_of_scope_questions = [
            "為什麼星星會閃爍？",
            "恐龍為什麼會滅絕？",
            "彩虹是怎麼形成的？",
        ]

        mock_response = QAResponse(
            answer="這個問題很棒！我需要請爸爸媽媽幫忙回答！",
            is_in_scope=False,
            should_save_question=True,
        )

        with patch("src.api.qa.get_qa_service") as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            for question in out_of_scope_questions:
                await client.post(
                    f"/api/v1/qa/sessions/{session['id']}/messages",
                    json={"content": question},
                )

        # Check all questions are saved
        questions_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"]},
        )
        questions = questions_response.json()

        # Verify all out-of-scope questions were saved
        saved_questions = [q["question"] for q in questions]
        for expected_q in out_of_scope_questions:
            assert any(expected_q in sq for sq in saved_questions)

    @pytest.mark.asyncio
    async def test_question_associated_with_story(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test that pending questions are associated with the story."""
        # Create question directly
        question = await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="Test question about the story",
            )
        )

        # Get the question
        response = await client.get(
            f"/api/v1/questions/{question.id}",
        )

        assert response.status_code == 200
        data = response.json()
        assert data["story_id"] == sample_story["id"]


class TestAnsweredQuestionLookup:
    """Integration tests for looking up previously answered questions."""

    @pytest.mark.asyncio
    async def test_find_answered_question(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test finding previously answered questions."""
        # Create and answer a question
        question = await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="為什麼海水是鹹的？",
            )
        )

        await PendingQuestionRepository.answer_question(
            question.id,
            answer="因為海水裡有很多鹽分！",
        )

        # Try to find the answered question
        found = await PendingQuestionRepository.find_answered_question(
            UUID(sample_parent["id"]),
            "為什麼海水是鹹的？",
        )

        assert found is not None
        assert found.answer == "因為海水裡有很多鹽分！"

    @pytest.mark.asyncio
    async def test_not_find_unanswered_question(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test that unanswered questions are not found."""
        # Create a pending (unanswered) question
        await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="未回答的問題",
            )
        )

        # Try to find it - should not be found as it's not answered
        found = await PendingQuestionRepository.find_answered_question(
            UUID(sample_parent["id"]),
            "未回答的問題",
        )

        assert found is None


class TestQuestionDeletion:
    """Integration tests for question deletion."""

    @pytest.mark.asyncio
    async def test_delete_pending_question(
        self,
        client: AsyncClient,
        sample_parent: dict,
        sample_story: dict,
    ) -> None:
        """Test deleting a pending question."""
        # Create a question
        question = await PendingQuestionRepository.create(
            PendingQuestionCreate(
                parent_id=UUID(sample_parent["id"]),
                story_id=UUID(sample_story["id"]),
                qa_session_id=None,
                question="Question to delete",
            )
        )

        # Delete it
        deleted = await PendingQuestionRepository.delete(question.id)
        assert deleted is True

        # Verify it's gone
        found = await PendingQuestionRepository.get_by_id(question.id)
        assert found is None
