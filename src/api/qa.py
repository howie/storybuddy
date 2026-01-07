"""Q&A API routes for StoryBuddy."""

import logging
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from src.db.repository import (
    PendingQuestionRepository,
    QAMessageRepository,
    QASessionRepository,
    StoryRepository,
)
from src.models import MessageRole, QASessionStatus
from src.models.qa import (
    EndSessionRequest,
    QAMessageCreate,
    QAMessageResponse,
    QASession,
    QASessionCreate,
    QASessionResponse,
    QASessionUpdate,
    QASessionWithMessages,
    SendMessageRequest,
    SendMessageResponse,
)
from src.models.question import PendingQuestionCreate
from src.services.qa_handler import get_qa_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/qa", tags=["qa"])

# Maximum messages allowed per session (5 exchanges = 10 messages)
MAX_MESSAGES_PER_SESSION = 10


@router.post("/sessions", response_model=QASessionResponse, status_code=status.HTTP_201_CREATED)
async def start_qa_session(data: QASessionCreate) -> QASession:
    """Start a new Q&A session for a story.

    - **story_id**: UUID of the story to discuss
    """
    # Verify story exists
    story = await StoryRepository.get_by_id(data.story_id)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found",
        )

    session = await QASessionRepository.create(data)
    return session


@router.get("/sessions/{session_id}", response_model=QASessionWithMessages)
async def get_qa_session(session_id: UUID) -> QASessionWithMessages:
    """Get a Q&A session by ID with all messages."""
    session = await QASessionRepository.get_by_id(session_id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    messages = await QAMessageRepository.get_by_session_id(session_id)

    return QASessionWithMessages(
        id=session.id,
        story_id=session.story_id,
        started_at=session.started_at,
        ended_at=session.ended_at,
        message_count=session.message_count,
        status=session.status,
        messages=[QAMessageResponse.model_validate(m.model_dump()) for m in messages],
    )


@router.patch("/sessions/{session_id}", response_model=QASessionResponse)
async def end_qa_session(session_id: UUID, data: EndSessionRequest) -> QASession:
    """End a Q&A session.

    - **status**: Final status ("completed" or "timeout")
    """
    session = await QASessionRepository.get_by_id(session_id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    updated = await QASessionRepository.update(
        session_id,
        QASessionUpdate(status=data.status, ended_at=datetime.utcnow()),
    )

    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    return updated


@router.post("/sessions/{session_id}/messages", response_model=SendMessageResponse)
async def send_qa_message(session_id: UUID, data: SendMessageRequest) -> SendMessageResponse:
    """Send a question and receive an AI response.

    - **content**: Question text (max 500 characters)

    Returns both the user's message and the AI's response.
    """
    # Get session
    session = await QASessionRepository.get_by_id(session_id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    # Check session is active
    if session.status != QASessionStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is not active",
        )

    # Check message limit
    current_count = await QAMessageRepository.get_message_count(session_id)
    if current_count >= MAX_MESSAGES_PER_SESSION:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message limit reached. Maximum 10 messages per session.",
        )

    # Get story for context
    story = await StoryRepository.get_by_id(session.story_id)
    if story is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Story associated with session not found",
        )

    # Create user message
    user_message = await QAMessageRepository.create(
        QAMessageCreate(
            session_id=session_id,
            role=MessageRole.CHILD,
            content=data.content,
            is_in_scope=None,  # Will be determined by AI
            audio_input_path=None,
            audio_output_path=None,
            sequence=current_count + 1,
        )
    )

    # Get conversation history for context
    previous_messages = await QAMessageRepository.get_by_session_id(session_id)
    conversation_history = [
        {"role": "user" if msg.role == MessageRole.CHILD else "assistant", "content": msg.content}
        for msg in previous_messages[:-1]  # Exclude the message we just created
    ]

    # Use Claude Q&A service
    qa_service = get_qa_service()
    qa_response = await qa_service.answer_question(
        question=data.content,
        story=story,
        conversation_history=conversation_history,
    )

    is_in_scope = qa_response.is_in_scope
    ai_response_content = qa_response.answer

    # If question is out of scope, save to pending questions
    if qa_response.should_save_question:
        try:
            await PendingQuestionRepository.create(
                PendingQuestionCreate(
                    parent_id=story.parent_id,
                    story_id=story.id,
                    qa_session_id=session_id,
                    question=data.content,
                )
            )
            logger.info(f"Saved out-of-scope question for parent {story.parent_id}")
        except Exception as e:
            logger.error(f"Failed to save pending question: {e}")

    # Create assistant message
    assistant_message = await QAMessageRepository.create(
        QAMessageCreate(
            session_id=session_id,
            role=MessageRole.ASSISTANT,
            content=ai_response_content,
            is_in_scope=is_in_scope,
            audio_input_path=None,
            audio_output_path=None,
            sequence=current_count + 2,
        )
    )

    # Update session message count
    await QASessionRepository.increment_message_count(session_id)
    await QASessionRepository.increment_message_count(session_id)

    return SendMessageResponse(
        user_message=QAMessageResponse.model_validate(user_message.model_dump()),
        assistant_message=QAMessageResponse.model_validate(assistant_message.model_dump()),
        is_in_scope=is_in_scope,
        audio_url=None,  # Would be generated by TTS service
    )
