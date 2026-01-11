"""Pending Questions API routes for StoryBuddy."""

from pathlib import Path
from uuid import UUID

import aiofiles
from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse

from src.config import get_settings
from src.db.repository import PendingQuestionRepository
from src.models import PendingQuestionStatus
from src.models.question import (
    PendingQuestion,
    PendingQuestionAnswer,
    PendingQuestionResponse,
)

router = APIRouter(prefix="/questions", tags=["questions"])
settings = get_settings()


@router.get("", response_model=list[PendingQuestionResponse])
async def list_pending_questions(
    parent_id: UUID = Query(..., description="Parent ID to filter questions"),
    status_filter: PendingQuestionStatus | None = Query(
        None, alias="status", description="Filter by status"
    ),
) -> list[PendingQuestion]:
    """List all pending questions for a parent.

    - **parent_id**: Required parent ID
    - **status**: Optional filter by "pending" or "answered"
    """
    questions = await PendingQuestionRepository.get_by_parent_id(
        parent_id=parent_id,
        status=status_filter,
    )
    return questions


@router.get("/{question_id}", response_model=PendingQuestionResponse)
async def get_pending_question(question_id: UUID) -> PendingQuestion:
    """Get a pending question by ID."""
    question = await PendingQuestionRepository.get_by_id(question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )
    return question


@router.post("/{question_id}/answer", response_model=PendingQuestionResponse)
async def answer_question(
    question_id: UUID,
    data: PendingQuestionAnswer,
) -> PendingQuestion:
    """Answer a pending question with text.

    - **answer**: The parent's text answer (max 2000 characters)
    """
    # Verify question exists
    question = await PendingQuestionRepository.get_by_id(question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    # Check if already answered
    if question.status == PendingQuestionStatus.ANSWERED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Question has already been answered",
        )

    # Update with answer
    updated = await PendingQuestionRepository.answer_question(
        question_id=question_id,
        answer=data.answer,
    )

    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save answer",
        )

    return updated


@router.post("/{question_id}/answer/audio", response_model=PendingQuestionResponse)
async def answer_question_with_audio(
    question_id: UUID,
    audio: UploadFile = File(..., description="Audio file with the answer"),
    transcription: str | None = Form(None, description="Optional text transcription"),
) -> PendingQuestion:
    """Answer a pending question with audio.

    - **audio**: Audio file with the parent's answer
    - **transcription**: Optional text transcription of the audio
    """
    # Verify question exists
    question = await PendingQuestionRepository.get_by_id(question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    # Check if already answered
    if question.status == PendingQuestionStatus.ANSWERED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Question has already been answered",
        )

    # Save audio file
    audio_dir = settings.parent_answers_dir / str(question_id)
    audio_dir.mkdir(parents=True, exist_ok=True)

    # Determine file extension
    ext = "mp3"
    if audio.filename:
        ext = audio.filename.rsplit(".", 1)[-1].lower()

    audio_path = audio_dir / f"answer.{ext}"

    content = await audio.read()
    async with aiofiles.open(audio_path, "wb") as f:
        await f.write(content)

    # Use transcription or placeholder
    answer_text = transcription or "[語音回答]"

    # Update with answer
    updated = await PendingQuestionRepository.answer_question(
        question_id=question_id,
        answer=answer_text,
        answer_audio_path=str(audio_path),
    )

    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save answer",
        )

    return updated


@router.get("/{question_id}/answer/audio")
async def get_question_answer_audio(question_id: UUID) -> FileResponse:
    """Get the audio answer for a question.

    Returns the audio file as audio/mpeg content.
    """
    question = await PendingQuestionRepository.get_by_id(question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    if question.answer_audio_path is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No audio answer for this question",
        )

    audio_path = Path(question.answer_audio_path)
    if not audio_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio file not found",
        )

    return FileResponse(
        path=audio_path,
        media_type="audio/mpeg",
        filename=f"answer_{question_id}.mp3",
    )


@router.delete("/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_pending_question(question_id: UUID) -> None:
    """Delete a pending question."""
    deleted = await PendingQuestionRepository.delete(question_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )
