# Research: Selectable Voice Kit

**Feature**: 003-selectable-voice-kit
**Date**: 2026-01-05
**Status**: Complete

## Executive Summary

This research evaluates TTS (Text-to-Speech) services for implementing a selectable voice kit feature in StoryBuddy, enabling children to choose different character voices for storytelling. Key findings:

1. **Legal Risk**: Imitating specific cartoon characters (PAW Patrol, Shimajiro, etc.) carries significant copyright/trademark risks
2. **Recommended Approach**: Use generic character archetypes (boy, girl, elderly narrator, etc.) with original voices
3. **Best TTS for zh-TW**: Microsoft Azure offers the most features, but all services have limited Traditional Chinese child voices
4. **Cost-Effective**: Azure and Google Cloud have generous free tiers for development

---

## 1. Legal & Licensing Analysis

### Can We Legally Imitate Character Voices?

| Protection Type | Coverage | Risk Level |
|----------------|----------|------------|
| **Copyright** | Character expression, dialogue, distinctive traits | High |
| **Trademark** | Character names, catchphrases, distinctive sounds | High |
| **Right of Publicity** | Voice actor's vocal likeness | Medium-High |

### Key Legal Precedents

- **Midler v. Ford Motor Co. (1988)**: Imitating a distinctive voice can violate right of publicity
- **Waits v. Frito-Lay (1992)**: $2.6M award for voice imitation in commercial

### Character Risk Assessment

| Character | Owner | Risk |
|-----------|-------|------|
| PAW Patrol (旺旺隊) | Spin Master/Nickelodeon | Very High |
| Shimajiro (巧虎) | Benesse Corporation | Very High |
| Peppa Pig (佩佩豬) | Hasbro/Entertainment One | Very High |

### Decision: Use Generic Character Archetypes

**Recommended Safe Voice Categories:**

| Archetype | Description | Legal Status |
|-----------|-------------|--------------|
| 小男孩 (Young Boy) | Energetic, curious child voice | Safe |
| 小女孩 (Young Girl) | Bright, playful child voice | Safe |
| 故事阿公 (Story Grandpa) | Warm, patient elderly male | Safe |
| 故事阿嬤 (Story Grandma) | Gentle, nurturing elderly female | Safe |
| 冒險英雄 (Adventure Hero) | Brave, encouraging tone | Safe |
| 魔法精靈 (Magic Fairy) | Whimsical, fairy-tale style | Safe |

**Rationale**: Original characters provide legal safety, creative freedom, no licensing costs, and full ownership.

---

## 2. TTS Service Comparison

### Overview Table

| Service | Chinese (zh-TW) | Child Voices | Voice Cloning | Pricing | Recommendation |
|---------|-----------------|--------------|---------------|---------|----------------|
| **Azure TTS** | 3 voices | Via SSML roles | Custom Neural Voice | $16/1M chars | **Primary** |
| **Google Cloud TTS** | WaveNet available | Limited | Custom Voice (beta) | $16/1M chars | Secondary |
| **ElevenLabs** | Limited | Community voices | Excellent | $5-330/month | Character voices |
| **Amazon Polly** | cmn-CN only | No | Brand Voice | $4/1M chars | Budget option |

---

## 3. Microsoft Azure TTS (Recommended Primary)

### Traditional Chinese (zh-TW) Voices

| Voice Name | Gender | Features |
|------------|--------|----------|
| zh-TW-HsiaoChenNeural | Female | Standard, viseme support |
| zh-TW-YunJheNeural | Male | Standard, viseme support |
| zh-TW-HsiaoYuNeural | Female | Standard |

### Strengths

1. **Rich SSML Support** - Excellent pitch, rate, emotion control
2. **Role-Play Feature** - Simulate child voices via SSML:
   ```xml
   <mstts:express-as role="Girl" style="cheerful">
       角色對話
   </mstts:express-as>
   ```
   Available roles: Girl, Boy, YoungAdultFemale, YoungAdultMale, OlderAdultFemale, OlderAdultMale, SeniorFemale, SeniorMale

3. **Storytelling Styles** (zh-CN voices):
   - `story` - narrative tone
   - `poetry-reading` - expressive reading
   - `narration-relaxed` - calm storytelling

4. **Multi-Character Dialogue**:
   ```xml
   <mstts:dialog>
       <mstts:turn speaker="narrator">從前從前...</mstts:turn>
       <mstts:turn speaker="princess">你好！</mstts:turn>
   </mstts:dialog>
   ```

5. **Background Audio** - Add ambient sounds in SSML
6. **Bookmarks** - Sync with illustrations

### Limitations

- **No native zh-TW child voices** - Must use role-play feature
- **zh-TW voices lack storytelling styles** - Only zh-CN has `story` style
- **Only 3 zh-TW voices** vs. dozens for zh-CN

### Pricing

| Tier | Price |
|------|-------|
| Free | 500,000 chars/month |
| Neural TTS | ~$16/1M characters |
| Custom Neural Voice | ~$24/1M characters |

### Custom Neural Voice

Can create unique character voices with:
- Lite tier: 20-50 samples, 90-day expiration
- Professional: 300-2000 samples, production quality

**Requirements**: Voice talent consent, Microsoft approval (~10 business days)

---

## 4. Google Cloud TTS

### Voice Types

| Type | Quality | zh-TW Support | Price |
|------|---------|---------------|-------|
| Standard | Basic | Yes | $4/1M chars |
| WaveNet | High | cmn-TW-Wavenet-A/B/C | $16/1M chars |
| Neural2 | Premium | Limited | $16/1M chars |
| Journey | Long-form | No zh-TW | $30/1M chars |

### zh-TW Voices (cmn-TW)

