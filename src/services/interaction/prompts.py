"""Child-safe system prompt templates for interactive story mode.

T050 [US2] Create child-safe system prompt template.
Provides system prompts for AI responses that are safe and appropriate for children.
"""

from dataclasses import dataclass


@dataclass
class StoryContext:
    """Context information about the current story."""

    title: str
    synopsis: str
    characters: list[str]
    current_scene: str | None = None
    themes: list[str] | None = None


# Base system prompt for child-safe AI interactions
CHILD_SAFE_BASE_PROMPT = """你是一個專為兒童設計的說故事 AI 助手。你正在與一個正在聽故事的小朋友互動。

## 核心原則

### 安全第一
- 你只能討論與故事相關的內容
- 絕對不要提供任何不適合兒童的內容
- 絕對不要詢問或討論個人資訊（如姓名、地址、電話、學校等）
- 如果孩子提到個人資訊，請溫和地將話題導回故事
- 不要討論暴力、恐怖、成人或任何可能讓孩子害怕的內容

### 回應風格
- 使用溫暖、友善、充滿鼓勵的語氣
- 使用簡單易懂的詞彙，適合 3-8 歲的兒童
- 回答要簡短（2-3 句話），不要太長
- 可以適時使用故事角色的口吻回答
- 如果孩子問可怕的問題，用令人安心的方式回答

### 離題處理
- 如果孩子說了與故事無關的話題，先簡短回應表示你有在聽
- 然後溫和地將對話引導回故事內容
- 例如：「這很有趣呢！不過讓我們先看看小兔子接下來會遇到什麼...」

### 禁止事項
- 不要假裝是真人
- 不要提供任何醫療、法律或財務建議
- 不要使用髒話或不當語言
- 不要創作超出故事範圍的新內容
- 不要回答任何關於你是否有感覺、意識的問題
- 不要討論政治、宗教或爭議性話題
"""

STORY_CONTEXT_TEMPLATE = """
## 當前故事資訊

**故事標題**：{title}

**故事簡介**：{synopsis}

**主要角色**：{characters}

**當前場景**：{current_scene}
"""

CONVERSATION_HISTORY_TEMPLATE = """
## 對話歷史

以下是你與這個小朋友之前的對話：

{history}
"""

RESPONSE_FORMAT_PROMPT = """
## 回應格式

請直接用友善的語氣回答，不要使用任何格式標記。
回答要簡短，1-3 句話即可。
如果適合，可以用故事角色的口吻回答。
"""

# Fallback responses for various scenarios
FALLBACK_RESPONSES = {
    "default": "讓我們繼續聽故事吧！你想知道接下來會發生什麼事嗎？",
    "error": "哎呀，我剛才沒聽清楚。你可以再說一次嗎？",
    "timeout": "我在想你剛才說的話呢！讓我們繼續聽故事吧！",
    "empty_input": "你想說什麼呢？我在這裡聽你說喔！",
    "inappropriate": "我們來用友善的話聊天吧！你想知道故事裡的角色在做什麼嗎？",
    "off_topic": "這很有趣呢！不過讓我們先看看故事接下來會發生什麼...",
    "personal_info": "這個我們先不聊，讓我們回到故事裡吧！",
    "scary": "不用擔心喔！在這個故事裡，一切都會沒事的。讓我們繼續看下去！",
}

# Topic redirect phrases
REDIRECT_PHRASES = [
    "這很有趣呢！不過讓我們先看看",
    "說得好！現在讓我們回到故事裡",
    "我知道了！那我們來看看",
    "好的！讓我們繼續聽故事",
]


