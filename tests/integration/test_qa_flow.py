"""Integration tests for Q&A flow.

Tests the complete workflow for Q&A sessions with stories.
"""

from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
from httpx import AsyncClient

from src.services.qa_handler import QAResponse


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Q&A Test Parent", "email": f"qa_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


@pytest.fixture
async def sample_story(client: AsyncClient, sample_parent: dict) -> dict:
    """Create a sample story for Q&A testing."""
    response = await client.post(
        "/api/v1/stories",
        json={
            "parent_id": sample_parent["id"],
            "title": "小兔子與朋友們",
            "content": "從前從前，有一隻可愛的小兔子住在森林裡。"
            "小兔子有很多朋友，包括聰明的貓頭鷹和友善的小鹿。"
            "有一天，牠們一起去冒險，發現了一個神奇的花園。"
            "在花園裡，牠們遇到了許多蝴蝶和蜜蜂。"
            "最後，大家都玩得很開心，一起回家吃晚餐。",
            "source": "imported",
        },
    )
    return response.json()


@pytest.fixture
async def sample_session(client: AsyncClient, sample_story: dict) -> dict:
    """Create a sample Q&A session."""
    response = await client.post(
        "/api/v1/qa/sessions",
        json={"story_id": sample_story["id"]},
    )
    return response.json()


class TestQASessionFlow:
    """Integration tests for Q&A session lifecycle."""

    @pytest.mark.asyncio
    async def test_complete_qa_flow(
        self,
        client: AsyncClient,
        sample_story: dict,
    ) -> None:
        """Test complete Q&A flow from session creation to completion."""
        # Step 1: Start a session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )
        assert session_response.status_code == 201
        session = session_response.json()
        assert session["status"] == "active"
        assert session["message_count"] == 0

        # Step 2: Send a question (with mocked AI)
        mock_response = QAResponse(
            answer="小兔子住在美麗的森林裡喔！",
            is_in_scope=True,
            should_save_question=False,
        )

        with patch(
            "src.api.qa.get_qa_service",
        ) as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            message_response = await client.post(
                f"/api/v1/qa/sessions/{session['id']}/messages",
                json={"content": "小兔子住在哪裡？"},
            )

            assert message_response.status_code == 200
            message_data = message_response.json()

            assert message_data["user_message"]["role"] == "child"
            assert message_data["user_message"]["content"] == "小兔子住在哪裡？"
            assert message_data["assistant_message"]["role"] == "assistant"
            assert message_data["is_in_scope"] is True

        # Step 3: End the session
        end_response = await client.patch(
            f"/api/v1/qa/sessions/{session['id']}",
            json={"status": "completed"},
        )
        assert end_response.status_code == 200
        ended_session = end_response.json()
        assert ended_session["status"] == "completed"
        assert ended_session["ended_at"] is not None

    @pytest.mark.asyncio
    async def test_qa_session_with_multiple_questions(
        self,
        client: AsyncClient,
        sample_session: dict,
    ) -> None:
        """Test Q&A session with multiple question exchanges."""
        questions = [
            ("小兔子有什麼朋友？", "小兔子的朋友有貓頭鷹和小鹿喔！"),
            ("牠們去哪裡冒險？", "牠們去了一個神奇的花園！"),
            ("花園裡有什麼？", "花園裡有蝴蝶和蜜蜂！"),
        ]

        for question, answer in questions:
            mock_response = QAResponse(
                answer=answer,
                is_in_scope=True,
                should_save_question=False,
            )

            with patch("src.api.qa.get_qa_service") as mock_service:
                mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

                response = await client.post(
                    f"/api/v1/qa/sessions/{sample_session['id']}/messages",
                    json={"content": question},
                )
                assert response.status_code == 200

        # Verify session has all messages
        session_response = await client.get(f"/api/v1/qa/sessions/{sample_session['id']}")
        session_data = session_response.json()

        # 3 questions * 2 messages (user + assistant) = 6 messages
        assert session_data["message_count"] == 6
        assert len(session_data["messages"]) == 6

    @pytest.mark.asyncio
    async def test_message_limit_enforcement(
        self,
        client: AsyncClient,
        sample_session: dict,
    ) -> None:
        """Test that message limit is enforced."""
        mock_response = QAResponse(
            answer="回答",
            is_in_scope=True,
            should_save_question=False,
        )

        # Send 5 exchanges (10 messages)
        with patch("src.api.qa.get_qa_service") as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            for i in range(5):
                response = await client.post(
                    f"/api/v1/qa/sessions/{sample_session['id']}/messages",
                    json={"content": f"問題 {i + 1}"},
                )
                assert response.status_code == 200

            # The 6th exchange should fail
            response = await client.post(
                f"/api/v1/qa/sessions/{sample_session['id']}/messages",
                json={"content": "再一個問題"},
            )
            assert response.status_code == 400
            assert "limit" in response.json()["detail"].lower()


