"""Claude LLM service for story generation and Q&A."""

import logging
from dataclasses import dataclass

import anthropic

from src.config import get_settings

logger = logging.getLogger("storybuddy")

# System prompts
STORY_GENERATION_SYSTEM_PROMPT = """You are a creative children's story writer.
Your task is to write engaging, age-appropriate stories for children aged 3-8 years old.

Guidelines:
- Write in Traditional Chinese (繁體中文)
- Keep the story between 300-800 characters
- Use simple, easy-to-understand language
- Include positive themes like friendship, courage, kindness, and curiosity
- Create vivid characters that children can relate to
- Include a clear beginning, middle, and end
- Make the story engaging and fun to listen to

Output format:
Return ONLY a JSON object with two fields:
- "title": The story title (max 50 characters)
- "content": The full story content

Do not include any other text or explanation outside the JSON object."""

QA_SYSTEM_PROMPT = """You are a friendly storytelling assistant helping children understand stories.
A child has just listened to a story and wants to ask questions about it.

Guidelines:
- Answer in Traditional Chinese (繁體中文)
- Use simple, child-friendly language suitable for ages 3-8
- Keep answers concise (50-150 characters)
- Be encouraging and patient
- If the question is about the story, answer based on the story content
- If the question is NOT about the story (out of scope), politely redirect to the story

You must respond with a JSON object containing:
- "answer": Your response to the child
- "is_in_scope": true if the question is about the story, false otherwise

Do not include any other text outside the JSON object."""


@dataclass
class StoryGenerationResult:
    """Result of story generation."""

    title: str
    content: str


@dataclass
class QAResult:
    """Result of Q&A response."""

    answer: str
    is_in_scope: bool


class ClaudeService:
    """Service for interacting with Claude API."""

    def __init__(self) -> None:
        """Initialize Claude client."""
        settings = get_settings()
        self.api_key = settings.anthropic_api_key
        self._client: anthropic.Anthropic | None = None

    @property
    def client(self) -> anthropic.Anthropic:
        """Get or create Anthropic client."""
        if self._client is None:
            if not self.api_key:
                raise ValueError("ANTHROPIC_API_KEY is not configured")
            self._client = anthropic.Anthropic(api_key=self.api_key)
        return self._client

    async def generate_story(self, keywords: list[str]) -> StoryGenerationResult:
        """Generate a children's story based on keywords.

        Args:
            keywords: List of keywords to inspire the story (1-5 keywords)

        Returns:
            StoryGenerationResult with title and content
        """
        keywords_str = "、".join(keywords)
        user_prompt = f"請根據以下關鍵字創作一個兒童故事：{keywords_str}"

        logger.info(f"Generating story with keywords: {keywords}")

        try:
            message = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=2000,
                system=STORY_GENERATION_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_prompt}],
            )

            # Extract response text
            response_text = message.content[0].text
            logger.debug(f"Claude response: {response_text}")

            # Parse JSON response (handle markdown code blocks)
            import json
            import re

            # Remove markdown code blocks if present
            json_text = response_text
            json_match = re.search(r"```(?:json)?\s*(.*?)```", response_text, re.DOTALL)
            if json_match:
                json_text = json_match.group(1).strip()

            try:
                result = json.loads(json_text)
                return StoryGenerationResult(
                    title=result.get("title", f"故事：{keywords_str}"),
                    content=result.get("content", response_text),
                )
            except json.JSONDecodeError:
                # If not valid JSON, use the response as content
                logger.warning("Claude response was not valid JSON, using raw text")
                return StoryGenerationResult(
                    title=f"故事：{keywords_str}",
                    content=response_text,
                )

        except anthropic.APIError as e:
            logger.error(f"Claude API error: {e}")
            raise RuntimeError(f"Failed to generate story: {e}") from e

    async def answer_question(
        self, story_content: str, question: str
    ) -> QAResult:
        """Answer a child's question about a story.

        Args:
            story_content: The full story content
            question: The child's question

        Returns:
            QAResult with answer and is_in_scope flag
        """
        user_prompt = f"""故事內容：
{story_content}

---

小朋友的問題：{question}"""

        logger.info(f"Answering question: {question[:50]}...")

        try:
            message = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                system=QA_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_prompt}],
            )

            response_text = message.content[0].text
            logger.debug(f"Claude Q&A response: {response_text}")

            # Parse JSON response (handle markdown code blocks)
            import json
            import re

            # Remove markdown code blocks if present
            json_text = response_text
            json_match = re.search(r"```(?:json)?\s*(.*?)```", response_text, re.DOTALL)
            if json_match:
                json_text = json_match.group(1).strip()

            try:
                result = json.loads(json_text)
                return QAResult(
                    answer=result.get("answer", response_text),
                    is_in_scope=result.get("is_in_scope", True),
                )
            except json.JSONDecodeError:
                logger.warning("Claude Q&A response was not valid JSON")
                return QAResult(
                    answer=response_text,
                    is_in_scope=True,
                )

        except anthropic.APIError as e:
            logger.error(f"Claude API error in Q&A: {e}")
            raise RuntimeError(f"Failed to answer question: {e}") from e


# Singleton instance
_claude_service: ClaudeService | None = None


def get_claude_service() -> ClaudeService:
    """Get singleton Claude service instance."""
    global _claude_service
    if _claude_service is None:
        _claude_service = ClaudeService()
    return _claude_service
