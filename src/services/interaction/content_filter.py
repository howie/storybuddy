"""Content Filter service for child-safe responses.

T052 [US2] Implement content filter for response validation.
Filters and validates content to ensure it's appropriate for children.
"""

import re
import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List, Dict, Any, Set

logger = logging.getLogger(__name__)


class ContentCategory(Enum):
    """Categories of content that may be filtered."""

    INAPPROPRIATE_LANGUAGE = "inappropriate_language"
    VIOLENCE = "violence"
    ADULT_CONTENT = "adult_content"
    FEAR_INDUCING = "fear_inducing"
    PERSONAL_INFO_REQUEST = "personal_info_request"
    OFF_TOPIC = "off_topic"
    UNSAFE_ACTIVITY = "unsafe_activity"


@dataclass
class ContentFilterConfig:
    """Configuration for content filter."""

    strictness_level: str = "maximum"
    enable_profanity_filter: bool = True
    enable_violence_filter: bool = True
    enable_adult_content_filter: bool = True
    enable_personal_info_filter: bool = True
    custom_blocked_phrases: List[str] = field(default_factory=list)
    custom_allowed_phrases: List[str] = field(default_factory=list)


@dataclass
class FilterResult:
    """Result of content filtering."""

    is_safe: bool
    original_text: str
    filtered_text: Optional[str]
    categories_detected: List[ContentCategory] = field(default_factory=list)
    was_modified: bool = False
    reason: Optional[str] = None
    confidence: float = 1.0
    needs_review: bool = False

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "isSafe": self.is_safe,
            "originalText": self.original_text,
            "filteredText": self.filtered_text,
            "categoriesDetected": [c.value for c in self.categories_detected],
            "wasModified": self.was_modified,
            "reason": self.reason,
            "confidence": self.confidence,
        }


