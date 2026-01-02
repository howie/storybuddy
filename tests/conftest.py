"""Pytest configuration and fixtures for StoryBuddy tests."""

import asyncio
from collections.abc import AsyncGenerator, Generator
from typing import Any

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from src.db.init import init_database, reset_database
from src.main import app


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def test_db() -> AsyncGenerator[None, None]:
    """Initialize a fresh test database."""
    await reset_database()
    await init_database()
    yield
    await reset_database()


@pytest_asyncio.fixture
async def client(test_db: None) -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for testing."""
    transport = ASGITransport(app=app)  # type: ignore[arg-type]
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_parent_data() -> dict[str, Any]:
    """Sample parent data for testing."""
    return {"name": "Test Parent", "email": "test@example.com"}


@pytest.fixture
def sample_voice_profile_data() -> dict[str, str]:
    """Sample voice profile data for testing."""
    return {"name": "爸爸"}
