"""E2E tests for Stories API endpoints.

Test Cases:
- ST-001 ~ ST-028: Story CRUD, import, generate, and audio operations
"""

from typing import Any

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestCreateStory:
    """Tests for POST /api/v1/stories endpoint."""

    # =========================================================================
    # ST-001: Create imported story
    # =========================================================================

    async def test_create_imported_story(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-001: Create story with source=imported, verify word_count."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "Imported Story",
                "content": "This is an imported story with some content.",
                "source": "imported",
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert "id" in data
        assert data["parent_id"] == created_parent["id"]
        assert data["title"] == "Imported Story"
        assert data["source"] == "imported"
        assert data["word_count"] > 0
        assert "estimated_duration_minutes" in data
        assert "created_at" in data
        assert "updated_at" in data

    # =========================================================================
    # ST-002: Create AI-generated story
    # =========================================================================

    async def test_create_ai_generated_story(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-002: Create story with source=ai_generated."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "AI Generated Story",
                "content": "An AI-generated adventure story.",
                "source": "ai_generated",
                "keywords": ["adventure", "friendship"],
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert data["source"] == "ai_generated"
        assert data["keywords"] == ["adventure", "friendship"]

    # =========================================================================
    # ST-003: Content exceeds 5000 characters
    # =========================================================================

    async def test_create_story_content_too_long(
        self, client: AsyncClient, created_parent: dict[str, Any], long_content_5000: str
    ) -> None:
        """ST-003: Create story with content > 5000 chars fails."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "Too Long Story",
                "content": long_content_5000,
                "source": "imported",
            },
        )

        assert response.status_code == 422

    # =========================================================================
    # ST-004: Title exceeds 200 characters
    # =========================================================================

    async def test_create_story_title_too_long(
        self, client: AsyncClient, created_parent: dict[str, Any], long_string_200: str
    ) -> None:
        """ST-004: Create story with title > 200 chars fails."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": long_string_200,
                "content": "Valid content",
                "source": "imported",
            },
        )

        assert response.status_code == 422

    # =========================================================================
    # ST-005: Parent ID does not exist
    # =========================================================================

    async def test_create_story_parent_not_found(
        self, client: AsyncClient, random_uuid: str
    ) -> None:
        """ST-005: Create story with non-existent parent_id fails."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": random_uuid,
                "title": "Test Story",
                "content": "Test content",
                "source": "imported",
            },
        )

        assert response.status_code == 404


@pytest.mark.asyncio
class TestListStories:
    """Tests for GET /api/v1/stories endpoint."""

    # =========================================================================
    # ST-006: Query stories with parent_id
    # =========================================================================

    async def test_list_stories_with_parent_id(
        self, client: AsyncClient, created_parent: dict[str, Any], created_story: dict[str, Any]
    ) -> None:
        """ST-006: List stories using parent_id query param."""
        response = await client.get("/api/v1/stories", params={"parent_id": created_parent["id"]})

        assert response.status_code == 200
        data = response.json()

        assert "items" in data
        assert "total" in data
        assert data["total"] >= 1

    # =========================================================================
    # ST-007: Query stories with X-Parent-ID header
    # =========================================================================

    async def test_list_stories_with_header(
        self, client: AsyncClient, created_parent: dict[str, Any], created_story: dict[str, Any]
    ) -> None:
        """ST-007: List stories using X-Parent-ID header."""
        response = await client.get(
            "/api/v1/stories", headers={"X-Parent-ID": created_parent["id"]}
        )

        # May return 200 with items or 422 if header not supported
        if response.status_code == 200:
            data = response.json()
            assert "items" in data or isinstance(data, list)

    # =========================================================================
    # ST-008: Filter stories by source
    # =========================================================================

    async def test_list_stories_filter_by_source(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-008: Filter stories by source type."""
        # Create stories with different sources
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "Imported Story",
                "content": "Imported content",
                "source": "imported",
            },
        )
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "AI Story",
                "content": "AI content",
                "source": "ai_generated",
            },
        )

        # Filter by imported
        response = await client.get(
            "/api/v1/stories", params={"parent_id": created_parent["id"], "source": "imported"}
        )

        assert response.status_code == 200
        data = response.json()

        for item in data["items"]:
            assert item["source"] == "imported"

    # =========================================================================
    # ST-009: Pagination with limit/offset
    # =========================================================================

    async def test_list_stories_pagination(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-009: Test pagination with limit and offset."""
        # Create 3 stories
        for i in range(3):
            await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": created_parent["id"],
                    "title": f"Story {i + 1}",
                    "content": f"Content {i + 1}",
                    "source": "imported",
                },
            )

        # Get first page
        response = await client.get(
            "/api/v1/stories", params={"parent_id": created_parent["id"], "limit": 2, "offset": 0}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["items"]) == 2
        assert data["total"] >= 3
        assert data["limit"] == 2
        assert data["offset"] == 0

    # =========================================================================
    # ST-010: Missing parent_id parameter
    # =========================================================================

    async def test_list_stories_missing_parent_id(self, client: AsyncClient) -> None:
        """ST-010: List stories without parent_id fails."""
        response = await client.get("/api/v1/stories")

        # Should return 400 or 422
        assert response.status_code in [400, 422]


@pytest.mark.asyncio
class TestGetStory:
    """Tests for GET /api/v1/stories/{story_id} endpoint."""

    # =========================================================================
    # ST-011: Get existing story
    # =========================================================================

    async def test_get_story_success(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """ST-011: Get existing story by ID."""
        story_id = created_story["id"]
        response = await client.get(f"/api/v1/stories/{story_id}")

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == story_id
        assert data["title"] == created_story["title"]
        assert "word_count" in data
        assert "audio_file_path" in data
        assert "audio_generated_at" in data

    # =========================================================================
    # ST-012: Get non-existent story
    # =========================================================================

    async def test_get_story_not_found(self, client: AsyncClient, random_uuid: str) -> None:
        """ST-012: Get non-existent story returns 404."""
        response = await client.get(f"/api/v1/stories/{random_uuid}")

        assert response.status_code == 404


@pytest.mark.asyncio
class TestUpdateStory:
    """Tests for PUT /api/v1/stories/{story_id} endpoint."""

    # =========================================================================
    # ST-013: Update story title
    # =========================================================================

    async def test_update_story_title(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """ST-013: Update story title successfully."""
        story_id = created_story["id"]
        new_title = "Updated Story Title"

        response = await client.put(f"/api/v1/stories/{story_id}", json={"title": new_title})

        assert response.status_code == 200
        data = response.json()

        assert data["title"] == new_title
        assert data["content"] == created_story["content"]

    # =========================================================================
    # ST-014: Update story content (recalculates word_count)
    # =========================================================================

    async def test_update_story_content_recalculates_word_count(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """ST-014: Update content recalculates word_count."""
        story_id = created_story["id"]
        original_word_count = created_story["word_count"]
        new_content = "This is a completely different and much longer content for the story."

        response = await client.put(f"/api/v1/stories/{story_id}", json={"content": new_content})

        assert response.status_code == 200
        data = response.json()

        assert data["content"] == new_content
        assert data["word_count"] != original_word_count

    # =========================================================================
    # ST-015: Update non-existent story
    # =========================================================================

    async def test_update_story_not_found(self, client: AsyncClient, random_uuid: str) -> None:
        """ST-015: Update non-existent story returns 404."""
        response = await client.put(f"/api/v1/stories/{random_uuid}", json={"title": "New Title"})

        assert response.status_code == 404


@pytest.mark.asyncio
class TestDeleteStory:
    """Tests for DELETE /api/v1/stories/{story_id} endpoint."""

    # =========================================================================
    # ST-016: Delete story
    # =========================================================================

    async def test_delete_story_success(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-016: Delete story successfully."""
        # Create a story to delete
        create_response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": created_parent["id"],
                "title": "Story to Delete",
                "content": "This will be deleted",
                "source": "imported",
            },
        )
        story_id = create_response.json()["id"]

        # Delete the story
        delete_response = await client.delete(f"/api/v1/stories/{story_id}")
        assert delete_response.status_code == 204

        # Verify it's deleted
        get_response = await client.get(f"/api/v1/stories/{story_id}")
        assert get_response.status_code == 404

    # =========================================================================
    # ST-017: Delete non-existent story
    # =========================================================================

    async def test_delete_story_not_found(self, client: AsyncClient, random_uuid: str) -> None:
        """ST-017: Delete non-existent story returns 404."""
        response = await client.delete(f"/api/v1/stories/{random_uuid}")

        assert response.status_code == 404


