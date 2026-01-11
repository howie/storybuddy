"""AI Responder service for interactive story mode.

T051 [US2] Implement AI responder with Claude integration.
Generates child-safe AI responses using Anthropic's Claude API.
"""

import asyncio
import logging
import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any

from anthropic import Anthropic, APIError, APITimeoutError, RateLimitError

from src.services.interaction.content_filter import ContentFilter
from src.services.interaction.prompts import (
    StoryContext,
    build_system_prompt,
    get_fallback_response,
)

logger = logging.getLogger(__name__)


class TriggerType(Enum):
    """Types of AI response triggers."""

    CHILD_QUESTION = "child_question"
    STORY_PROMPT = "story_prompt"
    CLARIFICATION = "clarification"
    CONTINUATION = "continuation"


@dataclass
class AIResponderConfig:
    """Configuration for AI Responder."""

    model: str = "claude-sonnet-4-20250514"
    max_tokens: int = 300
    temperature: float = 0.7
    max_response_length_chars: int = 250
    safety_level: str = "maximum"
    timeout_seconds: float = 10.0
    max_retries: int = 2
    retry_delay_seconds: float = 1.0


@dataclass
class ResponseContext:
    """Context for generating AI responses."""

    session_id: str
    story_id: str
    story_title: str
    story_synopsis: str = ""
    current_position_ms: int = 0
    characters: list[str] = field(default_factory=list)
    current_scene: str = ""
    conversation_history: list[dict[str, str]] = field(default_factory=list)
    themes: list[str] = field(default_factory=list)


@dataclass
class AIResponse:
    """AI response data."""

    response_id: str
    text: str
    trigger_type: TriggerType
    was_redirected: bool = False
    was_interrupted: bool = False
    original_topic: str | None = None
    is_fallback: bool = False
    created_at: datetime = field(default_factory=datetime.utcnow)
    processing_time_ms: int = 0

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "responseId": self.response_id,
            "text": self.text,
            "triggerType": self.trigger_type.value,
            "wasRedirected": self.was_redirected,
            "wasInterrupted": self.was_interrupted,
            "isFallback": self.is_fallback,
            "createdAt": self.created_at.isoformat() + "Z",
            "processingTimeMs": self.processing_time_ms,
        }


