from typing import Optional

def create_ssml(
    text: str,
    voice_name: str,
    language: str = "zh-TW",
    style: Optional[str] = None,
    role: Optional[str] = None,
    pitch: Optional[str] = None,
    rate: Optional[str] = None,
    volume: Optional[str] = None,
) -> str:
    """
    Generate SSML string for Azure TTS.
    
    Args:
        text: The text to speak
        voice_name: The Azure voice name (e.g., zh-TW-HsiaoChenNeural)
        language: The language code (default: zh-TW)
        style: Optional speaking style (e.g., cheerful, sad)
        role: Optional role play (e.g., Girl, Boy)
        pitch: Optional pitch adjustment (e.g., +0%, high)
        rate: Optional rate adjustment (e.g., 1.0, fast)
        volume: Optional volume adjustment (e.g., medium, +10%)
        
    Returns:
        String containing the formatted SSML
    """
    
    # Start with standard wrapper
    ssml_parts = [
        f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="{language}">',
        f'  <voice name="{voice_name}">'
    ]
    
    # Build inner mstts:express-as if style or role is present
    express_open = ""
    express_close = ""
    
    if style or role:
        express_attrs = []
        if style:
            express_attrs.append(f'style="{style}"')
        if role:
            express_attrs.append(f'role="{role}"')
        
        express_open = f'<mstts:express-as {" ".join(express_attrs)}>'
        express_close = "</mstts:express-as>"
        ssml_parts.append(f"    {express_open}")
    
    # Build prosody if pitch, rate, or volume is present
    prosody_open = ""
    prosody_close = ""
    
    if pitch or rate or volume:
        prosody_attrs = []
        if pitch:
            prosody_attrs.append(f'pitch="{pitch}"')
        if rate:
            prosody_attrs.append(f'rate="{rate}"')
        if volume:
            prosody_attrs.append(f'volume="{volume}"')
            
        prosody_open = f'<prosody {" ".join(prosody_attrs)}>'
        prosody_close = "</prosody>"
        
        indent = "      " if (style or role) else "    "
        ssml_parts.append(f"{indent}{prosody_open}")
    
    # Add text
    text_indent = "        " if (pitch or rate or volume) else ("      " if (style or role) else "    ")
    ssml_parts.append(f"{text_indent}{text}")
    
    # Close tags
    if prosody_close:
        indent = "      " if (style or role) else "    "
        ssml_parts.append(f"{indent}{prosody_close}")
        
    if express_close:
        ssml_parts.append(f"    {express_close}")
        
    ssml_parts.append('  </voice>')
    ssml_parts.append('</speak>')
    
    return "\n".join(ssml_parts)
