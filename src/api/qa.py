"""Q&A API routes for StoryBuddy."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from src.db.repository import QAMessageRepository, QASessionRepository, StoryRepository
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
async def send_qa_message(
    session_id: UUID, data: SendMessageRequest
) -> SendMessageResponse:
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

    # Generate AI response using Claude
    from src.services.llm import get_claude_service

    try:
        claude = get_claude_service()
        qa_result = await claude.answer_question(story.content, data.content)
        is_in_scope = qa_result.is_in_scope
        ai_response_content = qa_result.answer
    except ValueError:
        # API key not configured, use mock response
        is_in_scope = True
        ai_response_content = _generate_mock_response(data.content, story.content)
    except RuntimeError:
        # Claude API error, use mock response
        is_in_scope = True
        ai_response_content = _generate_mock_response(data.content, story.content)

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


def _generate_mock_response(question: str, _story_content: str) -> str:
    """Generate a mock AI response for testing.

    In production, this would be replaced by Claude Q&A handler.
    The _story_content parameter will be used to provide context.
    """
    # Simple placeholder response
    question_lower = question.lower()

    if "who" in question_lower:
        return "That's a great question! The story mentions a brave little rabbit who lived in the forest with friends like an owl and a deer."
    elif "what" in question_lower:
        return "The story tells us about an adventure in the forest with the rabbit and its friends."
    elif "where" in question_lower:
        return "The story takes place in a forest where the rabbit and its friends live."
    elif "why" in question_lower:
        return "That's interesting to think about! The characters in our story had their own reasons for going on adventures."
    elif "how" in question_lower:
        return "The story shows us how the characters worked together as friends."
    else:
        return "That's a wonderful question! Let me tell you more about the story."
