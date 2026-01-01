# Research: StoryBuddy MVP

**Branch**: `000-StoryBuddy-mvp` | **Date**: 2026-01-01

## 研究摘要

本研究針對 StoryBuddy MVP 的四個關鍵技術選擇進行調查：
1. 聲音克隆 TTS API
2. 語音識別 STT API
3. LLM API（故事生成與問答）
4. Mobile 開發平台

---

## 1. 聲音克隆 TTS (Text-to-Speech with Voice Cloning)

### Decision: ElevenLabs

### Rationale

ElevenLabs 在易用性、中文支援和價格之間提供最佳平衡：

| 評估項目 | ElevenLabs | Azure CNV | Coqui TTS |
|---------|------------|-----------|-----------|
| 中文支援 | 良好 | 優秀 | 一般 |
| 最小錄音時長 | 1-3 分鐘 | 20+ 句 | 6秒-2小時 |
| 設置複雜度 | 低 | 中高 | 高 |
| MVP 成本 | $22-44/月 | $200-500+ | $0 + 主機費用 |
| 延遲 | 300-500ms | 200-400ms | 1-2 秒 |
| 隱私控制 | 中等 | 良好 | 優秀 |

**選擇 ElevenLabs 的原因：**
1. 家長只需錄製 3 分鐘即可建立聲音模型
2. 無需 ML 專業知識，API 整合簡單
3. Creator Plan ($22/月) 可覆蓋 MVP 需求（~100K 字符）
4. Multilingual v2 模型支援中文，聲音克隆可跨語言使用

**注意事項：**
- 家長聲音資料會上傳至 ElevenLabs 伺服器
- 中文聲調準確度可能偶有偏差
- 未來可考慮遷移至 Azure Custom Neural Voice 以獲得更好的中文品質和隱私控制

### Alternatives Considered

1. **OpenAI TTS**: 不支援聲音克隆 - 不適用
2. **Azure Custom Neural Voice**: 品質最佳但需要審批流程，設置複雜，成本較高
3. **Coqui TTS**: 開源自主部署，但需要 ML 專業知識和 GPU 資源

---

## 2. 語音識別 STT (Speech-to-Text)

### Decision: Microsoft Azure Speech Services

### Rationale

對於兒童（3-8歲）中文語音識別，Azure 提供最佳的支援：

| 評估項目 | Azure Speech | Whisper API | Google STT |
|---------|--------------|-------------|------------|
| 中文準確度 | 優秀 | 良好 | 良好 |
| 兒童語音支援 | 優秀 (Custom Speech) | 一般 | 一般 |
| 即時串流 | 支援 | 不支援 | 支援 |
| 延遲 | 200-500ms | 2-10秒 | 300-800ms |
| 價格 | $1/小時 | $0.36/小時 | $1.44-2.16/小時 |

**選擇 Azure 的原因：**
1. **即時串流必要** - 兒童問問題需要即時回饋，Azure 的 200-500ms 延遲可實現自然對話
2. **Custom Speech 支援兒童語音** - 可建立針對兒童聲音特徵優化的模型
3. **中文支援優秀** - 支援 zh-CN（簡體）和 zh-TW（繁體）
4. **發音評估功能** - 可做為教育功能的附加價值
5. **免費額度** - 5小時/月可供測試

### Alternatives Considered

1. **OpenAI Whisper API**: 較便宜但無串流支援，延遲 2-10 秒不適合即時對話
2. **Google Cloud STT**: 串流支援佳但價格較高，無特別兒童語音優化
3. **Self-hosted Whisper**: 可離線使用，但需要 GPU 資源和維護成本

### Implementation Approach

```
Phase 1 (MVP):
- 使用 Azure Speech SDK 搭配 zh-TW 語言
- 啟用 interim results 提供響應式 UX
- 實作兒童說話時暫停的超時處理

Phase 2 (優化):
- 收集匿名語音樣本（需家長同意）
- 訓練 Custom Speech 模型優化兒童識別
- 添加故事相關的自定義詞彙
```

---

## 3. LLM API（故事生成與問答）

### Decision: Claude 3.5 Sonnet (主要) + Claude 3.5 Haiku (輔助)

### Rationale

對於兒童內容安全性要求高的應用，Claude 的內建安全機制最為可靠：

| 評估項目 | Claude 3.5 Sonnet | GPT-4o | GPT-4o-mini |
|---------|-------------------|--------|-------------|
| 中文品質 | 優秀 | 優秀 | 良好 |
| Context Window | 200K tokens | 128K tokens | 128K tokens |
| 輸入價格 | $3/1M tokens | $2.50/1M tokens | $0.15/1M tokens |
| 輸出價格 | $15/1M tokens | $10/1M tokens | $0.60/1M tokens |
| 內容安全 | 內建 Constitutional AI | 需另外呼叫 Moderation API | 需另外呼叫 |
| 中文審核 | 內建 | Moderation API 中文支援有限 | 同左 |

