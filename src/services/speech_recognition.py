"""Speech recognition service using Azure Cognitive Services.

This service handles:
- Speech-to-text conversion for children's Chinese voice input
- Audio file transcription
"""

import logging
from pathlib import Path

import httpx

from src.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class SpeechRecognitionError(Exception):
    """Exception raised for speech recognition errors."""

    pass


class SpeechRecognitionService:
    """Service for speech-to-text using Azure Cognitive Services."""

    def __init__(
        self,
        speech_key: str | None = None,
        speech_region: str | None = None,
    ):
        """Initialize the speech recognition service.

        Args:
            speech_key: Azure Speech API key. If not provided, uses settings.
            speech_region: Azure Speech region. If not provided, uses settings.
        """
        self.speech_key = speech_key or settings.azure_speech_key
        self.speech_region = speech_region or settings.azure_speech_region

        if not self.speech_key:
            logger.warning("Azure Speech API key not configured")

    def _get_endpoint(self) -> str:
        """Get the Azure Speech API endpoint."""
        return f"https://{self.speech_region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1"

    def _get_headers(self, content_type: str = "audio/wav") -> dict[str, str]:
        """Get HTTP headers for API requests."""
        return {
            "Ocp-Apim-Subscription-Key": self.speech_key,
            "Content-Type": content_type,
            "Accept": "application/json",
        }

    async def transcribe_audio(
        self,
        audio_file_path: str | Path,
        language: str = "zh-TW",
    ) -> str:
        """Transcribe an audio file to text.

        Args:
            audio_file_path: Path to the audio file
            language: Language code (default: zh-TW for Mandarin Taiwan)

        Returns:
            Transcribed text

        Raises:
            SpeechRecognitionError: If transcription fails
        """
        if not self.speech_key:
            raise SpeechRecognitionError("Azure Speech API key not configured")

        audio_path = Path(audio_file_path)
        if not audio_path.exists():
            raise SpeechRecognitionError(f"Audio file not found: {audio_file_path}")

        # Determine content type based on file extension
        ext = audio_path.suffix.lower()
        content_type_map = {
            ".wav": "audio/wav",
            ".mp3": "audio/mpeg",
            ".m4a": "audio/mp4",
            ".ogg": "audio/ogg",
        }
        content_type = content_type_map.get(ext, "audio/wav")

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                # Read audio file
                with open(audio_path, "rb") as f:
                    audio_data = f.read()

                # Send request to Azure
                response = await client.post(
                    self._get_endpoint(),
                    params={"language": language},
                    headers=self._get_headers(content_type),
                    content=audio_data,
                )

                if response.status_code == 200:
                    result = response.json()
                    recognition_status = result.get("RecognitionStatus")

                    if recognition_status == "Success":
                        text: str = str(result.get("DisplayText", ""))
                        logger.info(f"Transcription successful: {len(text)} chars")
                        return text
                    elif recognition_status == "NoMatch":
                        logger.warning("No speech recognized in audio")
                        raise SpeechRecognitionError("無法識別語音，請再說一次。")
                    elif recognition_status == "InitialSilenceTimeout":
                        raise SpeechRecognitionError("沒有偵測到說話聲，請再試一次。")
                    else:
                        raise SpeechRecognitionError(f"語音識別失敗: {recognition_status}")
                else:
                    error_detail = response.text
                    logger.error(f"Azure Speech API error: {response.status_code} - {error_detail}")
                    raise SpeechRecognitionError(f"語音服務錯誤: {response.status_code}")

        except httpx.RequestError as e:
            logger.error(f"Request error during transcription: {e}")
            raise SpeechRecognitionError(f"網路錯誤: {e}") from e

    async def transcribe_audio_bytes(
        self,
        audio_data: bytes,
        content_type: str = "audio/wav",
        language: str = "zh-TW",
    ) -> str:
        """Transcribe audio bytes to text.

        Args:
            audio_data: Audio data as bytes
            content_type: MIME type of the audio
            language: Language code (default: zh-TW for Mandarin Taiwan)

        Returns:
            Transcribed text

        Raises:
            SpeechRecognitionError: If transcription fails
        """
        if not self.speech_key:
            raise SpeechRecognitionError("Azure Speech API key not configured")

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self._get_endpoint(),
                    params={"language": language},
                    headers=self._get_headers(content_type),
                    content=audio_data,
                )

                if response.status_code == 200:
                    result = response.json()
                    recognition_status = result.get("RecognitionStatus")

                    if recognition_status == "Success":
                        text: str = str(result.get("DisplayText", ""))
                        logger.info(f"Transcription successful: {len(text)} chars")
                        return text
                    elif recognition_status == "NoMatch":
                        logger.warning("No speech recognized in audio")
                        raise SpeechRecognitionError("無法識別語音，請再說一次。")
                    elif recognition_status == "InitialSilenceTimeout":
                        raise SpeechRecognitionError("沒有偵測到說話聲，請再試一次。")
                    else:
                        raise SpeechRecognitionError(f"語音識別失敗: {recognition_status}")
                else:
                    error_detail = response.text
                    logger.error(f"Azure Speech API error: {response.status_code} - {error_detail}")
                    raise SpeechRecognitionError(f"語音服務錯誤: {response.status_code}")

        except httpx.RequestError as e:
            logger.error(f"Request error during transcription: {e}")
            raise SpeechRecognitionError(f"網路錯誤: {e}") from e


# Singleton instance
_speech_service: SpeechRecognitionService | None = None


def get_speech_service() -> SpeechRecognitionService:
    """Get the speech recognition service instance."""
    global _speech_service
    if _speech_service is None:
        _speech_service = SpeechRecognitionService()
    return _speech_service