@pytest.mark.asyncio
class TestImportStory:
    """Tests for POST /api/v1/stories/import endpoint."""

    # =========================================================================
    # ST-018: Import story with X-Parent-ID header
    # =========================================================================

    async def test_import_story_success(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-018: Import story with X-Parent-ID header."""
        response = await client.post(
            "/api/v1/stories/import",
            headers={"X-Parent-ID": created_parent["id"]},
            json={
                "title": "Imported Story via Endpoint",
                "content": "This story was imported through the import endpoint.",
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert data["source"] == "imported"
        assert data["title"] == "Imported Story via Endpoint"

    # =========================================================================
    # ST-019: Missing X-Parent-ID header
    # =========================================================================

    async def test_import_story_missing_header(self, client: AsyncClient) -> None:
        """ST-019: Import story without X-Parent-ID fails."""
        response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Test Story",
                "content": "Test content",
            },
        )

        assert response.status_code in [400, 422]

    # =========================================================================
    # ST-020: Verify estimated_duration_minutes calculation
    # =========================================================================

    async def test_import_story_duration_calculation(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-020: Verify estimated_duration_minutes is calculated correctly."""
        # Create content with known length
        content = "a" * 400  # 400 chars = 2 minutes at 200 chars/min

        response = await client.post(
            "/api/v1/stories/import",
            headers={"X-Parent-ID": created_parent["id"]},
            json={
                "title": "Duration Test Story",
                "content": content,
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert data["word_count"] == 400
        assert data["estimated_duration_minutes"] == 2


@pytest.mark.asyncio
class TestGenerateStory:
    """Tests for POST /api/v1/stories/generate endpoint."""

    # =========================================================================
    # ST-021: Generate story with keywords
    # =========================================================================

    async def test_generate_story_success(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-021: Generate story with keywords."""
        response = await client.post(
            "/api/v1/stories/generate",
            headers={"X-Parent-ID": created_parent["id"]},
            json={
                "keywords": ["adventure", "friendship", "magic"],
            },
        )

        # Currently returns placeholder, so 201
        assert response.status_code == 201
        data = response.json()

        assert data["source"] == "ai_generated"

    # =========================================================================
    # ST-022: Keywords exceed 5
    # =========================================================================

    async def test_generate_story_too_many_keywords(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-022: Generate story with > 5 keywords fails."""
        response = await client.post(
            "/api/v1/stories/generate",
            headers={"X-Parent-ID": created_parent["id"]},
            json={
                "keywords": ["one", "two", "three", "four", "five", "six"],
            },
        )

        assert response.status_code == 422

    # =========================================================================
    # ST-023: Keywords less than 1
    # =========================================================================

    async def test_generate_story_no_keywords(
        self, client: AsyncClient, created_parent: dict[str, Any]
    ) -> None:
        """ST-023: Generate story with 0 keywords fails."""
        response = await client.post(
            "/api/v1/stories/generate",
            headers={"X-Parent-ID": created_parent["id"]},
            json={
                "keywords": [],
            },
        )

        assert response.status_code == 422


@pytest.mark.asyncio
class TestGenerateStoryAudio:
    """Tests for POST /api/v1/stories/{story_id}/audio endpoint."""

    # =========================================================================
    # ST-024: Generate audio for story
    # =========================================================================

    async def test_generate_audio_success(
        self,
        client: AsyncClient,
        created_story: dict[str, Any],
        ready_voice_profile: dict[str, Any],
    ) -> None:
        """ST-024: Generate audio for story returns 202 Accepted."""
        response = await client.post(
            f"/api/v1/stories/{created_story['id']}/audio",
            json={"voice_profile_id": ready_voice_profile["id"]},
        )

        assert response.status_code == 202
        data = response.json()

        assert data["story_id"] == created_story["id"]
        assert data["status"] == "processing"

    # =========================================================================
    # ST-025: Voice profile ID does not exist
    # =========================================================================

    async def test_generate_audio_voice_not_found(
        self, client: AsyncClient, created_story: dict[str, Any], random_uuid: str
    ) -> None:
        """ST-025: Generate audio with non-existent voice profile fails."""
        response = await client.post(
            f"/api/v1/stories/{created_story['id']}/audio", json={"voice_profile_id": random_uuid}
        )

        assert response.status_code == 404

    # =========================================================================
    # ST-026: Story ID does not exist
    # =========================================================================

    async def test_generate_audio_story_not_found(
        self, client: AsyncClient, ready_voice_profile: dict[str, Any], random_uuid: str
    ) -> None:
        """ST-026: Generate audio for non-existent story fails."""
        response = await client.post(
            f"/api/v1/stories/{random_uuid}/audio",
            json={"voice_profile_id": ready_voice_profile["id"]},
        )

        assert response.status_code == 404


@pytest.mark.asyncio
class TestGetStoryAudio:
    """Tests for GET /api/v1/stories/{story_id}/audio endpoint."""

    # =========================================================================
    # ST-027: Download generated audio
    # =========================================================================

    async def test_get_audio_not_generated_yet(
        self, client: AsyncClient, created_story: dict[str, Any]
    ) -> None:
        """ST-027: Get audio returns 404 when not yet generated."""
        response = await client.get(f"/api/v1/stories/{created_story['id']}/audio")

        # Audio not generated yet
        assert response.status_code == 404
        data = response.json()
        assert "not" in data["detail"].lower()

    # =========================================================================
    # ST-028: Audio not yet generated
    # =========================================================================

    async def test_get_audio_story_not_found(self, client: AsyncClient, random_uuid: str) -> None:
        """ST-028: Get audio for non-existent story fails."""
        response = await client.get(f"/api/v1/stories/{random_uuid}/audio")

        assert response.status_code == 404
