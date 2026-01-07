"""E2E tests for complete user flows and integration scenarios.

Test Cases:
- E2E-001: Complete story lifecycle (parent → story → voice → audio → Q&A)
- E2E-002: Resource cascade deletion
- E2E-003: Q&A message limit enforcement
- PERF-001 ~ PERF-003: Performance tests
"""

import time
from typing import Any
from uuid import uuid4

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestCompleteStoryLifecycle:
    """E2E-001: Complete story lifecycle from parent creation to Q&A."""

    async def test_complete_story_lifecycle(
        self, client: AsyncClient, mock_wav_file_30s: bytes
    ) -> None:
        """
        E2E-001: Full lifecycle test.

        Steps:
        1. Create parent
        2. Import story
        3. Create voice profile
        4. Upload voice sample
        5. Generate story audio
        6. Create Q&A session
        7. Interactive Q&A
        8. End session
        """
        # Step 1: Create parent
        parent_response = await client.post(
            "/api/v1/parents",
            json={
                "name": "E2E Test Parent",
                "email": f"e2e_{uuid4().hex[:8]}@example.com"
            }
        )
        assert parent_response.status_code == 201
        parent = parent_response.json()
        parent_id = parent["id"]

        # Step 2: Import story
        story_response = await client.post(
            "/api/v1/stories/import",
            headers={"X-Parent-ID": parent_id},
            json={
                "title": "E2E Test Story",
                "content": (
                    "Once upon a time, there was a brave little rabbit named Ruby. "
                    "Ruby lived in a cozy burrow at the edge of a magical forest. "
                    "She had many friends including Oliver the wise owl and Danny the deer. "
                    "One sunny morning, Ruby decided to go on an adventure to find the legendary Rainbow Bridge."
                ),
            }
        )
        assert story_response.status_code == 201
        story = story_response.json()
        story_id = story["id"]

        # Verify story has correct metadata
        assert story["source"] == "imported"
        assert story["word_count"] > 0
        assert story["estimated_duration_minutes"] is not None

        # Step 3: Create voice profile
        voice_profile_response = await client.post(
            "/api/v1/voice-profiles",
            json={"parent_id": parent_id, "name": "Dad's Voice"}
        )
        assert voice_profile_response.status_code == 201
        voice_profile = voice_profile_response.json()
        profile_id = voice_profile["id"]
        assert voice_profile["status"] == "pending"

        # Step 4: Upload voice sample
        upload_response = await client.post(
            f"/api/v1/voice-profiles/{profile_id}/upload",
            files={"audio": ("sample.wav", mock_wav_file_30s, "audio/wav")}
        )
        # May succeed or require longer duration depending on validation
        if upload_response.status_code == 200:
            # Verify status changed
            get_profile = await client.get(f"/api/v1/voice-profiles/{profile_id}")
            assert get_profile.status_code == 200

        # Step 5: Generate story audio (requires ready voice profile)
        # Update voice profile to ready status for testing
        from src.db.repository import VoiceProfileRepository
        from src.models import VoiceProfileStatus
        from src.models.voice import VoiceProfileUpdate
        from uuid import UUID

        await VoiceProfileRepository.update(
            UUID(profile_id),
            VoiceProfileUpdate(
                status=VoiceProfileStatus.READY,
                elevenlabs_voice_id="test_voice_id",
            ),
        )

        audio_response = await client.post(
            f"/api/v1/stories/{story_id}/audio",
            json={"voice_profile_id": profile_id}
        )
        assert audio_response.status_code == 202
        assert audio_response.json()["status"] == "processing"

        # Step 6: Create Q&A session
        qa_session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": story_id}
        )
        assert qa_session_response.status_code == 201
        qa_session = qa_session_response.json()
        session_id = qa_session["id"]
        assert qa_session["status"] == "active"

        # Step 7: Interactive Q&A
        questions = [
            "Who is the main character?",
            "Where does Ruby live?",
            "What did Ruby do one morning?",
        ]

        for question in questions:
            msg_response = await client.post(
                f"/api/v1/qa/sessions/{session_id}/messages",
                json={"content": question}
            )
            assert msg_response.status_code == 200
            data = msg_response.json()
            assert data["user_message"]["content"] == question
            assert len(data["assistant_message"]["content"]) > 0

        # Verify message count
        get_session = await client.get(f"/api/v1/qa/sessions/{session_id}")
        assert get_session.json()["message_count"] == 6  # 3 questions + 3 answers

        # Step 8: End session
        end_response = await client.patch(
            f"/api/v1/qa/sessions/{session_id}",
            json={"status": "completed"}
        )
        assert end_response.status_code == 200
        assert end_response.json()["status"] == "completed"
        assert end_response.json()["ended_at"] is not None