- cmn-TW-Wavenet-A (Female)
- cmn-TW-Wavenet-B (Male)
- cmn-TW-Wavenet-C (Male)
- cmn-TW-Standard-A/B/C

### Strengths

- Good WaveNet quality for Chinese
- Strong SSML prosody control
- 1M chars/month free tier

### Limitations

- No child-specific voices for zh-TW
- No storytelling-optimized voices
- Less emotion control than Azure

---

## 5. ElevenLabs

### Overview

Best-in-class voice cloning and voice library, but limited Chinese support.

### Pricing

| Plan | Price | Characters |
|------|-------|------------|
| Free | $0 | 10,000/month |
| Starter | $5/month | 30,000/month |
| Creator | $22/month | 100,000/month |
| Pro | $99/month | 500,000/month |
| Scale | $330/month | 2,000,000/month |

### Strengths

- **Voice Library** - Thousands of community-created voices
- **Instant Voice Cloning** - Create voices from samples
- **Voice Design** - Generate voices from text description
- **High quality English** - Industry-leading natural speech

### Limitations

- **Chinese support is experimental** - Quality may vary
- **No Traditional Chinese optimization** - Primary focus on Western languages
- **Higher cost** for high volume

### Best Use Case

Use for specific character voices where quality matters most, potentially mixed with Azure for bulk content.

---

## 6. Amazon Polly

### Overview

Cost-effective option but limited Chinese support.

### Chinese Voices

| Voice | Language | Type |
|-------|----------|------|
| Zhiyu | cmn-CN (Mandarin) | Neural |

**Note**: No zh-TW (Traditional Chinese) voices available.

### Pricing

| Type | Price |
|------|-------|
| Standard | $4/1M chars |
| Neural | $16/1M chars |
| Free tier | 5M chars/month (12 months) |

### Strengths

- Lowest cost for high volume
- Good AWS integration
- Generous free tier

### Limitations

- **No Traditional Chinese** - Only Simplified Chinese
- **No child voices** for Chinese
- Limited customization

---

## 7. Other Services Evaluated

### Resemble.AI

- Good voice cloning
- Enterprise pricing (~$1000+/month)
- Limited Chinese support
- **Verdict**: Too expensive for MVP

### Murf.ai

- 120+ AI voices
- Limited Chinese options
- Studio-focused features
- **Verdict**: Not suitable for API integration

### Coqui TTS (Open Source)

- Self-hosted option
- Requires ML expertise
- Can train custom voices
- **Verdict**: Consider for future cost optimization

### Local Taiwanese Services

- Limited API offerings
- Quality varies
- **Verdict**: Not ready for production

---

## 8. Recommended Architecture

### Multi-Provider Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                     Voice Kit Service                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Azure     │  │  ElevenLabs │  │   Google    │         │
│  │  (Primary)  │  │ (Character) │  │  (Backup)   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                  │
│         ▼                ▼                ▼                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Unified Voice API Interface              │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  Voice Cache Layer                    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Voice Kit Categories

| Category | Provider | Use Case |
|----------|----------|----------|
| **Default Narrator** | Azure zh-TW | Story narration |
| **Child Roles** | Azure SSML roles | Character dialogue |
| **Special Characters** | ElevenLabs | Premium character voices |
| **Fallback** | Google Cloud | When Azure unavailable |

### Built-in Voice Pack (No Download)

| ID | Name | Provider | Description |
|----|------|----------|-------------|
| default-narrator | 故事姐姐 | Azure zh-TW-HsiaoChenNeural | Warm narrator |
| narrator-male | 故事哥哥 | Azure zh-TW-YunJheNeural | Friendly male narrator |
| child-girl | 小女孩 | Azure SSML role=Girl | Playful girl |
| child-boy | 小男孩 | Azure SSML role=Boy | Curious boy |
| elder-female | 阿嬤 | Azure SSML role=SeniorFemale | Gentle grandmother |
| elder-male | 阿公 | Azure SSML role=SeniorMale | Wise grandfather |

---

## 9. Cost Analysis

### Estimated Monthly Cost (MVP)

Assumptions:
- 100 active families
- 5 stories/family/month
- Average story: 2000 characters
- Total: 1,000,000 characters/month

| Provider | Cost |
|----------|------|
| Azure Neural | $16/month |
| Google WaveNet | $16/month |
| ElevenLabs Starter | $5/month (limited) |
| Amazon Polly Neural | $16/month |

**Recommendation**: Start with Azure free tier (500K chars), upgrade to paid as needed.

### Cost per Story

| Story Length | Azure Neural | ElevenLabs Creator |
|--------------|--------------|-------------------|
| 1000 chars | $0.016 | ~$0.22 |
| 2000 chars | $0.032 | ~$0.44 |
| 5000 chars | $0.080 | ~$1.10 |

---

## 10. Decisions Summary

| Question | Decision | Rationale |
|----------|----------|-----------|
| Can we imitate cartoon characters? | **No** | Legal risk too high |
| Primary TTS provider? | **Azure** | Best zh-TW + SSML features |
| How to get child voices? | **SSML roles** | No native zh-TW child voices |
| Support multiple providers? | **Yes** | Redundancy + best-of-breed |
| Built-in voices count? | **6** | Sufficient variety without complexity |

---

## 11. Next Steps

1. **Phase 1**: Implement Azure TTS integration with SSML role support
2. **Phase 1**: Create 6 built-in voice characters
3. **Phase 2**: Add ElevenLabs for premium character voices (optional)
4. **Phase 2**: Implement downloadable voice packs
5. **Future**: Evaluate Coqui TTS for cost optimization

---

## References

- [Azure TTS Documentation](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/)
- [Google Cloud TTS](https://cloud.google.com/text-to-speech)
- [ElevenLabs](https://elevenlabs.io/)
- [Amazon Polly](https://aws.amazon.com/polly/)
