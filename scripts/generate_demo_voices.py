#!/usr/bin/env python3
"""
Generate demo voice samples for StoryBuddy voice kit feature.

Usage:
    1. Set environment variables:
       export AZURE_SPEECH_KEY="your-key-here"
       export AZURE_SPEECH_REGION="eastasia"  # or your region

    2. Install dependency:
       pip install azure-cognitiveservices-speech

    3. Run:
       python scripts/generate_demo_voices.py

Output:
    Creates demo audio files in data/voice_previews/
"""

import os
import sys
from pathlib import Path

try:
    import azure.cognitiveservices.speech as speechsdk
except ImportError:
    print("Error: azure-cognitiveservices-speech not installed")
    print("Run: pip install azure-cognitiveservices-speech")
    sys.exit(1)


# Voice character configurations
VOICE_CHARACTERS = [
    {
        "id": "narrator-female",
        "name": "故事姐姐",
        "voice": "zh-TW-HsiaoChenNeural",
        "ssml_role": None,
        "ssml_style": None,
        "preview_text": "大家好，我是故事姐姐，今天要講一個精彩的故事給你聽！"
    },
    {
        "id": "narrator-male",
        "name": "故事哥哥",
        "voice": "zh-TW-YunJheNeural",
        "ssml_role": None,
        "ssml_style": None,
        "preview_text": "嗨！我是故事哥哥，準備好聽故事了嗎？"
    },
    {
        "id": "child-girl",
        "name": "小美",
        "voice": "zh-TW-HsiaoChenNeural",
        "ssml_role": "Girl",
        "ssml_style": "cheerful",
        "preview_text": "哈囉！我是小美，我們一起來冒險吧！"
    },
    {
        "id": "child-boy",
        "name": "小明",
        "voice": "zh-TW-YunJheNeural",
        "ssml_role": "Boy",
        "ssml_style": "cheerful",
        "preview_text": "嘿！我是小明，今天會發生什麼有趣的事呢？"
    },
    {
        "id": "elder-female",
        "name": "故事阿嬤",
        "voice": "zh-TW-HsiaoChenNeural",
        "ssml_role": "SeniorFemale",
        "ssml_style": "gentle",
        "preview_text": "乖孫，阿嬤來講古早的故事給你聽..."
    },
    {
        "id": "elder-male",
        "name": "故事阿公",
        "voice": "zh-TW-YunJheNeural",
        "ssml_role": "SeniorMale",
        "ssml_style": "calm",
        "preview_text": "來，阿公說一個很久很久以前的故事..."
    },
]

# Sample story text for longer demo
SAMPLE_STORY = """
從前從前，在一座美麗的森林裡，住著一隻勇敢的小兔子。
小兔子每天都會在森林裡探險，尋找美味的紅蘿蔔。
有一天，小兔子發現了一條從未走過的小路...
"""


def get_speech_config():
    """Create Azure Speech config from environment variables."""
    key = os.getenv("AZURE_SPEECH_KEY")
    region = os.getenv("AZURE_SPEECH_REGION", "eastasia")

    if not key:
        print("Error: AZURE_SPEECH_KEY environment variable not set")
        print("\nTo get an Azure Speech key:")
        print("1. Go to https://portal.azure.com")
        print("2. Create a Speech Services resource")
        print("3. Copy the Key from 'Keys and Endpoint'")
        print("\nThen run:")
        print('  export AZURE_SPEECH_KEY="your-key-here"')
        print('  export AZURE_SPEECH_REGION="eastasia"')
        sys.exit(1)

    return speechsdk.SpeechConfig(subscription=key, region=region)


def generate_ssml(text: str, voice: str, role: str = None, style: str = None) -> str:
    """Generate SSML markup for voice synthesis."""
    if role:
        return f'''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="zh-TW">
    <voice name="{voice}">
        <mstts:express-as role="{role}" style="{style or 'general'}">
            {text}
        </mstts:express-as>
    </voice>
</speak>'''
    else:
        return f'''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-TW">
    <voice name="{voice}">
        {text}
    </voice>
</speak>'''


def synthesize_to_file(speech_config, ssml: str, output_path: Path) -> bool:
    """Synthesize speech and save to file."""
    audio_config = speechsdk.audio.AudioOutputConfig(filename=str(output_path))

    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config,
        audio_config=audio_config
    )

    result = synthesizer.speak_ssml_async(ssml).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return True
    elif result.reason == speechsdk.ResultReason.Canceled:
        cancellation = result.cancellation_details
        print(f"  Error: {cancellation.reason}")
        if cancellation.error_details:
            print(f"  Details: {cancellation.error_details}")
        return False
    return False


def main():
    print("=" * 60)
    print("StoryBuddy Voice Kit - Demo Voice Generator")
    print("=" * 60)
    print()

    # Setup
    speech_config = get_speech_config()
    speech_config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoMp3
    )

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

        ssml = generate_ssml(
            text=char['preview_text'],
            voice=char['voice'],
            role=char['ssml_role'],
            style=char['ssml_style']
        )

        output_path = output_dir / f"{char['id']}_preview.mp3"

        if synthesize_to_file(speech_config, ssml, output_path):
            print(f"  ✓ Saved: {output_path}")
            success_count += 1
        else:
            print(f"  ✗ Failed to generate")

    # Generate sample story with default narrator
    print("\n" + "-" * 40)
    print("\nGenerating sample story narration...")

    story_ssml = generate_ssml(
        text=SAMPLE_STORY,
        voice="zh-TW-HsiaoChenNeural"
    )

    story_path = output_dir / "sample_story.mp3"
    if synthesize_to_file(speech_config, story_ssml, story_path):
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


if __name__ == "__main__":
    main()
