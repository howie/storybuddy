"""Integration tests for story import flow.

Tests the complete workflow for importing external stories.
"""

from uuid import uuid4

import pytest
from httpx import AsyncClient


@pytest.fixture
async def sample_parent(client: AsyncClient) -> dict:
    """Create a sample parent for testing."""
    response = await client.post(
        "/api/v1/parents",
        json={"name": "Import Test Parent", "email": f"import_{uuid4().hex[:8]}@example.com"},
    )
    return response.json()


class TestStoryImportFlow:
    """Integration tests for story import functionality."""

    @pytest.mark.asyncio
    async def test_complete_import_flow(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test the complete story import flow."""
        # Step 1: Import a story using the /import endpoint
        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "小兔子歷險記",
                "content": "從前從前，有一隻可愛的小兔子住在森林裡。牠每天都會去探險，尋找新的朋友。",
            },
            headers={"X-Parent-ID": sample_parent["id"]},
        )

        assert import_response.status_code == 201
        story = import_response.json()

        assert story["title"] == "小兔子歷險記"
        assert story["source"] == "imported"
        assert story["parent_id"] == sample_parent["id"]
        assert story["word_count"] > 0
        assert story["estimated_duration_minutes"] >= 1

        # Step 2: Verify story appears in list
        list_response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"]},
        )

        assert list_response.status_code == 200
        stories = list_response.json()
        assert stories["total"] == 1
        assert stories["items"][0]["id"] == story["id"]

    @pytest.mark.asyncio
    async def test_import_multiple_stories(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test importing multiple stories."""
        stories_to_import = [
            {"title": "故事一", "content": "這是第一個故事的內容。"},
            {"title": "故事二", "content": "這是第二個故事的內容。"},
            {"title": "故事三", "content": "這是第三個故事的內容。"},
        ]

        for story_data in stories_to_import:
            response = await client.post(
                "/api/v1/stories/import",
                json=story_data,
                headers={"X-Parent-ID": sample_parent["id"]},
            )
            assert response.status_code == 201

        # Verify all stories appear in list
        list_response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"]},
        )

        assert list_response.status_code == 200
        stories = list_response.json()
        assert stories["total"] == 3

    @pytest.mark.asyncio
    async def test_import_requires_parent_id_header(
        self,
        client: AsyncClient,
    ) -> None:
        """Test that import requires X-Parent-ID header."""
        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Test Story",
                "content": "Test content",
            },
        )

        assert import_response.status_code == 400
        assert "X-Parent-ID" in import_response.json()["detail"]

    @pytest.mark.asyncio
    async def test_import_with_invalid_parent_id(
        self,
        client: AsyncClient,
    ) -> None:
        """Test import with non-existent parent ID."""
        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Test Story",
                "content": "Test content",
            },
            headers={"X-Parent-ID": str(uuid4())},
        )

        assert import_response.status_code == 404

    @pytest.mark.asyncio
    async def test_import_with_content_too_long(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test import with content exceeding max length."""
        long_content = "測試內容" * 2000  # 8000 characters, exceeds 5000 limit

        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Too Long Story",
                "content": long_content,
            },
            headers={"X-Parent-ID": sample_parent["id"]},
        )

        assert import_response.status_code == 422


class TestStoryManagementFlow:
    """Integration tests for story management after import."""

    @pytest.mark.asyncio
    async def test_update_imported_story(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test updating an imported story."""
        # Import a story
        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Original Title",
                "content": "Original content.",
            },
            headers={"X-Parent-ID": sample_parent["id"]},
        )
        story = import_response.json()

        # Update the story
        update_response = await client.put(
            f"/api/v1/stories/{story['id']}",
            json={
                "title": "Updated Title",
                "content": "Updated content with more details.",
            },
        )

        assert update_response.status_code == 200
        updated = update_response.json()
        assert updated["title"] == "Updated Title"
        assert updated["content"] == "Updated content with more details."

    @pytest.mark.asyncio
    async def test_delete_imported_story(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test deleting an imported story."""
        # Import a story
        import_response = await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Story to Delete",
                "content": "This story will be deleted.",
            },
            headers={"X-Parent-ID": sample_parent["id"]},
        )
        story = import_response.json()

        # Delete the story
        delete_response = await client.delete(f"/api/v1/stories/{story['id']}")
        assert delete_response.status_code == 204

        # Verify deletion
        get_response = await client.get(f"/api/v1/stories/{story['id']}")
        assert get_response.status_code == 404

    @pytest.mark.asyncio
    async def test_filter_stories_by_source(
        self,
        client: AsyncClient,
        sample_parent: dict,
    ) -> None:
        """Test filtering stories by source type."""
        # Import a story
        await client.post(
            "/api/v1/stories/import",
            json={
                "title": "Imported Story",
                "content": "This is an imported story.",
            },
            headers={"X-Parent-ID": sample_parent["id"]},
        )

        # Create an AI-generated story
        await client.post(
            "/api/v1/stories",
            json={
                "parent_id": sample_parent["id"],
                "title": "AI Generated Story",
                "content": "This is an AI-generated story.",
                "source": "ai_generated",
            },
        )

        # Filter by imported
        imported_response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"], "source": "imported"},
        )
        assert imported_response.status_code == 200
        imported_stories = imported_response.json()
        assert imported_stories["total"] == 1
        assert imported_stories["items"][0]["source"] == "imported"

        # Filter by ai_generated
        ai_response = await client.get(
            "/api/v1/stories",
            params={"parent_id": sample_parent["id"], "source": "ai_generated"},
        )
        assert ai_response.status_code == 200
        ai_stories = ai_response.json()
        assert ai_stories["total"] == 1
        assert ai_stories["items"][0]["source"] == "ai_generated"
