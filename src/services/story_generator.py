"""Story generation service using Claude API.

This service handles:
- AI story generation from keywords
- Child-appropriate content filtering
- Story formatting for TTS
"""

import logging
from typing import Literal

import httpx

from src.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Claude API endpoint
ANTHROPIC_API_BASE = "https://api.anthropic.com/v1"


class StoryGeneratorError(Exception):
    """Exception raised for story generation errors."""

    pass


class GeneratedStory:
    """A generated story from Claude."""

    def __init__(
        self,
        title: str,
        content: str,
        word_count: int,
    ):
        """Initialize a generated story.

        Args:
            title: Story title
            content: Story content
            word_count: Word count
        """
        self.title = title
        self.content = content
        self.word_count = word_count


class StoryGeneratorService:
    """Service for generating stories using Claude."""

    def __init__(self, api_key: str | None = None):
        """Initialize the story generator service.

        Args:
            api_key: Anthropic API key. If not provided, uses settings.
        """
        self.api_key = api_key or settings.anthropic_api_key
        if not self.api_key:
            logger.warning("Anthropic API key not configured")

    def _get_headers(self) -> dict[str, str]:
        """Get HTTP headers for API requests."""
        return {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        }

    def _build_system_prompt(
        self,
        age_group: Literal["3-5", "4-6", "7-10"] = "4-6",
        target_word_count: int = 500,
    ) -> str:
        """Build the system prompt for story generation.

        Args:
            age_group: Target age group
            target_word_count: Target word count for the story

        Returns:
            System prompt string
        """
        age_guidance = {
            "3-5": "使用非常簡單的詞彙，句子要短，重複的元素有助記憶，避免複雜的情節。",
            "4-6": "使用簡單清晰的語言，可以有簡單的冒險情節，加入有趣的對話。",
            "7-10": "可以使用較豐富的詞彙，情節可以更複雜，加入一些道德寓意。",
        }

        return f"""你是一個專業的兒童故事作家，專門為{age_group}歲的小朋友創作故事。

## 你的任務
根據提供的關鍵字，創作一個適合兒童的中文故事。

## 故事要求
1. 故事長度約 {target_word_count} 字（可以有10%的誤差）
2. {age_guidance.get(age_group, age_guidance["4-6"])}
3. 故事必須有清楚的開始、中間和結束
4. 主角要有名字和個性
5. 故事要有正面的訊息（友誼、勇氣、善良等）
6. 避免任何暴力、恐怖、負面的內容
7. 故事要適合用語音朗讀（避免太多插入語）

## 安全規則（絕對不可違反）
- 不可包含任何暴力內容
- 不可包含任何恐怖元素
- 不可包含任何歧視性內容
- 不可包含任何不適合兒童的話題
- 角色之間要和平相處，即使有衝突也要友善解決

## 回應格式
你必須以 JSON 格式回應，包含以下欄位：
- "title": 故事標題（簡短吸引人）
- "content": 故事內容（完整故事文字）

## 注意事項
- 使用繁體中文
- 標點符號要正確
- 故事要連貫流暢
- 適合大聲朗讀"""

    async def generate_story(
        self,
        keywords: list[str],
        age_group: Literal["3-5", "4-6", "7-10"] = "4-6",
        target_word_count: int = 500,
    ) -> GeneratedStory:
        """Generate a story from keywords.

        Args:
            keywords: List of keywords to include in the story
            age_group: Target age group for the story
            target_word_count: Target word count

        Returns:
            GeneratedStory object

        Raises:
            StoryGeneratorError: If generation fails
        """
        if not self.api_key:
            raise StoryGeneratorError("Anthropic API key not configured")

        if not keywords:
            raise StoryGeneratorError("At least one keyword is required")

        keywords_str = "、".join(keywords)
        user_message = f"請用以下關鍵字創作一個故事：{keywords_str}"

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{ANTHROPIC_API_BASE}/messages",
                    headers=self._get_headers(),
                    json={
                        "model": "claude-sonnet-4-20250514",
                        "max_tokens": 2000,
                        "system": self._build_system_prompt(age_group, target_word_count),
                        "messages": [{"role": "user", "content": user_message}],
                    },
                )

                if response.status_code == 200:
                    result = response.json()
                    content = result.get("content", [])

                    if content and len(content) > 0:
                        text = content[0].get("text", "")
                        return self._parse_response(text)
                    else:
                        raise StoryGeneratorError("Empty response from Claude")
                else:
                    error_detail = response.text
                    logger.error(f"Claude API error: {response.status_code} - {error_detail}")
                    raise StoryGeneratorError(f"Story generation failed: {response.status_code}")

        except httpx.RequestError as e:
            logger.error(f"Request error during story generation: {e}")
            raise StoryGeneratorError(f"Network error: {e}") from e

    def _parse_response(self, text: str) -> GeneratedStory:
        """Parse Claude's JSON response.

        Args:
            text: The response text from Claude

        Returns:
            GeneratedStory object

        Raises:
            StoryGeneratorError: If parsing fails
        """
        import json

        try:
            # Try to extract JSON from the response
            json_text = text
            if "```json" in text:
                start = text.find("```json") + 7
                end = text.find("```", start)
                json_text = text[start:end].strip()
            elif "```" in text:
                start = text.find("```") + 3
                end = text.find("```", start)
                json_text = text[start:end].strip()

            data = json.loads(json_text)

            title = data.get("title", "無標題故事")
            content = data.get("content", "")

            if not content:
                raise StoryGeneratorError("Generated story has no content")

            # Calculate word count (for Chinese, count characters)
            word_count = len(content.replace(" ", "").replace("\n", ""))

            return GeneratedStory(
                title=title,
                content=content,
                word_count=word_count,
            )

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Claude response as JSON: {text[:200]}...")
            raise StoryGeneratorError(f"Failed to parse story: {e}") from e

    def validate_content_safety(self, content: str) -> bool:
        """Check if content is safe for children.

        Args:
            content: Story content to check

        Returns:
            True if content is safe
        """
        # List of unsafe keywords to check
        unsafe_keywords = [
            "殺",
            "死亡",
            "血",
            "暴力",
            "恐怖",
            "害怕",
            "噩夢",
            "鬼",
            "妖怪",
            "武器",
            "槍",
            "刀",
            "戰爭",
            "打架",
            "欺負",
            "霸凌",
        ]

        content_lower = content.lower()
        for keyword in unsafe_keywords:
            if keyword in content_lower:
                logger.warning(f"Unsafe keyword found in content: {keyword}")
                return False

        return True


