"""Integration tests for safe AI response generation.

T049 [P] [US2] Integration test for safe AI responses.
Tests the end-to-end flow from child speech to safe AI response.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, AsyncMock
import asyncio
from datetime import datetime

# These imports will fail until the services are implemented
from src.services.interaction.ai_responder import AIResponder, ResponseContext, TriggerType
from src.services.interaction.content_filter import ContentFilter, ContentCategory
from src.services.interaction.session_manager import SessionManager
from src.models.enums import SessionMode, SessionStatus


class TestAIResponseIntegration:
    """Integration tests for AI response generation flow."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.fixture
    def content_filter(self):
        """Create a real content filter instance."""
        return ContentFilter()

    @pytest.fixture
    def ai_responder(self, mock_anthropic_client, content_filter):
        """Create AI responder with real content filter."""
        with patch("src.services.interaction.ai_responder.ContentFilter", return_value=content_filter):
            return AIResponder()

    @pytest.fixture
    def story_context(self):
        """Create a sample story context."""
        return ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            story_synopsis="小兔子在森林裡冒險，遇到了各種動物朋友，學習勇氣與友誼的故事",
            current_position_ms=30000,
            characters=["小兔子", "大野狼", "貓頭鷹奶奶", "小松鼠"],
            current_scene="小兔子正走在森林小路上，聽到了奇怪的聲音",
        )

    @pytest.mark.asyncio
    async def test_story_related_question_flow(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Test complete flow for story-related questions (US2 Scenario 1)."""
        # Setup mock to return story-appropriate response
        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="小兔子正在仔細聽那個聲音呢！原來是風吹過樹葉的沙沙聲，小兔子鬆了一口氣。"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        # Child asks about the story
        response = await ai_responder.respond(
            child_text="小兔子在做什麼？那個聲音是什麼？",
            context=story_context,
        )

        # Verify response is appropriate
        assert response is not None
        assert response.text is not None
        assert len(response.text) > 0
        assert response.was_redirected is False

        # Verify system prompt was sent
        call_args = mock_anthropic_client.messages.create.call_args
        assert call_args is not None

    @pytest.mark.asyncio
    async def test_off_topic_redirection_flow(
        self, ai_responder, mock_anthropic_client, story_context
    ):
        """Test complete flow for off-topic redirection (US2 Scenario 2)."""
        # Setup mock to return redirection response
        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="數學很有趣呢！不過現在讓我們先看看小兔子在森林裡會發生什麼事。你覺得那個聲音是什麼呢？"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        # Child talks about unrelated topic
        response = await ai_responder.respond(
            child_text="我今天在學校學了數學，1+1=2",
            context=story_context,
        )

        # Response should acknowledge but redirect
        assert response is not None
        assert "故事" in response.text or "小兔子" in response.text or "森林" in response.text
        assert response.was_redirected is True

    @pytest.mark.asyncio
    async def test_inappropriate_content_handling_flow(
        self, ai_responder, mock_anthropic_client, content_filter, story_context
    ):
        """Test complete flow for inappropriate content (US2 Scenario 3)."""
        # Setup mock to return gentle guidance
        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="我們來用友善的話聊天吧！你想知道小兔子在森林裡會遇到什麼朋友嗎？"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        # Simulate inappropriate input (content filter will flag)
        response = await ai_responder.respond(
            child_text="壞話壞話",
            context=story_context,
        )

        # Response should guide positively
        assert response is not None
        # Should redirect to story without engaging inappropriate content
        assert "友善" in response.text or "小兔子" in response.text or response.was_redirected


class TestContentFilterIntegration:
    """Integration tests for content filter with AI response."""

    @pytest.fixture
    def content_filter(self):
        """Create a real content filter instance."""
        return ContentFilter()

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.mark.asyncio
    async def test_filter_validates_ai_output(
        self, content_filter, mock_anthropic_client
    ):
        """Content filter should validate all AI outputs."""
        # Create AI responder with real content filter
        with patch("src.services.interaction.ai_responder.ContentFilter", return_value=content_filter):
            ai_responder = AIResponder()

        story_context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        # Setup safe response
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="小兔子開心地跳來跳去！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="小兔子開心嗎？",
            context=story_context,
        )

        # Response should pass content filter
        filter_result = content_filter.filter(response.text)
        assert filter_result.is_safe is True

    @pytest.mark.asyncio
    async def test_filter_triggers_regeneration_for_unsafe(
        self, content_filter, mock_anthropic_client
    ):
        """Unsafe AI output should trigger regeneration."""
        # Mock content filter to flag first response as unsafe
        with patch.object(content_filter, 'is_safe', side_effect=[False, True]):
            with patch("src.services.interaction.ai_responder.ContentFilter", return_value=content_filter):
                ai_responder = AIResponder()

            story_context = ResponseContext(
                session_id="session-123",
                story_id="story-456",
                story_title="小兔子冒險記",
            )

            # First response is flagged, second is safe
            unsafe_response = MagicMock()
            unsafe_response.content = [MagicMock(text="不適當的內容")]
            safe_response = MagicMock()
            safe_response.content = [MagicMock(text="安全的回應")]
            mock_anthropic_client.messages.create = AsyncMock(
                side_effect=[unsafe_response, safe_response]
            )

            response = await ai_responder.respond(
                child_text="你好",
                context=story_context,
            )

            # Should have called API twice
            assert mock_anthropic_client.messages.create.call_count == 2
            assert response.text == "安全的回應"


class TestPersonalInfoProtection:
    """Integration tests for personal information protection."""

    @pytest.fixture
    def content_filter(self):
        """Create a real content filter instance."""
        return ContentFilter()

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.mark.asyncio
    async def test_never_asks_for_personal_info(
        self, content_filter, mock_anthropic_client
    ):
        """AI should never ask for personal information."""
        with patch("src.services.interaction.ai_responder.ContentFilter", return_value=content_filter):
            ai_responder = AIResponder()

        story_context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        # Setup response that doesn't ask for personal info
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="讓我們繼續聽故事吧！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        # Child mentions personal info topic
        response = await ai_responder.respond(
            child_text="你想知道我住在哪裡嗎？",
            context=story_context,
        )

        # AI should not ask for personal info
        assert response is not None
        personal_info_keywords = ["住在哪", "電話", "地址", "學校", "名字是什麼"]
        assert not any(keyword in response.text for keyword in personal_info_keywords)

    @pytest.mark.asyncio
    async def test_redirects_personal_info_discussion(
        self, content_filter, mock_anthropic_client
    ):
        """AI should redirect personal info discussions back to story."""
        with patch("src.services.interaction.ai_responder.ContentFilter", return_value=content_filter):
            ai_responder = AIResponder()

        story_context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="小兔子也有自己的小窩呢！牠住在一個溫暖的地洞裡。你想知道小兔子的家長什麼樣子嗎？"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="我家住在台北",
            context=story_context,
        )

        # Should redirect to story content
        assert response is not None
        assert "小兔子" in response.text


class TestFearManagement:
    """Integration tests for managing fear-inducing content."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.mark.asyncio
    async def test_handles_scary_questions_reassuringly(
        self, mock_anthropic_client
    ):
        """AI should handle scary questions with reassurance."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        story_context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            characters=["小兔子", "大野狼"],
        )

        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="在這個故事裡，大野狼其實沒有那麼可怕喔！而且小兔子很聰明，牠知道怎麼保護自己。你放心，故事的結局一定會很美好的！"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="大野狼會不會把小兔子吃掉？我好怕",
            context=story_context,
        )

        # Response should be reassuring
        assert response is not None
        reassuring_keywords = ["不會", "沒關係", "不用怕", "放心", "聰明", "保護", "美好"]
        assert any(keyword in response.text for keyword in reassuring_keywords)


class TestConversationContinuity:
    """Integration tests for conversation continuity."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.mark.asyncio
    async def test_maintains_conversation_context(
        self, mock_anthropic_client
    ):
        """AI should maintain context across conversation turns."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        # Context with conversation history
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
        mock_response.content = [MagicMock(
            text="對呀！小兔子今天找到了三根很大的胡蘿蔔，牠開心得不得了呢！"
        )]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="牠找到胡蘿蔔了嗎？",
            context=context,
        )

        # Response should reference the conversation history
        assert response is not None
        assert "胡蘿蔔" in response.text

    @pytest.mark.asyncio
    async def test_builds_conversation_history(
        self, mock_anthropic_client
    ):
        """Multiple turns should build conversation history."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
            conversation_history=[],
        )

        # First turn
        mock_response1 = MagicMock()
        mock_response1.content = [MagicMock(text="小兔子正在森林裡散步呢！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response1)

        response1 = await ai_responder.respond(
            child_text="小兔子在做什麼？",
            context=context,
        )

        # Update context with first turn
        context.conversation_history.append({"role": "child", "text": "小兔子在做什麼？"})
        context.conversation_history.append({"role": "ai", "text": response1.text})

        # Second turn
        mock_response2 = MagicMock()
        mock_response2.content = [MagicMock(text="小兔子看到了一隻可愛的小松鼠！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response2)

        response2 = await ai_responder.respond(
            child_text="牠遇到誰了？",
            context=context,
        )

        assert len(context.conversation_history) == 2
        assert response2 is not None


class TestSessionManagerWithAI:
    """Integration tests for session manager with AI responder."""

    @pytest.fixture
    def mock_services(self):
        """Setup all mocked services."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock_anthropic, \
             patch("src.services.interaction.ai_responder.ContentFilter"), \
             patch("src.services.interaction.session_manager.VADService"), \
             patch("src.services.interaction.session_manager.StreamingSTTService"):

            mock_client = MagicMock()
            mock_anthropic.return_value = mock_client

            session_manager = SessionManager()
            ai_responder = AIResponder()

            yield session_manager, ai_responder, mock_client

    @pytest.mark.asyncio
    async def test_complete_interaction_with_ai_response(self, mock_services):
        """Test complete flow from speech to AI response."""
        session_manager, ai_responder, mock_client = mock_services

        # Create interactive session
        session = await session_manager.create_session(
            story_id="story-456",
            parent_id="parent-789",
            mode=SessionMode.INTERACTIVE,
        )

        # Complete calibration and activate
        await session_manager.complete_calibration(session.session_id)
        await session_manager.activate_session(session.session_id)

        # Simulate getting transcription
        transcription_text = "小兔子會不會遇到大野狼？"

        # Get AI response
        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="在這個故事裡，小兔子很聰明，牠知道怎麼躲避大野狼喔！"
        )]
        mock_client.messages.create = AsyncMock(return_value=mock_response)

        context = ResponseContext(
            session_id=session.session_id,
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        response = await ai_responder.respond(
            child_text=transcription_text,
            context=context,
        )

        # Verify we got a response
        assert response is not None
        assert response.text is not None

        # End session
        await session_manager.end_session(session.session_id)


class TestEdgeCasesIntegration:
    """Integration tests for edge cases."""

    @pytest.fixture
    def mock_anthropic_client(self):
        """Create a mock Anthropic client."""
        with patch("src.services.interaction.ai_responder.Anthropic") as mock:
            client = MagicMock()
            mock.return_value = client
            yield client

    @pytest.mark.asyncio
    async def test_handles_empty_transcription(self, mock_anthropic_client):
        """Should handle empty transcription gracefully."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="你想說什麼呢？讓我們繼續聽故事吧！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="",
            context=context,
        )

        # Should return a valid response
        assert response is not None

    @pytest.mark.asyncio
    async def test_handles_very_long_input(self, mock_anthropic_client):
        """Should handle very long child input."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        # Very long input
        long_input = "小兔子" * 500

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="讓我們一起來看看小兔子的故事！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text=long_input,
            context=context,
        )

        assert response is not None

    @pytest.mark.asyncio
    async def test_handles_mixed_language_input(self, mock_anthropic_client):
        """Should handle mixed language input."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="Hello! 小兔子也會說你好呢！")]
        mock_anthropic_client.messages.create = AsyncMock(return_value=mock_response)

        response = await ai_responder.respond(
            child_text="Hello 小兔子！How are you?",
            context=context,
        )

        assert response is not None

    @pytest.mark.asyncio
    async def test_handles_api_timeout(self, mock_anthropic_client):
        """Should handle API timeout gracefully."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        # Simulate timeout
        mock_anthropic_client.messages.create = AsyncMock(
            side_effect=asyncio.TimeoutError()
        )

        response = await ai_responder.respond(
            child_text="你好",
            context=context,
        )

        # Should return fallback response
        assert response is not None
        assert response.is_fallback is True

    @pytest.mark.asyncio
    async def test_handles_rate_limiting(self, mock_anthropic_client):
        """Should handle API rate limiting."""
        with patch("src.services.interaction.ai_responder.ContentFilter"):
            ai_responder = AIResponder()

        context = ResponseContext(
            session_id="session-123",
            story_id="story-456",
            story_title="小兔子冒險記",
        )

        # Simulate rate limit error
        mock_anthropic_client.messages.create = AsyncMock(
            side_effect=Exception("Rate limit exceeded")
        )

        response = await ai_responder.respond(
            child_text="你好",
            context=context,
        )

        # Should return fallback response
        assert response is not None
        assert response.is_fallback is True
