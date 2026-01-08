"""Q&A handler service using Claude API.

This service handles:
- Story-based Q&A with children using Claude
- Out-of-scope question detection
- Child-friendly response generation
"""

import logging

import httpx

from src.config import get_settings
from src.models.story import Story

logger = logging.getLogger(__name__)
settings = get_settings()

# Claude API endpoint
ANTHROPIC_API_BASE = "https://api.anthropic.com/v1"


class QAHandlerError(Exception):
    """Exception raised for Q&A handler errors."""

    pass


class QAResponse:
    """Response from the Q&A handler."""

    def __init__(
        self,
        answer: str,
        is_in_scope: bool,
        should_save_question: bool = False,
    ):
        """Initialize a Q&A response.

        Args:
            answer: The answer text
            is_in_scope: Whether the question was within story scope
            should_save_question: Whether to save as pending question for parent
        """
        self.answer = answer
        self.is_in_scope = is_in_scope
        self.should_save_question = should_save_question


class QAHandlerService:
    """Service for handling Q&A using Claude."""

    def __init__(self, api_key: str | None = None):
        """Initialize the Q&A handler service.

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

    def _build_system_prompt(self, story: Story) -> str:
        """Build the system prompt for Q&A.

        Args:
            story: The story context

        Returns:
            System prompt string
        """
        return f"""你是一個友善的說故事助手，正在和3-10歲的小朋友互動。

你剛剛講完了一個故事，現在小朋友可能會問你問題。

## 故事標題
{story.title}

## 故事內容
{story.content}

## 你的任務
1. 回答小朋友關於故事的問題
2. 使用簡單、友善、適合兒童的語言
3. 回答要簡短（2-4句話）
4. 判斷問題是否在故事範圍內

## 判斷規則
- 如果問題是關於故事中的角色、情節、場景、結局等，這是「故事範圍內」的問題
- 如果問題是關於故事之外的事（例如：為什麼天空是藍色的、恐龍是什麼等），這是「故事範圍外」的問題

## 回應格式
你必須以 JSON 格式回應，包含以下欄位：
- "answer": 你的回答文字
- "is_in_scope": true 如果問題在故事範圍內，false 如果超出範圍
- "save_for_parent": true 如果這個問題應該記錄給家長回答，false 則否

對於範圍外的問題，回答類似：「這是個好問題！這個問題不在故事裡面喔，我們先記錄起來，等一下問爸爸媽媽好不好？」

## 重要提醒
- 永遠保持友善和鼓勵的態度
- 不要說任何不適合兒童的內容
- 如果問題含糊不清，可以溫和地請小朋友再說一次"""

    async def answer_question(
        self,
        question: str,
        story: Story,
        conversation_history: list[dict[str, str]] | None = None,
    ) -> QAResponse:
        """Answer a question about a story.

        Args:
            question: The child's question
            story: The story context
            conversation_history: Previous messages in the conversation

        Returns:
            QAResponse with answer and scope information

        Raises:
            QAHandlerError: If the API call fails
        """
        if not self.api_key:
            # Return a fallback response when API is not configured
            return self._get_fallback_response(question)

        messages = []

        # Add conversation history if provided
        if conversation_history:
            for msg in conversation_history:
                messages.append(msg)

        # Add the current question
        messages.append({"role": "user", "content": question})

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{ANTHROPIC_API_BASE}/messages",
                    headers=self._get_headers(),
                    json={
                        "model": "claude-sonnet-4-20250514",
                        "max_tokens": 500,
                        "system": self._build_system_prompt(story),
                        "messages": messages,
                    },
                )

                if response.status_code == 200:
                    result = response.json()
                    content = result.get("content", [])

                    if content and len(content) > 0:
                        text = content[0].get("text", "")
                        return self._parse_response(text)
                    else:
                        return self._get_fallback_response(question)
                else:
                    error_detail = response.text
                    logger.error(f"Claude API error: {response.status_code} - {error_detail}")
                    return self._get_fallback_response(question)

        except httpx.RequestError as e:
            logger.error(f"Request error during Q&A: {e}")
            return self._get_fallback_response(question)

    def _parse_response(self, text: str) -> QAResponse:
        """Parse Claude's JSON response.

        Args:
            text: The response text from Claude

        Returns:
            QAResponse object
        """
        import json

        try:
            # Try to extract JSON from the response
            # Claude might wrap it in markdown code blocks
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

            return QAResponse(
                answer=data.get("answer", text),
                is_in_scope=data.get("is_in_scope", True),
                should_save_question=data.get("save_for_parent", False),
            )

        except json.JSONDecodeError:
            # If JSON parsing fails, use the text as-is
            logger.warning(f"Failed to parse Claude response as JSON: {text[:100]}...")
            return QAResponse(
                answer=text,
                is_in_scope=True,
                should_save_question=False,
            )

    def _get_fallback_response(self, question: str) -> QAResponse:
        """Generate a fallback response when API is unavailable.

        Args:
            question: The original question

        Returns:
            A simple fallback QAResponse
        """
        question_lower = question.lower()

        # Check if it's likely an out-of-scope question
        out_of_scope_keywords = [
            "為什麼天空",
            "恐龍",
            "太空",
            "地球",
            "科學",
            "數學",
            "學校",
            "爸爸媽媽",
            "真的嗎",
            "現實",
        ]

        is_out_of_scope = any(kw in question_lower for kw in out_of_scope_keywords)

        if is_out_of_scope:
            return QAResponse(
                answer="這是個好問題！這個問題不在故事裡面喔，我們先記錄起來，等一下問爸爸媽媽好不好？",
                is_in_scope=False,
                should_save_question=True,
            )

        # Simple in-scope fallback
        if "誰" in question_lower or "who" in question_lower:
            return QAResponse(
                answer="故事裡面有很多有趣的角色喔！他們都是好朋友，一起經歷了精彩的冒險。",
                is_in_scope=True,
                should_save_question=False,
            )
        elif "什麼" in question_lower or "what" in question_lower:
            return QAResponse(
                answer="這是故事裡面發生的精彩事情喔！角色們一起解決了問題。",
                is_in_scope=True,
                should_save_question=False,
            )
        elif "為什麼" in question_lower or "why" in question_lower:
            return QAResponse(
                answer="這是個好問題！故事裡的角色做這些事情是因為他們想幫助朋友、完成冒險。",
                is_in_scope=True,
                should_save_question=False,
            )
        elif "怎麼" in question_lower or "how" in question_lower:
            return QAResponse(
                answer="故事裡的角色們互相幫助，一起想辦法解決問題，這就是團隊合作的力量！",
                is_in_scope=True,
                should_save_question=False,
            )
        elif "哪裡" in question_lower or "where" in question_lower:
            return QAResponse(
                answer="故事發生在一個神奇的地方，那裡有很多有趣的東西等著我們去發現！",
                is_in_scope=True,
                should_save_question=False,
            )
        else:
            return QAResponse(
                answer="這是個很棒的問題！故事告訴我們友誼和勇氣是很重要的。",
                is_in_scope=True,
                should_save_question=False,
            )

    async def check_question_scope(
        self,
        question: str,
        story: Story,
    ) -> bool:
        """Check if a question is within the story's scope.

        Args:
            question: The question to check
            story: The story context

        Returns:
            True if in scope, False otherwise
        """
        response = await self.answer_question(question, story)
        return response.is_in_scope


# Singleton instance
_qa_service: QAHandlerService | None = None


def get_qa_service() -> QAHandlerService:
    """Get the Q&A handler service instance."""
    global _qa_service
    if _qa_service is None:
        _qa_service = QAHandlerService()
    return _qa_service
