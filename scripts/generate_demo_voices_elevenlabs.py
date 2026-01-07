#!/usr/bin/env python3
"""
Generate demo voice samples using ElevenLabs API.

Usage:
    1. Get your API key from https://elevenlabs.io/
    2. Set environment variable:
       export ELEVENLABS_API_KEY="your-key-here"

    3. Install dependency:
       pip install elevenlabs

    4. Run:
       python scripts/generate_demo_voices_elevenlabs.py

Output:
    Creates demo audio files in data/voice_previews/
"""

import os
import sys
from pathlib import Path

try:
    from elevenlabs import ElevenLabs, VoiceSettings
except ImportError:
    print("Error: elevenlabs package not installed")
    print("Run: pip install elevenlabs")
    sys.exit(1)


# ElevenLabs voice configurations
# Using voices that work well for Traditional Chinese
VOICE_CHARACTERS = [
    {
        "id": "narrator-female",
        "name": "故事姐姐",
        "voice_id": "EXAVITQu4vr4xnSDxMaL",  # Bella - warm female
        "preview_text": "大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！",
        "stability": 0.5,
        "similarity_boost": 0.75,
    },
    {
        "id": "narrator-male",
        "name": "故事哥哥",
        "voice_id": "pNInz6obpgDQGcFmaJgB",  # Adam - friendly male
        "preview_text": "嗨！我是故事哥哥，準備好聽故事了嗎？",
        "stability": 0.5,
        "similarity_boost": 0.75,
    },
    {
        "id": "child-girl",
        "name": "小美",
        "voice_id": "jBpfuIE2acCO8z3wKNLl",  # Gigi - young energetic
        "preview_text": "哈囉！我是小美，我們一起來冒險吧！",
        "stability": 0.3,  # More expressive for child
        "similarity_boost": 0.8,
    },
    {
        "id": "child-boy",
        "name": "小明",
        "voice_id": "onwK4e9ZLuTAKqWW03F9",  # Daniel - young male
        "preview_text": "嘿！我是小明，今天會發生什麼有趣的事呢？",
        "stability": 0.3,
        "similarity_boost": 0.8,
    },
    {
        "id": "elder-female",
        "name": "故事阿嬤",
        "voice_id": "ThT5KcBeYPX3keUQqHPh",  # Dorothy - warm older female
        "preview_text": "乖孫，阿嬤來講古早的故事給你聽...",
        "stability": 0.7,  # More stable for elder
        "similarity_boost": 0.6,
    },
    {
        "id": "elder-male",
        "name": "故事阿公",
        "voice_id": "VR6AewLTigWG4xSOukaG",  # Arnold - mature male
        "preview_text": "來，阿公說一個很久很久以前的故事...",
        "stability": 0.7,
        "similarity_boost": 0.6,
    },
]

# Sample story
SAMPLE_STORY = """
從前從前，在一座美麗的森林裡，住著一隻勇敢的小兔子。
小兔子每天都會在森林裡探險，尋找美味的紅蘿蔔。
有一天，小兔子發現了一條從未走過的小路...
"""


def get_client():
    """Create ElevenLabs client from environment variable."""
    api_key = os.getenv("ELEVENLABS_API_KEY")

    if not api_key:
        print("Error: ELEVENLABS_API_KEY environment variable not set")
        print("\nTo get an ElevenLabs API key:")
        print("1. Go to https://elevenlabs.io/")
        print("2. Sign up for a free account")
        print("3. Go to Profile Settings -> API Keys")
        print("4. Copy your API key")
        print("\nThen run:")
        print('  export ELEVENLABS_API_KEY="your-key-here"')
        sys.exit(1)

    return ElevenLabs(api_key=api_key)


def list_available_voices(client):
    """List all available voices for reference."""
    print("\nAvailable voices in your account:")
    print("-" * 50)

    response = client.voices.get_all()
    for voice in response.voices:
        print(f"  {voice.voice_id}: {voice.name}")
    print()


def synthesize_to_file(client, text: str, voice_id: str, output_path: Path,
                       stability: float = 0.5, similarity_boost: float = 0.75) -> bool:
    """Synthesize speech and save to file."""
    try:
        audio = client.text_to_speech.convert(
            voice_id=voice_id,
            text=text,
            model_id="eleven_multilingual_v2",  # Best for non-English
            voice_settings=VoiceSettings(
                stability=stability,
                similarity_boost=similarity_boost,
                style=0.0,
                use_speaker_boost=True,
            ),
        )

        # Write audio to file
        with open(output_path, "wb") as f:
            for chunk in audio:
                f.write(chunk)

        return True

    except Exception as e:
        print(f"  Error: {e}")
        return False


def main():
    print("=" * 60)
    print("StoryBuddy Voice Kit - ElevenLabs Demo Generator")
    print("=" * 60)
    print()

    # Setup
    client = get_client()

    # Optionally list available voices
    # list_available_voices(client)

    # Create output directory
    output_dir = Path("data/voice_previews")
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Output directory: {output_dir.absolute()}")
    print()

    # Generate preview for each character
    print("Generating voice previews...")
    print("-" * 40)

    success_count = 0
    for char in VOICE_CHARACTERS:
        print(f"\n[{char['id']}] {char['name']}")
        print(f"  Text: {char['preview_text'][:30]}...")
        print(f"  Voice ID: {char['voice_id']}")

        output_path = output_dir / f"{char['id']}_preview.mp3"

        if synthesize_to_file(
            client,
            text=char['preview_text'],
            voice_id=char['voice_id'],
            output_path=output_path,
            stability=char['stability'],
            similarity_boost=char['similarity_boost'],
        ):
            print(f"  ✓ Saved: {output_path}")
            success_count += 1
        else:
            print(f"  ✗ Failed to generate")

    # Generate sample story
    print("\n" + "-" * 40)
    print("\nGenerating sample story narration...")

    story_path = output_dir / "sample_story_elevenlabs.mp3"
    if synthesize_to_file(
        client,
        text=SAMPLE_STORY,
        voice_id="EXAVITQu4vr4xnSDxMaL",  # Bella for story
        output_path=story_path,
        stability=0.5,
        similarity_boost=0.75,
    ):
        print(f"  ✓ Saved: {story_path}")
        success_count += 1

    # Summary
    print("\n" + "=" * 60)
    print(f"Done! Generated {success_count} audio files")
    print(f"Files saved to: {output_dir.absolute()}")
    print()
    print("To play on macOS:")
    print(f"  afplay {output_dir}/narrator-female_preview.mp3")
    print()
    print("Note: ElevenLabs free tier has ~10,000 characters/month limit")
    print()


if __name__ == "__main__":
    main()
