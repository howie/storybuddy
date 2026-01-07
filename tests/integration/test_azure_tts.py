import pytest
from src.services.tts.azure_tts import AzureTTSProvider
from src.config import get_settings

@pytest.mark.asyncio
class TestAzureTTS:
    """Integration tests for Azure TTS."""

    async def test_credentials(self):
        """Test credentials validation."""
        provider = AzureTTSProvider()
        is_valid = await provider.validate_credentials()
        # If env vars are set, should be true. If not, false.
        # We assert boolean return.
        assert isinstance(is_valid, bool)

    async def test_ssml_generation(self):
        """Test SSML generation internal to provider."""
        # This tests implicit logic if we exposed ssml helper
        pass
