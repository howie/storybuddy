"""Parent model for StoryBuddy."""

from datetime import datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class ParentBase(BaseModel):
    """Base parent model with common fields."""

    name: str = Field(..., max_length=100, description="Parent's display name")
    email: str | None = Field(None, max_length=255, description="Parent's email (optional)")


class ParentCreate(ParentBase):
    """Model for creating a new parent."""

    pass


class ParentUpdate(BaseModel):
    """Model for updating an existing parent."""

    name: str | None = Field(None, max_length=100)
    email: str | None = Field(None, max_length=255)


class Parent(ParentBase):
    """Full parent model with all fields."""

    id: UUID = Field(default_factory=uuid4, description="Unique identifier")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
    updated_at: datetime = Field(
        default_factory=datetime.utcnow, description="Last update timestamp"
    )

    model_config = {"from_attributes": True}


class ParentResponse(Parent):
    """Parent model for API responses."""

    pass