class TestOutOfScopeQuestions:
    """Integration tests for out-of-scope question handling."""

    @pytest.mark.asyncio
    async def test_out_of_scope_question_saved(
        self,
        client: AsyncClient,
        sample_story: dict,
        sample_parent: dict,
    ) -> None:
        """Test that out-of-scope questions are saved for parent."""
        # Start session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )
        session = session_response.json()

        # Send out-of-scope question
        mock_response = QAResponse(
            answer="這個問題我需要問問爸爸媽媽才能回答你喔！",
            is_in_scope=False,
            should_save_question=True,
        )

        with patch("src.api.qa.get_qa_service") as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            response = await client.post(
                f"/api/v1/qa/sessions/{session['id']}/messages",
                json={"content": "為什麼天空是藍色的？"},
            )

            assert response.status_code == 200
            assert response.json()["is_in_scope"] is False

        # Check pending questions for parent
        questions_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"]},
        )

        assert questions_response.status_code == 200
        questions = questions_response.json()

        # Should have at least one pending question
        assert len(questions) >= 1
        # Find our question
        our_question = next(
            (q for q in questions if "天空" in q["question"]),
            None,
        )
        assert our_question is not None
        assert our_question["status"] == "pending"

    @pytest.mark.asyncio
    async def test_in_scope_question_not_saved(
        self,
        client: AsyncClient,
        sample_story: dict,
        sample_parent: dict,
    ) -> None:
        """Test that in-scope questions are not saved as pending."""
        # Start session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": sample_story["id"]},
        )
        session = session_response.json()

        # Send in-scope question
        mock_response = QAResponse(
            answer="小兔子住在森林裡！",
            is_in_scope=True,
            should_save_question=False,
        )

        with patch("src.api.qa.get_qa_service") as mock_service:
            mock_service.return_value.answer_question = AsyncMock(return_value=mock_response)

            response = await client.post(
                f"/api/v1/qa/sessions/{session['id']}/messages",
                json={"content": "小兔子住在哪裡？"},
            )

            assert response.status_code == 200
            assert response.json()["is_in_scope"] is True

        # Check pending questions - should not have this question
        questions_response = await client.get(
            "/api/v1/questions",
            params={"parent_id": sample_parent["id"]},
        )

        questions = questions_response.json()
        story_questions = [q for q in questions if q.get("story_id") == sample_story["id"]]

        # Should not have the in-scope question saved
        rabbit_question = next(
            (q for q in story_questions if "住在哪裡" in q["question"]),
            None,
        )
        assert rabbit_question is None


class TestQASessionErrors:
    """Integration tests for Q&A error handling."""

    @pytest.mark.asyncio
    async def test_send_message_to_completed_session(
        self,
        client: AsyncClient,
        sample_session: dict,
    ) -> None:
        """Test that sending message to completed session fails."""
        # End the session
        await client.patch(
            f"/api/v1/qa/sessions/{sample_session['id']}",
            json={"status": "completed"},
        )

        # Try to send message
        response = await client.post(
            f"/api/v1/qa/sessions/{sample_session['id']}/messages",
            json={"content": "Test question"},
        )

        assert response.status_code == 400
        assert "not active" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_create_session_for_nonexistent_story(
        self,
        client: AsyncClient,
    ) -> None:
        """Test creating session for non-existent story."""
        response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": str(uuid4())},
        )

        assert response.status_code == 404
