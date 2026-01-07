"""Contract tests for Story API endpoints.

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


class TestCreateStory:
    """Tests for POST /api/v1/stories endpoint."""

    @pytest.mark.asyncio
    async def test_create_story_success(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test creating an imported story successfully."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "小兔子歷險記",
                "content": "從前從前，有一隻可愛的小兔子住在森林裡...",
                "source": "imported",
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert "id" in data
        assert data["parent_id"] == sample_parent["id"]
        assert data["title"] == "小兔子歷險記"
        assert data["content"] == "從前從前，有一隻可愛的小兔子住在森林裡..."
        assert data["source"] == "imported"
        assert data["word_count"] > 0
        assert "estimated_duration_minutes" in data
        assert "created_at" in data
        assert "updated_at" in data

    @pytest.mark.asyncio
    async def test_create_story_with_keywords(
        self, client: AsyncClient, sample_parent: dict
    ) -> None:
        """Test creating an AI-generated story with keywords."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "AI 生成的故事",
                "content": "一個由 AI 創作的精彩故事...",
                "source": "ai_generated",
                "keywords": ["冒險", "友誼", "勇氣"],
            },
        )

        assert response.status_code == 201
        data = response.json()

        assert data["source"] == "ai_generated"
        assert data["keywords"] == ["冒險", "友誼", "勇氣"]

    @pytest.mark.asyncio
    async def test_create_story_invalid_parent_id(self, client: AsyncClient) -> None:
        """Test creating story with non-existent parent ID."""
        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": str(uuid4()),
                "title": "Test Story",
                "content": "Test content",
                "source": "imported",
            },
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_create_story_content_too_long(
        self, client: AsyncClient, sample_parent: dict
    ) -> None:
        """Test creating story with content exceeding max word count."""
        # Create content that exceeds 5000 characters
        long_content = "測試" * 3000  # 6000 characters

        response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Too Long Story",
                "content": long_content,
                "source": "imported",
            },
        )

        assert response.status_code == 422  # Validation error


class TestListStories:
    """Tests for GET /api/v1/stories endpoint."""

    @pytest.mark.asyncio
    async def test_list_stories_empty(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test listing stories when none exist."""
        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"]},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["items"] == []
        assert data["total"] == 0
        assert "limit" in data
        assert "offset" in data

    @pytest.mark.asyncio
    async def test_list_stories_with_items(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test listing stories with existing items."""
        # Create a story first
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Test Story",
                "content": "Some test content for the story",
                "source": "imported",
            },
        )

        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"]},
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["items"]) == 1
        assert data["total"] == 1
        assert data["items"][0]["title"] == "Test Story"

    @pytest.mark.asyncio
    async def test_list_stories_filter_by_source(
        self, client: AsyncClient, sample_parent: dict
    ) -> None:
        """Test listing stories filtered by source."""
        # Create an imported story
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Imported Story",
                "content": "An imported story",
                "source": "imported",
            },
        )

        # Create an AI-generated story
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "AI Story",
                "content": "An AI-generated story",
                "source": "ai_generated",
            },
        )

        # Filter by imported
        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"], "source": "imported"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["total"] == 1
        assert data["items"][0]["source"] == "imported"

    @pytest.mark.asyncio
    async def test_list_stories_pagination(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test listing stories with pagination."""
        # Create 3 stories
        for i in range(3):
            await client.post(
                "/api/v1/stories",
                json={
                    "parent_id": sample_parent["id"],
                    "title": f"Story {i + 1}",
                    "content": f"Content for story {i + 1}",
                    "source": "imported",
                },
            )

        # Get first page with limit 2
        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"], "limit": 2, "offset": 0},
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["items"]) == 2
        assert data["total"] == 3
        assert data["limit"] == 2
        assert data["offset"] == 0

        # Get second page
        response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"], "limit": 2, "offset": 2},
        )

        data = response.json()
        assert len(data["items"]) == 1


class TestGetStory:
    """Tests for GET /api/v1/stories/{story_id} endpoint."""

    @pytest.mark.asyncio
    async def test_get_story_success(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test getting a story by ID."""
        # Create a story
        create_response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Test Story",
                "content": "Test content for the story",
                "source": "imported",
            },
        )
        story_id = create_response.json()["id"]

        # Get the story
        response = await client.get(f"/api/v1/stories/{story_id}")

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == story_id
        assert data["title"] == "Test Story"

    @pytest.mark.asyncio
    async def test_get_story_not_found(self, client: AsyncClient) -> None:
        """Test getting a non-existent story."""
        response = await client.get(f"/api/v1/stories/{uuid4()}")

        assert response.status_code == 404


class TestUpdateStory:
    """Tests for PUT /api/v1/stories/{story_id} endpoint."""

    @pytest.mark.asyncio
    async def test_update_story_title(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test updating a story's title."""
        # Create a story
        create_response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Original Title",
                "content": "Original content",
                "source": "imported",
            },
        )
        story_id = create_response.json()["id"]

        # Update the story
        response = await client.put(
            f"/api/v1/stories/{story_id}",
            json={"title": "Updated Title"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["title"] == "Updated Title"
        assert data["content"] == "Original content"

    @pytest.mark.asyncio
    async def test_update_story_content(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test updating a story's content recalculates word count."""
        # Create a story
        create_response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Test Story",
                "content": "Short",
                "source": "imported",
            },
        )
        story_id = create_response.json()["id"]
        original_word_count = create_response.json()["word_count"]

        # Update with longer content
        new_content = (
            "This is a much longer content that should change the word count significantly"
        )
        response = await client.put(
            f"/api/v1/stories/{story_id}",
            json={"content": new_content},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["content"] == new_content
        assert data["word_count"] != original_word_count

    @pytest.mark.asyncio
    async def test_update_story_not_found(self, client: AsyncClient) -> None:
        """Test updating a non-existent story."""
        response = await client.put(
            f"/api/v1/stories/{uuid4()}",
            json={"title": "New Title"},
        )

        assert response.status_code == 404


class TestDeleteStory:
    """Tests for DELETE /api/v1/stories/{story_id} endpoint."""

    @pytest.mark.asyncio
    async def test_delete_story_success(self, client: AsyncClient, sample_parent: dict) -> None:
        """Test deleting a story."""
        # Create a story
        create_response = await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "Story to Delete",
                "content": "This story will be deleted",
                "source": "imported",
            },
        )
        story_id = create_response.json()["id"]

        # Delete the story
        response = await client.delete(f"/api/v1/stories/{story_id}")

        assert response.status_code == 204

        # Verify it's deleted
        get_response = await client.get(f"/api/v1/stories/{story_id}")
        assert get_response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_story_not_found(self, client: AsyncClient) -> None:
        """Test deleting a non-existent story."""
        response = await client.delete(f"/api/v1/stories/{uuid4()}")

        assert response.status_code == 404
