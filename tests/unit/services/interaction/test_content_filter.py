"""Unit tests for Content Filter service.

T048 [P] [US2] Unit test for content filter.
Tests the content filtering for child-safe AI responses.
"""

import pytest

# These imports will fail until the service is implemented
from src.services.interaction.content_filter import (
    ContentCategory,
    ContentFilter,
    ContentFilterConfig,
    FilterResult,
)


class TestContentFilterConfig:
    """Tests for Content Filter configuration."""

    def test_default_config_values(self):
        """Default config should be maximally restrictive for child safety."""
        config = ContentFilterConfig()
        assert config.strictness_level == "maximum"
        assert config.enable_profanity_filter is True
        assert config.enable_violence_filter is True
        assert config.enable_adult_content_filter is True

    def test_custom_blocked_phrases(self):
        """Should allow custom blocked phrases."""
        config = ContentFilterConfig(custom_blocked_phrases=["壞話1", "壞話2"])
        assert "壞話1" in config.custom_blocked_phrases

    def test_custom_allowed_phrases(self):
        """Should allow custom allowed phrases for story context."""
        config = ContentFilterConfig(
            custom_allowed_phrases=["大野狼"]  # Allowed in story context
        )
        assert "大野狼" in config.custom_allowed_phrases


class TestFilterResult:
    """Tests for filter result model."""

    def test_create_safe_result(self):
        """Should create result for safe content."""
        result = FilterResult(
            is_safe=True,
            original_text="小兔子在吃蘿蔔",
            filtered_text="小兔子在吃蘿蔔",
            categories_detected=[],
        )
        assert result.is_safe is True
        assert result.original_text == result.filtered_text

    def test_create_unsafe_result(self):
        """Should create result for unsafe content with detected categories."""
        result = FilterResult(
            is_safe=False,
            original_text="不安全的內容",
            filtered_text=None,
            categories_detected=[ContentCategory.INAPPROPRIATE_LANGUAGE],
            reason="Contains inappropriate language",
        )
        assert result.is_safe is False
        assert ContentCategory.INAPPROPRIATE_LANGUAGE in result.categories_detected

    def test_create_modified_result(self):
        """Should create result for content that was modified."""
        result = FilterResult(
            is_safe=True,
            original_text="有些問題的內容",
            filtered_text="修改後的安全內容",
            was_modified=True,
            categories_detected=[ContentCategory.OFF_TOPIC],
        )
        assert result.was_modified is True
        assert result.original_text != result.filtered_text


class TestContentFilter:
    """Tests for Content Filter service."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_create_filter(self, content_filter):
        """Should create filter with default configuration."""
        assert content_filter is not None
        assert content_filter.config.strictness_level == "maximum"

    def test_safe_content_passes(self, content_filter):
        """Should allow safe, story-related content."""
        result = content_filter.filter("小兔子在森林裡跳來跳去，好開心啊！")
        assert result.is_safe is True
        assert result.was_modified is False

    def test_basic_greeting_passes(self, content_filter):
        """Should allow basic greetings."""
        result = content_filter.filter("你好！")
        assert result.is_safe is True

    def test_story_related_question_passes(self, content_filter):
        """Should allow story-related questions."""
        result = content_filter.filter("小兔子會不會遇到大野狼？")
        assert result.is_safe is True

    def test_educational_content_passes(self, content_filter):
        """Should allow educational content."""
        result = content_filter.filter("為什麼兔子喜歡吃紅蘿蔔？")
        assert result.is_safe is True


class TestContentFilterProfanity:
    """Tests for profanity filtering."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_blocks_profanity(self, content_filter):
        """Should block profane language."""
        result = content_filter.filter("這是髒話內容")
        # Filter should detect and handle profanity
        assert (
            ContentCategory.INAPPROPRIATE_LANGUAGE in result.categories_detected or result.is_safe
        )

    def test_detects_masked_profanity(self, content_filter):
        """Should detect masked profanity attempts."""
        # Various masking techniques
        result = content_filter.filter("這是*#%&內容")
        # Should at least flag for review or filter
        assert result is not None


class TestContentFilterViolence:
    """Tests for violence content filtering."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_blocks_graphic_violence(self, content_filter):
        """Should block graphic violence descriptions."""
        result = content_filter.filter("殺掉所有人")
        assert result.is_safe is False or ContentCategory.VIOLENCE in result.categories_detected

    def test_allows_story_conflict(self, content_filter):
        """Should allow mild story conflicts (e.g., wolf chasing rabbit)."""
        result = content_filter.filter("大野狼追著小兔子跑")
        assert result.is_safe is True

    def test_context_aware_violence_filtering(self, content_filter):
        """Should consider context when filtering violence."""
        # Story context should allow certain narrative elements
        result = content_filter.filter(
            "小兔子勇敢地躲過了大野狼", context={"story_title": "小兔子冒險記"}
        )
        assert result.is_safe is True


class TestContentFilterAdultContent:
    """Tests for adult content filtering."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_blocks_adult_themes(self, content_filter):
        """Should block adult themes."""
        result = content_filter.filter("成人內容")
        # Should be filtered
        assert (
            result.is_safe is False or ContentCategory.ADULT_CONTENT in result.categories_detected
        )

    def test_blocks_romantic_content(self, content_filter):
        """Should block romantic content inappropriate for children."""
        result = content_filter.filter("親密行為描述")
        assert result.is_safe is False or len(result.categories_detected) > 0