class ContentFilter:
    """Content filter for validating child-safe content.

    Checks text content for inappropriate material and validates
    that AI responses are safe for children.
    """

    def __init__(self, config: Optional[ContentFilterConfig] = None):
        """Initialize content filter.

        Args:
            config: Filter configuration.
        """
        self.config = config or ContentFilterConfig()
        self._init_patterns()

    def _init_patterns(self) -> None:
        """Initialize detection patterns."""
        # Personal info request patterns
        self._personal_info_patterns = [
            r"(你的?|妳的?)(真)?名(字)?是",
            r"你(住|家)在哪",
            r"你家住在哪",
            r"你的?(電話|手機|地址|學校|年紀|年齡)",
            r"告訴我(你的?|妳的?)(電話|地址|學校|名字)",
            r"(your|tell me your)\s*(name|phone|address|school|age)",
            r"where\s*(do\s*)?you\s*live",
        ]

        # Violence patterns (severe)
        self._violence_patterns = [
            r"(殺|砍|打死|殺死|殺掉|弄死|殺害)",
            r"(血|死|屍體|死亡|流血|暴力)",
            r"(kill|murder|blood|death|die|violent)",
        ]

        # Fear-inducing patterns
        self._fear_patterns = [
            r"(會來抓你|會抓你|把你抓走)",
            r"(可怕的?怪物|恐怖的?)",
            r"(晚上.*來.*抓|睡覺.*會)",
            r"(monster.*get you|come for you at night)",
        ]

        # Adult content patterns
        self._adult_content_patterns = [
            r"(成人|限制級|十八禁|18禁|R18)",
            r"(色情|情色|裸體|性愛|做愛)",
            r"(親密行為|親吻|接吻|擁抱).*描述",
            r"(adult\s*content|explicit|pornograph|nude|sex)",
        ]

        # Off-topic keywords (used with context)
        self._off_topic_keywords = {
            "股票", "投資", "政治", "選舉", "新聞",
            "工作", "公司", "老闆", "薪水",
            "stocks", "politics", "election", "news",
        }

        # Common story-related words (should be allowed)
        self._story_keywords = {
            "故事", "角色", "主角", "冒險", "魔法", "森林",
            "動物", "朋友", "家人", "英雄", "公主", "王子",
            "story", "character", "adventure", "magic", "forest",
            "animal", "friend", "hero", "princess", "prince",
        }

    def filter(
        self,
        text: str,
        context: Optional[Dict[str, Any]] = None,
    ) -> FilterResult:
        """Filter and analyze text content.

        Args:
            text: Text to filter.
            context: Optional context (e.g., story_title).

        Returns:
            Filter result with analysis.
        """
        if not text or not text.strip():
            return FilterResult(
                is_safe=True,
                original_text=text,
                filtered_text=text,
                confidence=1.0,
            )

        text_lower = text.lower()
        categories_detected = []
        confidence = 1.0

        # Check for personal info requests
        if self._check_personal_info(text_lower):
            categories_detected.append(ContentCategory.PERSONAL_INFO_REQUEST)
            confidence = min(confidence, 0.95)

        # Check for violence
        if self._check_violence(text_lower):
            categories_detected.append(ContentCategory.VIOLENCE)
            confidence = min(confidence, 0.8)

        # Check for fear-inducing content
        if self._check_fear_inducing(text_lower):
            categories_detected.append(ContentCategory.FEAR_INDUCING)
            confidence = min(confidence, 0.85)

        # Check for adult content
        if self._check_adult_content(text_lower):
            categories_detected.append(ContentCategory.ADULT_CONTENT)
            confidence = min(confidence, 0.7)

        # Check for off-topic content
        if context and self._check_off_topic(text_lower, context):
            categories_detected.append(ContentCategory.OFF_TOPIC)
            confidence = min(confidence, 0.9)

        # Check for inappropriate language
        if self._check_inappropriate_language(text_lower):
            categories_detected.append(ContentCategory.INAPPROPRIATE_LANGUAGE)
            confidence = min(confidence, 0.75)

        # Determine safety
        severe_categories = {
            ContentCategory.VIOLENCE,
            ContentCategory.ADULT_CONTENT,
            ContentCategory.INAPPROPRIATE_LANGUAGE,
        }

        is_safe = not any(cat in severe_categories for cat in categories_detected)

        # Allow story-related content even with some flags
        if context:
            story_title = context.get("story_title", "")
            if self._is_story_related(text_lower, story_title):
                # Less strict for story-related content
                is_safe = True
                confidence = max(confidence, 0.85)

        return FilterResult(
            is_safe=is_safe,
            original_text=text,
            filtered_text=text if is_safe else None,
            categories_detected=categories_detected,
            confidence=confidence,
            needs_review=len(categories_detected) > 0 and is_safe,
        )

    def is_safe(self, text: str, context: Optional[Dict[str, Any]] = None) -> bool:
        """Quick check if text is safe.

        Args:
            text: Text to check.
            context: Optional context.

        Returns:
            True if safe, False otherwise.
        """
        result = self.filter(text, context)
        return result.is_safe

    def filter_response(self, text: str) -> str:
        """Filter and potentially modify a response.

        Args:
            text: Response text to filter.

        Returns:
            Filtered text (may be modified).
        """
        result = self.filter(text)
        if result.is_safe:
            return text
        return result.filtered_text or text

    def contains_inappropriate_content(
        self,
        text: str,
        context: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Check if text contains inappropriate content.

        Args:
            text: Text to check.
            context: Optional context.

        Returns:
            True if inappropriate content detected.
        """
        result = self.filter(text, context)
        return ContentCategory.INAPPROPRIATE_LANGUAGE in result.categories_detected

    def _check_personal_info(self, text: str) -> bool:
        """Check for personal information requests."""
        for pattern in self._personal_info_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False

    def _check_violence(self, text: str) -> bool:
        """Check for violent content."""
        for pattern in self._violence_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                # Check if it's in story context
                # "大野狼追著小兔子" is OK
                # "殺掉所有人" is not OK
                match = re.search(pattern, text)
                if match:
                    # Check surrounding context
                    start = max(0, match.start() - 20)
                    end = min(len(text), match.end() + 20)
                    context = text[start:end].lower()

                    # Allow mild story violence
                    if any(word in context for word in ["故事", "小", "追", "跑"]):
                        continue
                    return True
        return False

    def _check_fear_inducing(self, text: str) -> bool:
        """Check for fear-inducing content."""
        for pattern in self._fear_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False

    def _check_adult_content(self, text: str) -> bool:
        """Check for adult content."""
        for pattern in self._adult_content_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False

    def _check_off_topic(self, text: str, context: Dict[str, Any]) -> bool:
        """Check if content is off-topic for the story."""
        story_title = context.get("story_title", "").lower()

        # Check for off-topic keywords
        off_topic_count = sum(1 for kw in self._off_topic_keywords if kw in text)
        story_related_count = sum(1 for kw in self._story_keywords if kw in text)

        # If more off-topic than story-related, flag it
        if off_topic_count > 0 and story_related_count == 0:
            return True

        return False

    def _check_inappropriate_language(self, text: str) -> bool:
        """Check for inappropriate language."""
        # Basic profanity check
        # In production, this would use a comprehensive word list
        # or a machine learning model

        # Check custom blocked phrases
        for phrase in self.config.custom_blocked_phrases:
            if phrase.lower() in text:
                return True

        return False

    def _is_story_related(self, text: str, story_title: str) -> bool:
        """Check if content is related to the story."""
        # Check if story title words appear
        story_words = set(story_title.lower().split())
        text_words = set(text.lower().split())

        if story_words & text_words:
            return True

        # Check for story keywords
        if any(kw in text for kw in self._story_keywords):
            return True

        return False