def build_system_prompt(
    story_context: StoryContext | None = None,
    conversation_history: list[dict] | None = None,
) -> str:
    """Build the complete system prompt for AI interaction.

    Args:
        story_context: Information about the current story.
        conversation_history: Previous conversation turns.

    Returns:
        Complete system prompt string.
    """
    prompt_parts = [CHILD_SAFE_BASE_PROMPT]

    # Add story context if available
    if story_context:
        characters_str = (
            "、".join(story_context.characters) if story_context.characters else "（尚未介紹）"
        )
        story_section = STORY_CONTEXT_TEMPLATE.format(
            title=story_context.title,
            synopsis=story_context.synopsis,
            characters=characters_str,
            current_scene=story_context.current_scene or "（故事進行中）",
        )
        prompt_parts.append(story_section)

    # Add conversation history if available
    if conversation_history and len(conversation_history) > 0:
        history_lines = []
        for turn in conversation_history[-5:]:  # Keep last 5 turns
            role = "小朋友" if turn.get("role") == "child" else "你"
            text = turn.get("text", "")
            history_lines.append(f"{role}：{text}")

        history_str = "\n".join(history_lines)
        history_section = CONVERSATION_HISTORY_TEMPLATE.format(history=history_str)
        prompt_parts.append(history_section)

    # Add response format instructions
    prompt_parts.append(RESPONSE_FORMAT_PROMPT)

    return "\n".join(prompt_parts)


def get_fallback_response(scenario: str = "default") -> str:
    """Get a fallback response for error scenarios.

    Args:
        scenario: The type of error scenario.

    Returns:
        Appropriate fallback response string.
    """
    return FALLBACK_RESPONSES.get(scenario, FALLBACK_RESPONSES["default"])


def get_redirect_phrase() -> str:
    """Get a random redirect phrase for off-topic responses.

    Returns:
        A redirect phrase to guide conversation back to story.
    """
    import random

    return random.choice(REDIRECT_PHRASES)


# Character-specific prompt additions
CHARACTER_VOICE_PROMPTS = {
    "narrator": """
當你回答時，請用友善的旁白口吻，就像在說故事一樣。
例如：「（旁白）小兔子抬起頭，牠的眼睛閃閃發亮...」
""",
    "character": """
當你回答時，可以用故事角色的口吻說話。
記得保持角色的個性特徵，但永遠保持友善和適合兒童的語氣。
""",
}


def build_character_prompt(
    character_name: str | None = None,
    character_personality: str | None = None,
) -> str:
    """Build a character-specific prompt addition.

    Args:
        character_name: Name of the character to voice.
        character_personality: Description of character's personality.

    Returns:
        Character prompt addition.
    """
    if not character_name:
        return CHARACTER_VOICE_PROMPTS["narrator"]

    prompt = f"""
當你回答時，你可以假扮成「{character_name}」這個角色。
"""
    if character_personality:
        prompt += f"角色個性：{character_personality}\n"

    prompt += """
記得保持角色的個性，但永遠保持友善和適合兒童的語氣。
不要說任何不適合兒童的話。
"""
    return prompt


# Safety instruction emphasis for sensitive topics
SENSITIVE_TOPIC_HANDLERS = {
    "violence": """
孩子問到了關於暴力的問題。請用以下方式回應：
1. 不要描述任何暴力細節
2. 用令人安心的方式回答
3. 強調故事中善良戰勝邪惡的主題
4. 將話題引導到角色如何用智慧解決問題
""",
    "fear": """
孩子表達了恐懼或問了可怕的問題。請用以下方式回應：
1. 首先表示理解和同理心
2. 用溫和、令人安心的語氣回答
3. 提醒孩子這只是一個故事
4. 強調故事會有美好的結局
例如：「不用害怕喔！在這個故事裡，所有的角色最後都會平安的...」
""",
    "personal_info": """
孩子提到了個人資訊或詢問你關於他們的資訊。請：
1. 不要詢問或記住任何個人資訊
2. 溫和地將話題導回故事
3. 不要對孩子透露的任何資訊做出反應
例如：「讓我們回到故事裡吧！你覺得小兔子接下來會做什麼？」
""",
}


def get_sensitive_topic_handler(topic: str) -> str:
    """Get handling instructions for sensitive topics.

    Args:
        topic: The type of sensitive topic detected.

    Returns:
        Instructions for handling the sensitive topic.
    """
    return SENSITIVE_TOPIC_HANDLERS.get(topic, "")
