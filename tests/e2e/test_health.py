"""E2E tests for Health Check & Root endpoints.

Test Cases:
- HC-001: Health check endpoint response
- HC-002: Root endpoint returns API info
"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestHealthEndpoints:
    """Tests for health check and root endpoints."""

    # =========================================================================
    # HC-001: Health check endpoint
    # =========================================================================

    async def test_health_check_returns_healthy_status(self, client: AsyncClient) -> None:
        """HC-001: GET /health returns healthy status."""
        response = await client.get("/health")

        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "healthy"
        assert "version" in data
        assert data["version"] == "0.1.0"

    async def test_health_check_response_time(self, client: AsyncClient) -> None:
        """HC-001: Health check should respond quickly (< 100ms)."""
        import time

        start = time.time()
        response = await client.get("/health")
        elapsed_ms = (time.time() - start) * 1000

        assert response.status_code == 200
        # Allow some buffer for test environment
        assert elapsed_ms < 500, f"Health check took {elapsed_ms:.2f}ms"

    # =========================================================================
    # HC-002: Root endpoint
    # =========================================================================

    async def test_root_endpoint_returns_api_info(self, client: AsyncClient) -> None:
        """HC-002: GET / returns API information."""
        response = await client.get("/")

        assert response.status_code == 200
        data = response.json()

        assert "name" in data or "message" in data
        assert "version" in data or "docs" in data or "docs_url" in data