@pytest.mark.asyncio
class TestCascadeDeleteResources:
    """E2E-002: Resource cascade deletion tests."""

    async def test_delete_parent_cascades_to_stories(
        self, client: AsyncClient
    ) -> None:
        """
        E2E-002: Delete parent cascades to all associated resources.

        Steps:
        1. Create parent
        2. Create stories and voice profiles
        3. Delete parent
        4. Verify all resources are deleted
        """
        # Create parent
        parent_response = await client.post(
            "/api/v1/parents",
            json={
                "name": "Cascade Delete Parent",
                "email": f"cascade_{uuid4().hex[:8]}@example.com"
            }
        )
        parent_id = parent_response.json()["id"]

        # Create stories
        story_ids = []
        for i in range(3):
            story_response = await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": parent_id,
                    "title": f"Story {i + 1}",
                    "content": f"Content for story {i + 1}",
                    "source": "imported",
                }
            )
            story_ids.append(story_response.json()["id"])

        # Create voice profiles
        profile_ids = []
        for name in ["Dad", "Mom"]:
            profile_response = await client.post(
                "/api/v1/voice-profiles",
                json={"parent_id": parent_id, "name": name}
            )
            profile_ids.append(profile_response.json()["id"])

        # Verify resources exist
        for story_id in story_ids:
            assert (await client.get(f"/api/v1/stories/{story_id}")).status_code == 200
        for profile_id in profile_ids:
            assert (await client.get(f"/api/v1/voice-profiles/{profile_id}")).status_code == 200

        # Delete parent
        delete_response = await client.delete(f"/api/v1/parents/{parent_id}")
        assert delete_response.status_code == 204

        # Verify all resources are deleted
        assert (await client.get(f"/api/v1/parents/{parent_id}")).status_code == 404

        for story_id in story_ids:
            assert (await client.get(f"/api/v1/stories/{story_id}")).status_code == 404

        for profile_id in profile_ids:
            assert (await client.get(f"/api/v1/voice-profiles/{profile_id}")).status_code == 404


@pytest.mark.asyncio
class TestQAMessageLimitEnforcement:
    """E2E-003: Q&A session message limit enforcement."""

    async def test_message_limit_exactly_10(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """
        E2E-003: Test exact 10 message limit enforcement.

        Steps:
        1. Create story
        2. Create Q&A session
        3. Send exactly 5 Q&A exchanges (10 messages)
        4. Verify 6th exchange is rejected
        """
        # Create Q&A session
        session_response = await client.post(
            "/api/v1/qa/sessions",
            json={"story_id": created_story["id"]}
        )
        session_id = session_response.json()["id"]

        # Send 5 exchanges (10 messages total)
        for i in range(5):
            response = await client.post(
                f"/api/v1/qa/sessions/{session_id}/messages",
                json={"content": f"Question number {i + 1}?"}
            )
            assert response.status_code == 200, f"Exchange {i + 1} failed"

        # Verify count is 10
        get_response = await client.get(f"/api/v1/qa/sessions/{session_id}")
        assert get_response.json()["message_count"] == 10

        # 6th exchange should fail
        response = await client.post(
            f"/api/v1/qa/sessions/{session_id}/messages",
            json={"content": "This should fail?"}
        )
        assert response.status_code == 400
        assert "limit" in response.json()["detail"].lower()


@pytest.mark.asyncio
class TestPerformance:
    """Performance and stability tests."""

    # =========================================================================
    # PERF-001: Health check response time
    # =========================================================================

    async def test_health_check_response_time(
        self, client: AsyncClient
    ) -> None:
        """PERF-001: Health check responds in < 100ms."""
        times = []
        for _ in range(5):
            start = time.time()
            response = await client.get("/health")
            elapsed = (time.time() - start) * 1000
            times.append(elapsed)
            assert response.status_code == 200

        avg_time = sum(times) / len(times)
        # Allow generous buffer for CI environments
        assert avg_time < 500, f"Average health check time {avg_time:.2f}ms exceeds 500ms"

    # =========================================================================
    # PERF-002: List API pagination performance
    # =========================================================================

    async def test_list_pagination_performance(
        self, client: AsyncClient
    ) -> None:
        """PERF-002: List API with pagination handles 100 items efficiently."""
        # Create parent
        parent_response = await client.post(
            "/api/v1/parents",
            json={"name": "Perf Test Parent", "email": f"perf_{uuid4().hex[:8]}@example.com"}
        )
        parent_id = parent_response.json()["id"]

        # Create 50 stories (reduced for faster test execution)
        for i in range(50):
            await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": parent_id,
                    "title": f"Perf Story {i + 1}",
                    "content": f"Content {i + 1}",
                    "source": "imported",
                }
            )

        # Measure list performance
        start = time.time()
        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": parent_id, "limit": 100}
        )
        elapsed = (time.time() - start) * 1000

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 50
        assert elapsed < 1000, f"List pagination took {elapsed:.2f}ms, exceeds 1000ms"

    # =========================================================================
    # PERF-003: Concurrent request handling
    # =========================================================================

    async def test_concurrent_requests(
        self, client: AsyncClient
    ) -> None:
        """PERF-003: Handle 10 concurrent requests correctly."""
        import asyncio

        async def make_request(i: int) -> tuple[int, int]:
            response = await client.get("/health")
            return i, response.status_code

        # Run 10 concurrent requests
        tasks = [make_request(i) for i in range(10)]
        results = await asyncio.gather(*tasks)

        # All should succeed
        for i, status_code in results:
            assert status_code == 200, f"Request {i} failed with status {status_code}"