class AIResponder:
    """AI Responder service for generating child-safe responses.

    Uses Anthropic's Claude API with safety-focused system prompts
    to generate appropriate responses for children during interactive
    story sessions.
    """

    def __init__(
        self,
        config: AIResponderConfig | None = None,
        content_filter: ContentFilter | None = None,
    ):
        """Initialize AI Responder.

        Args:
            config: Configuration options.
            content_filter: Content filter for validating responses.
        """
        self.config = config or AIResponderConfig()
        self._client = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))
        self._content_filter = content_filter or ContentFilter()
        self._current_task: asyncio.Task | None = None
        self._is_generating = False

    async def respond(
        self,
        child_text: str,
        context: ResponseContext,
        trigger_type: TriggerType = TriggerType.CHILD_QUESTION,
    ) -> AIResponse:
        """Generate an AI response to the child's input.

        Args:
            child_text: The child's speech transcription.
            context: Story and conversation context.
            trigger_type: What triggered this response.

        Returns:
            AI response object.
        """
        start_time = datetime.utcnow()
        response_id = str(uuid.uuid4())

        # Handle empty input
        if not child_text or not child_text.strip():
            return AIResponse(
                response_id=response_id,
                text=get_fallback_response("empty_input"),
                trigger_type=trigger_type,
                is_fallback=True,
            )

        # Check input content
        input_filter_result = self._content_filter.filter(
            child_text, context={"story_title": context.story_title}
        )
        was_redirected = len(input_filter_result.categories_detected) > 0

        # Build system prompt
        story_context = StoryContext(
            title=context.story_title,
            synopsis=context.story_synopsis,
            characters=context.characters,
            current_scene=context.current_scene,
            themes=context.themes,
        )
        system_prompt = build_system_prompt(
            story_context=story_context,
            conversation_history=context.conversation_history,
        )

        # Build messages
        messages = self._build_messages(child_text, context)

        # Try to generate response
        for attempt in range(self.config.max_retries + 1):
            try:
                self._is_generating = True
                response_text = await self._call_api(system_prompt, messages)
                self._is_generating = False

                # Check if response was cancelled
                if response_text is None:
                    return AIResponse(
                        response_id=response_id,
                        text="",
                        trigger_type=trigger_type,
                        was_interrupted=True,
                    )

                # Validate response with content filter
                filter_result = self._content_filter.is_safe(response_text)

                if not filter_result:
                    logger.warning(
                        f"Response failed content filter, regenerating (attempt {attempt + 1})"
                    )
                    if attempt < self.config.max_retries:
                        await asyncio.sleep(self.config.retry_delay_seconds)
                        continue
                    # Use fallback if all retries failed
                    response_text = get_fallback_response("default")

                # Truncate if too long
                if len(response_text) > self.config.max_response_length_chars:
                    response_text = self._truncate_response(response_text)

                processing_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)

                return AIResponse(
                    response_id=response_id,
                    text=response_text,
                    trigger_type=trigger_type,
                    was_redirected=was_redirected,
                    processing_time_ms=processing_time,
                )

            except (TimeoutError, APITimeoutError):
                logger.warning(f"API timeout (attempt {attempt + 1})")
                if attempt < self.config.max_retries:
                    await asyncio.sleep(self.config.retry_delay_seconds)
                    continue

            except RateLimitError:
                logger.warning(f"Rate limit exceeded (attempt {attempt + 1})")
                if attempt < self.config.max_retries:
                    await asyncio.sleep(self.config.retry_delay_seconds * 2)
                    continue

            except APIError as e:
                logger.error(f"API error: {e}")
                break

            except Exception as e:
                logger.error(f"Unexpected error generating response: {e}")
                break

            finally:
                self._is_generating = False

        # Return fallback response on failure
        return AIResponse(
            response_id=response_id,
            text=get_fallback_response("error"),
            trigger_type=trigger_type,
            is_fallback=True,
        )

    async def _call_api(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
    ) -> str | None:
        """Call the Anthropic API.

        Args:
            system_prompt: System prompt for safety guidelines.
            messages: Conversation messages.

        Returns:
            Response text, or None if cancelled.
        """
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(
                    self._client.messages.create,
                    model=self.config.model,
                    max_tokens=self.config.max_tokens,
                    temperature=self.config.temperature,
                    system=system_prompt,
                    messages=messages,
                ),
                timeout=self.config.timeout_seconds,
            )

            if response.content and len(response.content) > 0:
                return response.content[0].text
            return None

        except asyncio.CancelledError:
            logger.info("Response generation cancelled")
            return None

    def _build_messages(
        self,
        child_text: str,
        context: ResponseContext,
    ) -> list[dict[str, str]]:
        """Build the message list for the API call.

        Args:
            child_text: Current child input.
            context: Conversation context.

        Returns:
            List of message dictionaries.
        """
        messages = []

        # Add recent conversation history
        for turn in context.conversation_history[-4:]:  # Last 4 turns
            role = turn.get("role", "")
            text = turn.get("text", "")

            if role == "child":
                messages.append({"role": "user", "content": text})
            elif role == "ai":
                messages.append({"role": "assistant", "content": text})

        # Add current input
        messages.append({"role": "user", "content": child_text})

        return messages

    def _truncate_response(self, text: str) -> str:
        """Truncate response to fit within limits.

        Tries to truncate at natural sentence boundaries.

        Args:
            text: Original response text.

        Returns:
            Truncated text.
        """
        max_len = self.config.max_response_length_chars

        if len(text) <= max_len:
            return text

        # Try to find a natural break point
        truncated = text[:max_len]

        # Look for sentence endings
        for end_char in ["。", "！", "？", ".", "!", "?"]:
            last_end = truncated.rfind(end_char)
            if last_end > max_len * 0.5:  # At least half the content
                return truncated[: last_end + 1]

        # Look for other break points
        for break_char in ["，", "、", ",", " "]:
            last_break = truncated.rfind(break_char)
            if last_break > max_len * 0.7:
                return truncated[:last_break] + "..."

        # Hard truncate with ellipsis
        return truncated[:-3] + "..."

    async def cancel_current_response(self) -> AIResponse | None:
        """Cancel the current response generation.

        Returns:
            Partial response if available, None otherwise.
        """
        if self._current_task and not self._current_task.done():
            self._current_task.cancel()
            try:
                await self._current_task
            except asyncio.CancelledError:
                pass

        self._is_generating = False

        return AIResponse(
            response_id=str(uuid.uuid4()),
            text="",
            trigger_type=TriggerType.CHILD_QUESTION,
            was_interrupted=True,
        )

    @property
    def is_generating(self) -> bool:
        """Check if currently generating a response."""
        return self._is_generating
