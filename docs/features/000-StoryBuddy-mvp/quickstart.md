# Quickstart: StoryBuddy MVP

**Branch**: `000-StoryBuddy-mvp` | **Date**: 2026-01-01

本文檔提供快速開始 StoryBuddy 開發的指南。

---

## 前置需求

### 系統需求

- Python 3.11+
- Node.js 18+ (for React Native / Expo)
- Git

### API Keys (需申請)

| Service | 用途 | 申請網址 |
|---------|------|---------|
| ElevenLabs | 聲音克隆 TTS | https://elevenlabs.io/ |
| Azure Speech | 語音識別 STT | https://azure.microsoft.com/en-us/products/ai-services/speech-to-text |
| Anthropic Claude | 故事生成/問答 | https://console.anthropic.com/ |

---

## 後端設置

### 1. 建立 Python 虛擬環境

```bash
# 建立虛擬環境
python3 -m venv venv

# 啟動虛擬環境
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# 升級 pip
pip install --upgrade pip
```

### 2. 安裝依賴

```bash
pip install fastapi uvicorn pydantic python-dotenv
pip install anthropic elevenlabs azure-cognitiveservices-speech
pip install aiosqlite python-multipart
pip install pytest pytest-asyncio httpx  # 測試用
```

### 3. 環境變數設定

創建 `.env` 檔案：

```env
# Server
DEBUG=true
API_HOST=0.0.0.0
API_PORT=8000

# ElevenLabs (Voice Cloning TTS)
ELEVENLABS_API_KEY=your_elevenlabs_api_key

# Azure Speech (STT)
AZURE_SPEECH_KEY=your_azure_speech_key
AZURE_SPEECH_REGION=eastasia  # or your preferred region

# Anthropic Claude (LLM)
ANTHROPIC_API_KEY=your_anthropic_api_key

# Storage
DATA_DIR=./data
DATABASE_URL=sqlite+aiosqlite:///./data/db/storybuddy.db
```

### 4. 初始化資料庫

```bash
# 創建資料目錄
mkdir -p data/db data/audio/voice_samples data/audio/stories data/audio/qa_responses data/audio/parent_answers

# 執行資料庫遷移 (待實作)
python -m src.db.init
```

### 5. 啟動開發伺服器

```bash
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

API 文檔可在 http://localhost:8000/docs 查看。

---

## 前端設置 (React Native + Expo)

### 1. 安裝 Expo CLI

```bash
npm install -g expo-cli
```

### 2. 建立 React Native 專案

```bash
npx create-expo-app@latest storybuddy-app
cd storybuddy-app
```

### 3. 安裝依賴

```bash
# Audio
npx expo install expo-av
npm install react-native-track-player

# Speech Recognition
npm install @react-native-voice/voice
npx expo install expo-speech

# Storage
npx expo install expo-file-system expo-sqlite

# Navigation
npm install @react-navigation/native @react-navigation/native-stack
npx expo install react-native-screens react-native-safe-area-context

# UI
npm install react-native-paper
```

### 4. 設定環境變數

創建 `.env` 檔案 (使用 `react-native-dotenv`)：

```env
API_BASE_URL=http://localhost:8000
```

### 5. 啟動開發

```bash
npx expo start
```

使用 Expo Go app 掃描 QR code 在手機上測試。

---

## 專案結構

```
storybuddy/
├── docs/
│   └── features/                   # 設計文檔
│       └── 000-StoryBuddy-mvp/
│           ├── spec.md             # 功能規格
│           ├── plan.md             # 實作計劃
│           ├── research.md         # 技術研究
│           ├── data-model.md       # 資料模型
│           ├── quickstart.md       # 本文檔
│           ├── contracts/
│           │   └── openapi.yaml    # API 規格
│           └── tasks.md            # 任務清單 (待生成)
│
├── src/                            # 後端程式碼
│   ├── __init__.py
│   ├── main.py                     # FastAPI 入口
│   ├── config.py                   # 設定管理
│   ├── api/                        # API 路由
│   │   ├── __init__.py
│   │   ├── voice.py                # 聲音模型 API
│   │   ├── stories.py              # 故事 API
│   │   ├── qa.py                   # 問答 API
│   │   └── questions.py            # 待回答問題 API
│   ├── models/                     # Pydantic 模型
│   │   ├── __init__.py
│   │   ├── voice.py
│   │   ├── story.py
│   │   ├── qa.py
│   │   └── question.py
│   ├── services/                   # 業務邏輯
│   │   ├── __init__.py
│   │   ├── voice_cloning.py        # ElevenLabs 整合
│   │   ├── speech_recognition.py   # Azure Speech 整合
│   │   ├── story_generator.py      # Claude 故事生成
│   │   └── qa_handler.py           # Claude 問答處理
│   └── db/                         # 資料庫
│       ├── __init__.py
│       ├── init.py
│       └── repository.py
│
├── tests/                          # 測試
│   ├── contract/                   # 合約測試
│   ├── integration/                # 整合測試
│   └── unit/                       # 單元測試
│
├── app/                            # React Native 前端 (獨立 repo 或子目錄)
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── services/
│   │   └── hooks/
│   └── ...
│
├── data/                           # 本地資料 (不提交)
│   ├── db/
│   │   └── storybuddy.db
│   └── audio/
│       ├── voice_samples/
│       ├── stories/
│       ├── qa_responses/
│       └── parent_answers/
│
├── .env                            # 環境變數 (不提交)
├── .gitignore
├── requirements.txt
├── pyproject.toml
└── CLAUDE.md
```

---

## 核心 API 快速測試

### 1. 建立聲音模型

```bash
# 建立聲音模型
curl -X POST http://localhost:8000/api/v1/voice-profiles \
  -H "Content-Type: application/json" \
  -d '{"parent_id": "123e4567-e89b-12d3-a456-426614174000", "name": "爸爸"}'

