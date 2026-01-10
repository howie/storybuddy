from src.models.voice import (
    AgeGroup,
    Gender,
    VoiceCharacter,
    VoiceKit,
    VoiceStyle,
)
from src.models.voice import (
    TTSProvider as TTSProviderEnum,
)
from src.services.tts.azure_tts import AzureTTSProvider


class VoiceKitService:
    """Service for managing voice kits and characters."""

    def __init__(self):
        # Initialize providers
        self.azure_provider = AzureTTSProvider()

        # Load built-in kits
        # MVP: Hardcoded built-in kit
        self._kits = [
            VoiceKit(
                id="builtin-v1",
                name="內建角色",
                description="StoryBuddy 預設的故事角色聲音",
                provider=TTSProviderEnum.AZURE,
                version="1.0.0",
                is_builtin=True,
                is_downloaded=True,
                voices=[
                    VoiceCharacter(
                        id="narrator-female",
                        kit_id="builtin-v1",
                        name="故事姐姐",
                        provider_voice_id="zh-TW-HsiaoChenNeural",
                        gender=Gender.FEMALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                        preview_text="大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！",
                    ),
                    VoiceCharacter(
                        id="child-girl",
                        kit_id="builtin-v1",
                        name="小美",
                        provider_voice_id="zh-TW-HsiaoChenNeural",
                        ssml_options={"role": "Girl", "style": "cheerful"},
                        gender=Gender.FEMALE,
                        age_group=AgeGroup.CHILD,
                        style=VoiceStyle.CHARACTER,
                        preview_text="哈囉！我是小美，我們一起來冒險吧！",
                    ),
                    VoiceCharacter(
                        id="child-boy",
                        kit_id="builtin-v1",
                        name="小强",
                        provider_voice_id="zh-TW-YunJheNeural",
                        ssml_options={"role": "Boy", "style": "cheerful"},
                        gender=Gender.MALE,
                        age_group=AgeGroup.CHILD,
                        style=VoiceStyle.CHARACTER,
                        preview_text="嘿！我是小強，這裡有好多好玩的東西！",
                    ),
                    VoiceCharacter(
                        id="narrator-male",
                        kit_id="builtin-v1",
                        name="故事哥哥",
                        provider_voice_id="zh-TW-YunJheNeural",
                        gender=Gender.MALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                        preview_text="小朋友你好，我是故事哥哥。",
                    ),
                ],
            )
        ]

    async def list_voices(self) -> list[VoiceCharacter]:
        """List all available voices from all kits."""
        all_voices = []
        for kit in self._kits:
            # In future, filter by is_downloaded or compatible
            all_voices.extend(kit.voices)
        return all_voices

    async def get_voice(self, voice_id: str) -> VoiceCharacter | None:
        """Get a specific voice by ID."""
        for kit in self._kits:
            for voice in kit.voices:
                if voice.id == voice_id:
                    return voice
        return None

    async def get_voice_preview(self, voice_id: str, text: str | None = None) -> bytes:
        """Get audio preview for a voice."""
        voice = await self.get_voice(voice_id)
        if not voice:
            raise ValueError(f"Voice not found: {voice_id}")

        preview_text = text or voice.preview_text or "你好，這是聲音預覽。"

        # Route to provider (currently only Azure)
        # We could check voice.kit_id or look up kit provider,
        # but for MVP we assume Azure based on TTSProviderEnum in kit.

        # In a real dynamic system, we'd map kit provider to service instance.
        return await self.azure_provider.synthesize(
            text=preview_text, voice_id=voice.provider_voice_id, options=voice.ssml_options
        )

    async def generate_story_audio(self, story_id: str, voice_id: str) -> bytes:
        """
        Generate audio for a story using a specific voice.

        Args:
            story_id: ID of story to read (would fetch content from DB)
            voice_id: ID of voice to use

        Returns:
            Audio bytes
        """
        # MVP Implementation:
        # 1. Fetch story content (Mocked for now or TODO: Inject StoryService)
        # 2. Call synthesize

        # Since I don't have StoryService injected yet, I will mock fetching story content
        # or just fail if text not provided.
        # But method signature is (story_id, voice_id).

        # I'll implement a placeholder that synthesizes a fixed string or needs extension.
        # For now, let's assume we just verify voice exists.

        voice = await self.get_voice(voice_id)
        if not voice:
            raise ValueError(f"Voice not found: {voice_id}")

        # TODO: Get story content from DB
        story_text = "這是一個測試故事內容。很久很久以前..."

        return await self.azure_provider.synthesize(
            text=story_text, voice_id=voice.provider_voice_id, options=voice.ssml_options
        )
