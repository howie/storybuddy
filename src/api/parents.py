"""Parent API routes for StoryBuddy."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from src.db.repository import ParentRepository
from src.models.parent import Parent, ParentCreate, ParentResponse, ParentUpdate

router = APIRouter(prefix="/parents", tags=["Parents"])


@router.post(
    "",
    response_model=ParentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new parent",
)
async def create_parent(data: ParentCreate) -> Parent:
    """Create a new parent account."""
    return await ParentRepository.create(data)


@router.get(
    "/{parent_id}",
    response_model=ParentResponse,
    summary="Get parent by ID",
)
async def get_parent(parent_id: UUID) -> Parent:
    """Get a parent by their ID."""
    parent = await ParentRepository.get_by_id(parent_id)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Parent {parent_id} not found",
        )
    return parent


@router.get(
    "",
    response_model=list[ParentResponse],
    summary="List all parents",
)
async def list_parents(limit: int = 100, offset: int = 0) -> list[Parent]:
    """List all parents with pagination."""
    return await ParentRepository.get_all(limit=limit, offset=offset)


@router.patch(
    "/{parent_id}",
    response_model=ParentResponse,
    summary="Update a parent",
)
async def update_parent(parent_id: UUID, data: ParentUpdate) -> Parent:
    """Update an existing parent."""
    parent = await ParentRepository.update(parent_id, data)
    if parent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Parent {parent_id} not found",
        )
    return parent


@router.delete(
    "/{parent_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a parent",
)
async def delete_parent(parent_id: UUID) -> None:
    """Delete a parent and all associated data."""
    deleted = await ParentRepository.delete(parent_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Parent {parent_id} not found",
        )