# 上傳語音樣本
curl -X POST http://localhost:8000/api/v1/voice-profiles/{voice_profile_id}/upload \
  -F "audio=@sample.wav"
```

### 2. 建立故事

```bash
# 匯入故事
curl -X POST http://localhost:8000/api/v1/stories \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": "123e4567-e89b-12d3-a456-426614174000",
    "title": "小兔子的冒險",
    "content": "從前從前，有一隻小白兔住在森林裡...",
    "source": "imported"
  }'

# AI 生成故事
curl -X POST http://localhost:8000/api/v1/stories/generate \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": "123e4567-e89b-12d3-a456-426614174000",
    "keywords": ["小兔子", "森林", "勇敢"],
    "age_group": "4-6",
    "word_count": 500
  }'
```

### 3. 生成故事語音

```bash
curl -X POST http://localhost:8000/api/v1/stories/{story_id}/audio \
  -H "Content-Type: application/json" \
  -d '{"voice_profile_id": "your_voice_profile_id"}'
```

### 4. 開始問答

```bash
# 開始問答對話
curl -X POST http://localhost:8000/api/v1/qa/sessions \
  -H "Content-Type: application/json" \
  -d '{"story_id": "your_story_id"}'

# 發送問題
curl -X POST http://localhost:8000/api/v1/qa/sessions/{session_id}/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "小兔子後來怎麼了？"}'
```

---

## 開發工作流程

### 測試驅動開發 (TDD)

```bash
# 執行所有測試
pytest

# 執行特定測試
pytest tests/unit/test_story_generator.py -v

# 監視模式
pytest-watch
```

### 程式碼品質

```bash
# Linting
ruff check .

# 格式化
ruff format .

# 類型檢查
mypy src/
```

### API 文檔

開發伺服器啟動後，可在以下位置查看 API 文檔：

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI JSON: http://localhost:8000/openapi.json

---

## 常見問題

### ElevenLabs 聲音品質不佳

1. 確保錄音樣本品質：
   - 安靜環境
   - 清晰發音
   - 至少 60 秒錄音
2. 使用 Multilingual v2 模型
3. 考慮升級到 Professional Voice Cloning

### Azure Speech 中文識別準確度問題

1. 確認使用正確的語言代碼 (zh-TW 或 zh-CN)
2. 考慮訓練 Custom Speech 模型
3. 添加自定義詞彙

### Claude 生成內容不適當

1. 強化 system prompt 中的安全指令
2. 添加輸出過濾層
3. 限制可接受的主題範圍

---

## 下一步

1. [ ] 執行 `/speckit.tasks` 生成任務清單
2. [ ] 實作核心 API endpoints
3. [ ] 整合 ElevenLabs 聲音克隆
4. [ ] 整合 Azure Speech 語音識別
5. [ ] 整合 Claude 故事生成/問答
6. [ ] 建立 React Native 前端框架
7. [ ] 實作錄音功能
8. [ ] 實作故事播放功能
9. [ ] 實作問答互動功能
10. [ ] 測試與優化
