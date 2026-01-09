import logging
from typing import List, Optional, Dict, Any
from sqlalchemy import select, update
from src.db.init import get_db_connection

from src.models.voice import (
    AgeGroup,
    Gender,
    TTSProvider as TTSProviderEnum,
    VoiceCharacter,
    VoiceKit,
    VoiceStyle,
)
from src.services.tts.azure_tts import AzureTTSProvider
from src.services.tts.google_tts import GoogleTTSProvider
from src.services.tts.elevenlabs_tts import ElevenLabsProvider


class VoiceKitService:
    """Service for managing voice kits and characters."""

    def __init__(self):
        self.logger = logging.getLogger("storybuddy.services.voice")
        # Initialize providers
        self.azure_provider = AzureTTSProvider()
        self.google_provider = GoogleTTSProvider()
        self.elevenlabs_provider = ElevenLabsProvider()

        # Load built-in kits
        # MVP: Hardcoded built-in kits (In-memory storage for now)
        self._kits = [
            # Kit 1: Built-in StoryBuddy Voices
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
            ),
            # Kit 2: Holiday Pack (Mock Downloadable)
            VoiceKit(
                id="holiday-v1",
                name="節日特別版",
                description="聖誕老人與精靈的快樂聲音",
                provider=TTSProviderEnum.AZURE,
                version="1.0.0",
                is_builtin=False,
                is_downloaded=False, # Initially not downloaded
                download_size=15000000, # 15MB mock
                voices=[
                    VoiceCharacter(
                        id="santa",
                        kit_id="holiday-v1",
                        name="聖誕老人",
                        provider_voice_id="zh-TW-YunJheNeural", 
                        # Azure doesn't have explicit Santa, mocking with deep male + style
                        ssml_options={"role": "OlderAdult", "style": "cheerful", "pitch": "-10%"},
                        gender=Gender.MALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.CHARACTER,
                        preview_text="呵呵呵！聖誕快樂！",
                    ),
                    VoiceCharacter(
                        id="elf",
                        kit_id="holiday-v1",
                        name="小精靈",
                        provider_voice_id="zh-TW-HsiaoChenNeural",
                        ssml_options={"role": "Boy", "style": "excited", "pitch": "+10%"},
                        gender=Gender.FEMALE, # Or ambiguous
                        age_group=AgeGroup.CHILD,
                        style=VoiceStyle.CHARACTER,
                        preview_text="禮物都準備好囉！",
                    ),
                ],
            ),
            # Kit 3: Google Basic (Google TTS)
            VoiceKit(
                id="google-basic-v1",
                name="Google 基礎語音",
                description="Google Cloud 提供的標準與 WaveNet 中文語音",
                provider=TTSProviderEnum.GOOGLE,
                version="1.0.0",
                is_builtin=False,
                is_downloaded=True,  # Assume always available if cloud is connected
                download_size=0,
                voices=[
                    VoiceCharacter(
                        id="google-female-a",
                        kit_id="google-basic-v1",
                        name="Google 女聲 A",
                        provider_voice_id="cmn-TW-Wavenet-A",
                        gender=Gender.FEMALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                        preview_text="你好，我是 Google 語音助手。",
                    ),
                    VoiceCharacter(
                        id="google-male-b",
                        kit_id="google-basic-v1",
                        name="Google 男聲 B",
                        provider_voice_id="cmn-TW-Wavenet-B",
                        gender=Gender.MALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                        preview_text="很高興為您服務。",
                    ),
                    VoiceCharacter(
                        id="google-male-c",
                        kit_id="google-basic-v1",
                        name="Google 男聲 C",
                        provider_voice_id="cmn-TW-Wavenet-C",
                        gender=Gender.MALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                    ),
                ],
            ),
            # Kit 4: ElevenLabs Premium (Premium Voices)
            VoiceKit(
                id="elevenlabs-premium-v1",
                name="ElevenLabs 情感聲音",
                description="高品質 AI 情感語音 (需付費)",
                provider=TTSProviderEnum.ELEVENLABS,
                version="1.0.0",
                is_builtin=False,
                is_downloaded=True,  # Cloud
                download_size=0,
                voices=[
                    VoiceCharacter(
                        id="eleven-rachel",
                        kit_id="elevenlabs-premium-v1",
                        name="Rachel (美式女聲)",
                        provider_voice_id="21m00Tcm4TlvDq8ikWAM",
                        gender=Gender.FEMALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                        preview_text="Hey there, I love telling stories.",
                    ),
                    VoiceCharacter(
                        id="eleven-drew",
                        kit_id="elevenlabs-premium-v1",
                        name="Drew (新聞主播)",
                        provider_voice_id="29vD33N1CtxCmqQRPOHJ", 
                        gender=Gender.MALE,
                        age_group=AgeGroup.ADULT,
                        style=VoiceStyle.NARRATOR,
                    ),
                    VoiceCharacter(
                        id="eleven-clyde",
                        kit_id="elevenlabs-premium-v1",
                        name="Clyde (深沉男聲)",
                        provider_voice_id="2EiwWnXFnvU5JabPnv8n",
                        gender=Gender.MALE,
                        age_group=AgeGroup.SENIOR,
                        style=VoiceStyle.CHARACTER,
                    ),
                ],
            )
        ]

    async def list_kits(self) -> List[VoiceKit]:
        """List all available voice kits."""
        return self._kits

    async def list_voices(self) -> List[VoiceCharacter]:
        """List all available voices from DOWNLOADED kits."""
        all_voices = []
        for kit in self._kits:
            if kit.is_downloaded:
                all_voices.extend(kit.voices)
        return all_voices

    async def get_kit(self, kit_id: str) -> Optional[VoiceKit]:
        """Get a specific kit by ID."""
        for kit in self._kits:
            if kit.id == kit_id:
                return kit
        return None

    async def download_kit(self, kit_id: str) -> Optional[VoiceKit]:
        """Simulate downloading a kit."""
        self.logger.info(f"Downloading voice kit: {kit_id}", extra={"kit_id": kit_id})
        
        kit = await self.get_kit(kit_id)
        if not kit:
            self.logger.warning(f"Kit not found for download: {kit_id}")
            return None
            
        # Simulate processing (could verify size, etc)
        # In real app, this would trigger background job.
        kit.is_downloaded = True
        
        self.logger.info(f"Voice kit downloaded successfully: {kit_id}", extra={"kit_id": kit_id})
        return kit

    async def get_voice(self, voice_id: str) -> Optional[VoiceCharacter]:
        """Get a specific voice by ID."""
        # We search ALL kits, but maybe should only allow if downloaded?
        # For now, let's search all to allow "previewing" uninstalled voices via Store?
        # Actually, usually you can preview before download.
        for kit in self._kits:
            for voice in kit.voices:
                if voice.id == voice_id:
                    return voice
        return None

    async def get_voice_preview(self, voice_id: str, text: Optional[str] = None) -> bytes:
        """Get audio preview for a voice."""
        voice = await self.get_voice(voice_id)
        if not voice:
            raise ValueError(f"Voice not found: {voice_id}")

        preview_text = text or voice.preview_text or "你好，這是聲音預覽。"

        # Find kit to determine provider
        kit = next((k for k in self._kits if k.id == voice.kit_id), None)
        if not kit:
             raise ValueError(f"Kit not found for voice: {voice_id}")

        if kit.provider == TTSProviderEnum.GOOGLE:
            provider = self.google_provider
        elif kit.provider == TTSProviderEnum.ELEVENLABS:
             provider = self.elevenlabs_provider
        elif kit.provider == TTSProviderEnum.AZURE:
            provider = self.azure_provider
        else:
             # Default
             provider = self.azure_provider

        return await provider.synthesize(
            text=preview_text,
            voice_id=voice.provider_voice_id,
            options=voice.ssml_options
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
            
        # Verify kit is downloaded for generation?
        # Usually yes.
        # kit = next(k for k in self._kits if k.id == voice.kit_id)
        # if not kit.is_downloaded: raise ValueError("Kit not downloaded")
        
        kit = next((k for k in self._kits if k.id == voice.kit_id), None)
        if not kit:
             raise ValueError(f"Kit not found for voice: {voice_id}")

        if kit.provider == TTSProviderEnum.GOOGLE:
            provider = self.google_provider
        elif kit.provider == TTSProviderEnum.ELEVENLABS:
             provider = self.elevenlabs_provider
        elif kit.provider == TTSProviderEnum.AZURE:
            provider = self.azure_provider
        else:
             provider = self.azure_provider
            
        # TODO: Get story content from DB
        story_text = "這是一個測試故事內容。很久很久以前..."
        
        return await provider.synthesize(
            text=story_text,
            voice_id=voice.provider_voice_id,
            options=voice.ssml_options
        )

    # -- User Preferences --

    async def get_user_preferences(self, user_id: str) -> Dict[str, Any]:
        """Get user voice preferences."""
        async with get_db_connection() as db:
            async with db.execute(
                "SELECT * FROM voice_preferences WHERE user_id = :user_id",
                {"user_id": user_id}
            ) as cursor:
                row = await cursor.fetchone()
                if row:
                    return dict(row)
                return {"user_id": user_id, "default_voice_id": None}

    async def update_default_voice(self, user_id: str, voice_id: str) -> Dict[str, Any]:
        """Update user's default voice."""
        # Verify voice exists
        if not await self.get_voice(voice_id):
            raise ValueError(f"Voice not found: {voice_id}")

        async with get_db_connection() as db:
            # Upsert
            await db.execute(
                """
                INSERT INTO voice_preferences (user_id, default_voice_id)
                VALUES (:user_id, :voice_id)
                ON CONFLICT(user_id) DO UPDATE SET 
                    default_voice_id = :voice_id,
                    updated_at = CURRENT_TIMESTAMP
                """,
                {"user_id": user_id, "voice_id": voice_id}
            )
            await db.commit()
            
        return await self.get_user_preferences(user_id)

    # -- Story Voice Mappings --

    async def get_story_voice_mappings(self, user_id: str, story_id: str) -> List[Dict[str, Any]]:
        """Get all voice mappings for a specific story."""
        async with get_db_connection() as db:
            async with db.execute(
                """
                SELECT * FROM story_voice_maps 
                WHERE user_id = :user_id AND story_id = :story_id
                """,
                {"user_id": user_id, "story_id": story_id}
            ) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def update_story_voice_mapping(
        self, user_id: str, story_id: str, role: str, voice_id: str
    ) -> Dict[str, Any]:
        """Update a voice mapping for a specific story role."""
         # Verify voice exists
        if not await self.get_voice(voice_id):
            raise ValueError(f"Voice not found: {voice_id}")
            
        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO story_voice_maps (story_id, user_id, role, voice_id)
                VALUES (:story_id, :user_id, :role, :voice_id)
                ON CONFLICT(story_id, user_id, role) DO UPDATE SET voice_id = :voice_id
                """,
                {
                    "story_id": story_id,
                    "user_id": user_id,
                    "role": role,
                    "voice_id": voice_id
                }
            )
            await db.commit()
            
        return {
            "story_id": story_id,
            "user_id": user_id,
            "role": role,
            "voice_id": voice_id
        }