async def generate_story_from_keywords(
    keywords: list[str],
    age_group: Literal["3-5", "4-6", "7-10"] = "4-6",
    target_word_count: int = 500,
    max_retries: int = 3,
) -> GeneratedStory:
    """Generate a story from keywords with safety checks.

    Args:
        keywords: List of keywords to include
        age_group: Target age group
        target_word_count: Target word count
        max_retries: Maximum retry attempts

    Returns:
        GeneratedStory object

    Raises:
        StoryGeneratorError: If generation fails after all retries
    """
    service = StoryGeneratorService()

    for attempt in range(max_retries):
        try:
            story = await service.generate_story(
                keywords=keywords,
                age_group=age_group,
                target_word_count=target_word_count,
            )

            # Validate content safety
            if service.validate_content_safety(story.content):
                return story
            else:
                logger.warning(f"Generated story failed safety check, attempt {attempt + 1}")
                continue

        except StoryGeneratorError as e:
            if attempt == max_retries - 1:
                raise
            logger.warning(f"Story generation attempt {attempt + 1} failed: {e}")
            continue

    raise StoryGeneratorError("Failed to generate safe story after maximum retries")


# Singleton instance
_story_service: StoryGeneratorService | None = None


def get_story_service() -> StoryGeneratorService:
    """Get the story generator service instance."""
    global _story_service
    if _story_service is None:
        _story_service = StoryGeneratorService()
    return _story_service