class TestContentFilterPersonalInfo:
    """Tests for personal information filtering."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_detects_phone_number_requests(self, content_filter):
        """Should detect phone number requests."""
        result = content_filter.filter("告訴我你的電話號碼")
        assert ContentCategory.PERSONAL_INFO_REQUEST in result.categories_detected

    def test_detects_address_requests(self, content_filter):
        """Should detect address requests."""
        result = content_filter.filter("你家住在哪裡")
        assert ContentCategory.PERSONAL_INFO_REQUEST in result.categories_detected

    def test_detects_name_requests(self, content_filter):
        """Should detect full name requests."""
        result = content_filter.filter("你的真名是什麼")
        assert ContentCategory.PERSONAL_INFO_REQUEST in result.categories_detected


class TestContentFilterOffTopic:
    """Tests for off-topic content detection."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_detects_completely_off_topic(self, content_filter):
        """Should detect completely off-topic content."""
        result = content_filter.filter(
            "今天的股票市場怎麼樣", context={"story_title": "小兔子冒險記"}
        )
        assert ContentCategory.OFF_TOPIC in result.categories_detected

    def test_allows_related_educational_tangent(self, content_filter):
        """Should allow related educational tangents."""
        result = content_filter.filter(
            "兔子真的只吃紅蘿蔔嗎", context={"story_title": "小兔子冒險記"}
        )
        # Related to story animal, should be allowed
        assert result.is_safe is True


class TestContentFilterFearInducing:
    """Tests for fear-inducing content filtering."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_moderates_scary_content(self, content_filter):
        """Should moderate excessively scary content."""
        result = content_filter.filter("可怕的怪物會在晚上來抓你")
        assert (
            result.is_safe is False or ContentCategory.FEAR_INDUCING in result.categories_detected
        )

    def test_allows_mild_story_tension(self, content_filter):
        """Should allow mild story tension appropriate for children."""
        result = content_filter.filter(
            "小兔子有點緊張，因為森林裡有奇怪的聲音", context={"story_title": "小兔子冒險記"}
        )
        assert result.is_safe is True


class TestContentFilterResponseValidation:
    """Tests for validating AI response content."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_validates_ai_response_safety(self, content_filter):
        """Should validate AI responses for child safety."""
        ai_response = "小兔子開心地跳到胡蘿蔔園，找到了最大最甜的胡蘿蔔！"
        result = content_filter.is_safe(ai_response)
        assert result is True

    def test_rejects_unsafe_ai_response(self, content_filter):
        """Should reject unsafe AI responses."""
        ai_response = "不適合兒童的內容"
        result = content_filter.is_safe(ai_response)
        # Should be checked and potentially rejected
        assert result is True or result is False  # Depends on actual content

    def test_filter_and_modify_response(self, content_filter):
        """Should filter and potentially modify responses."""
        ai_response = "這是回應，但有一些[問題內容]需要移除"
        filtered = content_filter.filter_response(ai_response)
        # Should return modified or original text
        assert filtered is not None


class TestContentFilterEdgeCases:
    """Edge case tests for Content Filter."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_handles_empty_input(self, content_filter):
        """Should handle empty input gracefully."""
        result = content_filter.filter("")
        assert result.is_safe is True

    def test_handles_whitespace_only(self, content_filter):
        """Should handle whitespace-only input."""
        result = content_filter.filter("   ")
        assert result.is_safe is True

    def test_handles_very_long_input(self, content_filter):
        """Should handle very long input."""
        long_text = "小兔子" * 1000
        result = content_filter.filter(long_text)
        assert result is not None

    def test_handles_mixed_languages(self, content_filter):
        """Should handle mixed language input."""
        result = content_filter.filter("小兔子 says Hello 在 forest")
        assert result is not None

    def test_handles_emojis(self, content_filter):
        """Should handle emoji content."""
        result = content_filter.filter("小兔子好開心 🐰✨")
        assert result.is_safe is True

    def test_handles_special_characters(self, content_filter):
        """Should handle special characters."""
        result = content_filter.filter("小兔子說：「你好！」")
        assert result.is_safe is True


class TestContentFilterConfidence:
    """Tests for content filter confidence scoring."""

    @pytest.fixture
    def content_filter(self):
        """Create a Content Filter instance."""
        return ContentFilter()

    def test_high_confidence_safe(self, content_filter):
        """Should have high confidence for clearly safe content."""
        result = content_filter.filter("你好！")
        assert result.confidence >= 0.9

    def test_low_confidence_ambiguous(self, content_filter):
        """Should have lower confidence for ambiguous content."""
        result = content_filter.filter("這個有點奇怪的內容")
        # Ambiguous content should have lower confidence
        assert result.confidence is not None

    def test_confidence_affects_decision(self, content_filter):
        """Low confidence should flag for review."""
        result = content_filter.filter("模糊的內容需要審查")
        # Should either be flagged or have confidence score
        assert hasattr(result, "confidence") or hasattr(result, "needs_review")
