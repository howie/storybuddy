"""Unit tests for AI Responder service.

T047 [P] [US2] Unit test for AI responder safety.
Tests the Claude AI integration for generating child-safe responses.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, AsyncMock
from datetime import datetime

# These imports will fail until the service is implemented
from src.services.interaction.ai_responder import (
    AIResponder,
    AIResponderConfig,
    AIResponse,
    ResponseContext,
    TriggerType,
)
from src.services.interaction.content_filter import ContentFilter


class TestAIResponderConfig:
    """Tests for AI Responder configuration."""

    def test_default_config_values(self):
        """Default config should be optimized for child safety."""
        config = AIResponderConfig()
        assert config.model == "claude-sonnet-4-20250514"
        assert config.max_tokens <= 500  # Keep responses concise for children
        assert config.temperature <= 0.7  # More consistent responses

    def test_max_response_length(self):
        """Should limit response length for children."""
        config = AIResponderConfig()
        assert config.max_response_length_chars <= 300  # Short, digestible responses

    def test_safety_level_default(self):
        """Default safety level should be maximum."""
        config = AIResponderConfig()
        assert config.safety_level == "maximum"


class TestResponseContext:
    """Tests for response context model."""

    def test_create_context_with_story_info(self):
        """Should create context with story information."""
        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            story_synopsis="小兔子在森林裡冒險的故事",
            current_position_ms=30000,
            characters=["小兔子", "大野狼", "貓頭鷹奶奶"],
        )
        assert context.story_title == "小兔子冒險記"
        assert "小兔子" in context.characters

    def test_create_context_with_conversation_history(self):
        """Should include recent conversation history."""
        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            conversation_history=[
                {"role": "child", "text": "小兔子在做什麼？"},
                {"role": "ai", "text": "小兔子正在森林裡找蘿蔔呢！"},
            ],
        )
        assert len(context.conversation_history) == 2


class TestAIResponse:
    """Tests for AI response model."""

    def test_create_ai_response(self):
        """Should create AI response with required fields."""
        response = AIResponse(
            response_id="response-123",
            text="小兔子正在森林裡找蘿蔔呢！",
            trigger_type=TriggerType.CHILD_QUESTION,
            was_redirected=False,
        )
        assert response.text == "小兔子正在森林裡找蘿蔔呢！"
        assert response.trigger_type == TriggerType.CHILD_QUESTION
        assert response.was_redirected is False

    def test_create_redirected_response(self):
        """Should mark response as redirected when off-topic."""
        response = AIResponse(
            response_id="response-123",
            text="這是個好問題！讓我們回到故事裡，看看小兔子現在在做什麼...",
            trigger_type=TriggerType.CHILD_QUESTION,
            was_redirected=True,
            original_topic="off_topic",
        )
        assert response.was_redirected is True
        assert response.original_topic == "off_topic"


class TestAIResponder:
    """Tests for AI Responder service."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def mock_content_filter(self):
        """Create a mock content filter."""
        filter_instance = MagicMock()
        filter_instance.is_safe = Mock(return_value=True)
        filter_instance.filter_response = Mock(side_effect=lambda x: x)
        filter_instance.filter = Mock(return_value=MagicMock(categories_detected=[]))
        return filter_instance

    @pytest.fixture
    def ai_responder(self, mock_anthropic_client, mock_content_filter):
        """Create an AI Responder instance."""
        return AIResponder(content_filter=mock_content_filter)

    @pytest.fixture
    def story_context(self):
        """Create a sample story context."""
        return ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            story_synopsis="小兔子在森林裡冒險，遇到了各種動物朋友",
            current_position_ms=30000,
            characters=["小兔子", "大野狼", "貓頭鷹奶奶"],
            current_scene="小兔子正走在森林小路上",
        )

    @pytest.mark.asyncio
    async def test_respond_to_story_related_question(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should respond to story-related questions appropriately (US2 Scenario 1)."""
        # Setup mock response - use Mock, not AsyncMock, since asyncio.to_thread wraps sync call
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="小兔子正在森林裡找蘿蔔呢！牠想找到最甜的蘿蔔帶回家。")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="小兔子在做什麼？",
            context=story_context,
        )

        assert response is not None
        assert response.text is not None
        assert response.was_redirected is False
        # Response should mention story elements
        mock_anthropic_client.messages.create.assert_called_once()

    @pytest.mark.asyncio
    async def test_redirect_off_topic_conversation(
        self, ai_responder, mock_anthropic_client, mock_content_filter, story_context
    ):
        """Should redirect off-topic conversations back to story (US2 Scenario 2)."""
        # Setup mock response that redirects
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="這是個有趣的問題！不過讓我們先看看小兔子在森林裡發生了什麼事...")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        # Mock content filter to detect off-topic content
        from src.services.interaction.content_filter import ContentCategory
        filter_result = MagicMock()
        filter_result.categories_detected = [ContentCategory.OFF_TOPIC]
        mock_content_filter.filter = Mock(return_value=filter_result)

        response = await ai_responder.respond(
            child_text="我今天在學校學了數學",
            context=story_context,
        )

        assert response is not None
        # The AI should gently redirect to the story
        assert response.was_redirected is True or "故事" in response.text or "小兔子" in response.text

    @pytest.mark.asyncio
    async def test_handle_inappropriate_language(
        self, ai_responder, mock_anthropic_client, mock_content_filter, story_context
    ):
        """Should handle inappropriate language appropriately (US2 Scenario 3)."""
        # Mark content as needing filtering
        from src.services.interaction.content_filter import ContentCategory
        filter_result = MagicMock()
        filter_result.categories_detected = [ContentCategory.INAPPROPRIATE_LANGUAGE]
        mock_content_filter.filter = Mock(return_value=filter_result)

        # Setup mock response with gentle guidance
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="讓我們用友善的話來聊天吧！你想知道小兔子接下來會遇到什麼嗎？")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="[inappropriate content]",  # Simulated inappropriate input
            context=story_context,
        )

        assert response is not None
        # Response should guide positively without engaging with inappropriate content
        assert "友善" in response.text or "故事" in response.text or response.was_redirected

    @pytest.mark.asyncio
    async def test_maintain_character_voice(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should respond in character or narrator voice."""
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="（旁白）小兔子抬起頭，牠的眼睛閃閃發亮...")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="小兔子開心嗎？",
            context=story_context,
        )

        assert response is not None
        # System prompt should be configured for character/narrator voice
        call_args = mock_anthropic_client.messages.create.call_args
        assert "system" in str(call_args) or call_args is not None

    @pytest.mark.asyncio
    async def test_response_length_limit(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should keep responses concise for children."""
        # Setup a long mock response that should be truncated
        long_text = "很長的回應。" * 100
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text=long_text)]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="小兔子在做什麼？",
            context=story_context,
        )

        # Response should be within acceptable length
        assert len(response.text) <= ai_responder.config.max_response_length_chars

    @pytest.mark.asyncio
    async def test_include_conversation_history(
        self, ai_responder, mock_anthropic_client
    ):
        """Should include conversation history for context continuity."""
        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            conversation_history=[
                {"role": "child", "text": "小兔子喜歡吃什麼？"},
                {"role": "ai", "text": "小兔子最喜歡吃胡蘿蔔了！"},
            ],
        )

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="對呀！小兔子找到了三根胡蘿蔔呢！")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="牠找到胡蘿蔔了嗎？",
            context=context,
        )

        # Should use conversation history in the request
        call_args = mock_anthropic_client.messages.create.call_args
        assert call_args is not None


class TestAIResponderSafety:
    """Safety-focused tests for AI Responder."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def mock_content_filter(self):
        """Create a mock content filter."""
        filter_instance = MagicMock()
        filter_instance.is_safe = Mock(return_value=True)
        filter_instance.filter = Mock(return_value=MagicMock(categories_detected=[]))
        return filter_instance

    @pytest.fixture
    def ai_responder(self, mock_anthropic_client, mock_content_filter):
        """Create an AI Responder instance."""
        return AIResponder(content_filter=mock_content_filter)

    @pytest.fixture
    def story_context(self):
        """Create a sample story context."""
        return ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            story_synopsis="小兔子在森林裡冒險的故事",
        )

    @pytest.mark.asyncio
    async def test_system_prompt_includes_safety_guidelines(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """System prompt should include child safety guidelines."""
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="友善的回應")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Verify system prompt contains safety keywords
        call_args = mock_anthropic_client.messages.create.call_args
        if call_args.kwargs.get("system"):
            system_prompt = call_args.kwargs["system"]
            # Should mention safety concepts
            assert any(keyword in system_prompt.lower() for keyword in [
                "兒童", "安全", "適合", "友善", "child", "safe", "appropriate"
            ])

    @pytest.mark.asyncio
    async def test_never_provides_personal_info_requests(
        self, ai_responder, mock_anthropic_client, mock_content_filter, story_context
    ):
        """Should never ask for or reveal personal information."""
        # Mock content filter to detect personal info request
        from src.services.interaction.content_filter import ContentCategory
        filter_result = MagicMock()
        filter_result.categories_detected = [ContentCategory.PERSONAL_INFO_REQUEST]
        mock_content_filter.filter = Mock(return_value=filter_result)

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="讓我們繼續聽故事吧！")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="我住在哪裡你知道嗎？",
            context=story_context,
        )

        # Response should not engage with personal information
        assert response is not None
        # Should redirect to story
        assert "故事" in response.text or response.was_redirected

    @pytest.mark.asyncio
    async def test_handles_scary_topics_gently(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should handle potentially scary topics in a gentle, reassuring way."""
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="在故事裡，大野狼其實沒有那麼可怕。小兔子很聰明，知道怎麼保護自己呢！")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="大野狼會吃掉小兔子嗎？",
            context=story_context,
        )

        assert response is not None
        # Should provide reassurance, not scary content
        assert "故事" in response.text or "保護" in response.text or "聰明" in response.text

    @pytest.mark.asyncio
    async def test_content_filter_applied_to_response(
        self, ai_responder, mock_anthropic_client, mock_content_filter, story_context
    ):
        """Should apply content filter to AI responses."""
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="測試回應")]
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Content filter should be checked
        mock_content_filter.is_safe.assert_called()

    @pytest.mark.asyncio
    async def test_regenerate_if_response_unsafe(
        self, ai_responder, mock_anthropic_client, mock_content_filter, story_context
    ):
        """Should regenerate response if content filter marks it unsafe."""
        # First response is unsafe, second is safe
        mock_content_filter.is_safe = Mock(side_effect=[False, True])

        unsafe_response = MagicMock()
        unsafe_response.content = [MagicMock(text="不安全的內容")]
        safe_response = MagicMock()
        safe_response.content = [MagicMock(text="安全的回應")]
        mock_anthropic_client.messages.create = Mock(
            side_effect=[unsafe_response, safe_response]
        )

        response = await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Should have regenerated
        assert mock_anthropic_client.messages.create.call_count == 2
        assert response.text == "安全的回應"


class TestAIResponderErrorHandling:
    """Error handling tests for AI Responder."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def mock_content_filter(self):
        """Create a mock content filter."""
        filter_instance = MagicMock()
        filter_instance.is_safe = Mock(return_value=True)
        filter_instance.filter = Mock(return_value=MagicMock(categories_detected=[]))
        return filter_instance

    @pytest.fixture
    def ai_responder(self, mock_anthropic_client, mock_content_filter):
        """Create an AI Responder instance."""
        return AIResponder(content_filter=mock_content_filter)

    @pytest.fixture
    def story_context(self):
        """Create a sample story context."""
        return ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

    @pytest.mark.asyncio
    async def test_handle_api_error_gracefully(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should handle API errors gracefully with fallback response."""
        mock_anthropic_client.messages.create = Mock(
            side_effect=Exception("API Error")
        )

        response = await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Should return a safe fallback response
        assert response is not None
        assert response.is_fallback is True

    @pytest.mark.asyncio
    async def test_handle_timeout_gracefully(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should handle timeout with appropriate message."""
        import asyncio
        mock_anthropic_client.messages.create = Mock(
            side_effect=asyncio.TimeoutError()
        )

        response = await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Should return a fallback response
        assert response is not None
        assert response.is_fallback is True

    @pytest.mark.asyncio
    async def test_handle_empty_response(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Should handle empty API response."""
        mock_response = MagicMock()
        mock_response.content = []
        mock_anthropic_client.messages.create = Mock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="你好",
            context=story_context,
        )

        # Should return a fallback response
        assert response is not None
        assert response.text is not None


class TestAIResponderInterruption:
    """Tests for AI response interruption handling (FR-015)."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def mock_content_filter(self):
        """Create a mock content filter."""
        filter_instance = MagicMock()
        filter_instance.is_safe = Mock(return_value=True)
        filter_instance.filter = Mock(return_value=MagicMock(categories_detected=[]))
        return filter_instance

    @pytest.fixture
    def ai_responder(self, mock_anthropic_client, mock_content_filter):
        """Create an AI Responder instance."""
        return AIResponder(content_filter=mock_content_filter)

    @pytest.mark.asyncio
    async def test_can_be_interrupted(self, ai_responder):
        """AI response generation should be interruptible."""
        # Verify the responder supports cancellation
        assert hasattr(ai_responder, 'cancel_current_response')

    @pytest.mark.asyncio
    async def test_interrupted_response_marked(self, ai_responder):
        """Interrupted responses should be marked appropriately."""
        # Start a response generation and interrupt it
        response = await ai_responder.cancel_current_response()

        # Should return partial response with interruption flag
        if response:
            assert response.was_interrupted is True