**選擇 Claude 的原因：**
1. **內建安全機制 (Constitutional AI)** - 無需額外 API 呼叫，模型本身會拒絕生成不當內容
2. **最大 Context Window (200K)** - 可容納完整故事 + 對話歷史
3. **中文故事創作優秀** - 自然流暢，能調整適合兒童的詞彙
4. **指令遵循能力強** - 可準確判斷問題是否超出故事範圍

**混合架構建議：**
- **故事生成**：Claude 3.5 Sonnet（品質 + 安全）
- **問答/分類**：Claude 3.5 Haiku（速度 + 成本）

### Alternatives Considered

1. **GPT-4o**: 中文品質同樣優秀，但內容安全需要另外呼叫 Moderation API，且該 API 中文支援有限
2. **GPT-4o-mini**: 最低成本選項，適合預算緊張的情況
3. **Azure OpenAI**: 與 OpenAI 相同模型但提供企業合規和區域部署選項

### Out-of-Scope Detection Implementation

```python
SYSTEM_PROMPT = """
你是一個為 4-8 歲兒童講故事的友好助手。

當前故事：{story_content}

對於每個問題，判斷是否在故事範圍內：
- IN_SCOPE: 關於故事角色、情節、詞彙的問題
- OUT_OF_SCOPE: 與故事無關的問題

OUT_OF_SCOPE 回答範例：
「這是個好問題！我們先記錄起來，等一下問爸爸媽媽好不好？現在我們繼續來聊聊故事裡的小兔子吧！」
"""
```

### Cost Estimate (MVP: 1000 users, 2 stories/day)

| 模型 | 月估計成本 |
|------|----------|
| Claude 3.5 Haiku only | ~$80/月 |
| Claude 3.5 Sonnet only | ~$945/月 |
| 混合 (Sonnet 故事 + Haiku 問答) | ~$200/月 |

---

## 4. Mobile 開發平台

### Decision: React Native with Expo

### Rationale

對於單人開發者快速建立 MVP，React Native + Expo 提供最佳平衡：

| 評估項目 | React Native | Flutter | PWA | Native |
|---------|--------------|---------|-----|--------|
| 錄音功能 | 優秀 | 優秀 | 有限 | 優秀 |
| 背景播放 | 良好 | 良好 | iOS 差 | 優秀 |
| 語音識別 | 良好 | 良好 | iOS 不支援 | 優秀 |
| 離線支援 | 優秀 | 優秀 | 有限 | 優秀 |
| MVP 開發時間 | 4-8 週 | 4-8 週 | 2-4 週 | 8-16 週 |
| 單人開發 | 適合 | 適合 | 適合 | 困難 |

**選擇 React Native 的原因：**
1. **音訊處理成熟** - `expo-av` 提供簡單的錄音 API，`react-native-track-player` 處理背景播放
2. **語音識別可用** - `@react-native-voice/voice` 支援中文，使用原生 iOS/Android API
3. **離線簡單直接** - 下載音訊到設備儲存，使用 SQLite/Realm 儲存 metadata
4. **快速 MVP 開發** - Expo managed workflow、Expo Go 快速測試、EAS Build 生產構建
5. **單人開發友好** - 社群大、React/JavaScript 人才多
6. **App Store 上架** - 對台灣/中文市場用戶信任度重要

### Alternatives Considered

1. **PWA**: iOS Safari 不支援語音識別、背景音訊不可靠 - **不適用**
2. **Flutter**: 同樣優秀，但 Dart 生態較小，未來招聘困難
3. **Native iOS + Android**: 2 倍開發時間，MVP 階段不划算

### Suggested Tech Stack

```
Framework: React Native with Expo (managed workflow)

Audio:
- expo-av (錄音, 簡單播放)
- react-native-track-player (背景播放, 佇列管理)

Speech Recognition:
- @react-native-voice/voice

Storage:
- expo-file-system (音訊檔案)
- expo-sqlite (metadata)

UI:
- React Native Paper 或 NativeBase

Backend:
- Python FastAPI (主要 API)
- Firebase/Supabase (可選: 驗證, 雲端儲存)
```

---

## 技術決策總結

| 功能 | 選擇 | 替代方案 |
|------|------|---------|
| 聲音克隆 TTS | ElevenLabs | Azure CNV (品質更佳但複雜) |
| 語音識別 STT | Azure Speech Services | Whisper API (便宜但延遲高) |
| LLM | Claude 3.5 Sonnet + Haiku | GPT-4o-mini (便宜) |
| Mobile | React Native + Expo | Flutter |
| Backend | Python FastAPI | - |
| 資料庫 | SQLite (本地) | - |

## MVP 預估成本 (月)

| 項目 | 預估成本 |
|------|---------|
| ElevenLabs Creator | $22 |
| Azure Speech (5hr free, 後 ~10hr) | $10 |
| Claude API | ~$200 |
| Apple Developer | $99/年 ≈ $8/月 |
| **總計** | **~$240/月** |

## 下一步

1. ✅ 技術研究完成
2. ⏳ 建立 data-model.md
3. ⏳ 建立 API contracts
4. ⏳ 建立 quickstart.md