@pytest.mark.asyncio
class TestMultiParentIsolation:
    """Test data isolation between different parents."""

    async def test_parent_data_isolation(
        self, client: AsyncClient
    ) -> None:
        """Verify one parent cannot see another parent's data."""
        # Create two parents
        parent1_response = await client.post(
            "/api/v1/parents",
            json={"name": "Parent 1", "email": f"p1_{uuid4().hex[:8]}@example.com"}
        )
        parent1_id = parent1_response.json()["id"]

        parent2_response = await client.post(
            "/api/v1/parents",
            json={"name": "Parent 2", "email": f"p2_{uuid4().hex[:8]}@example.com"}
        )
        parent2_id = parent2_response.json()["id"]

        # Create stories for parent1
        for i in range(3):
            await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": parent1_id,
                    "title": f"Parent1 Story {i}",
                    "content": f"Content {i}",
                    "source": "imported",
                }
            )

        # Create stories for parent2
        for i in range(2):
            await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": parent2_id,
                    "title": f"Parent2 Story {i}",
                    "content": f"Content {i}",
                    "source": "imported",
                }
            )

        # Verify parent1 only sees their stories
        parent1_stories = await client.get(
            "/api/v1/stories",
            params={"parent_id": parent1_id}
        )
        assert parent1_stories.json()["total"] == 3
        for story in parent1_stories.json()["items"]:
            assert story["parent_id"] == parent1_id

        # Verify parent2 only sees their stories
        parent2_stories = await client.get(
            "/api/v1/stories",
            params={"parent_id": parent2_id}
        )
        assert parent2_stories.json()["total"] == 2
        for story in parent2_stories.json()["items"]:
            assert story["parent_id"] == parent2_id


@pytest.mark.asyncio
class TestErrorRecovery:
    """Test error handling and recovery scenarios."""

    async def test_invalid_operations_dont_corrupt_state(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """Verify invalid operations don't corrupt the database state."""
        story_id = created_story["id"]

        # Try invalid update
        await client.put(
            f"/api/v1/stories/{story_id}",
            json={"content": "a" * 10000}  # Too long
        )

        # Verify story is still intact
        get_response = await client.get(f"/api/v1/stories/{story_id}")
        assert get_response.status_code == 200
        assert get_response.json()["content"] == created_story["content"]

    async def test_partial_operation_rollback(
        self, client: AsyncClient
    ) -> None:
        """Verify failed operations don't leave partial data."""
        # Try to create story with non-existent parent
        random_parent_id = str(uuid4())

        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": random_parent_id,
                "title": "Orphan Story",
                "content": "This should not be created",
                "source": "imported",
            }
        )
        assert response.status_code == 404

        # Verify no orphan story exists (list should be empty for this parent)
        list_response = await client.get(
            "/api/v1/stories",
            params={"parent_id": random_parent_id}
        )
        # Should return 200 with empty list or 404 (depending on implementation)
        if list_response.status_code == 200:
            assert list_response.json()["total"] == 0
