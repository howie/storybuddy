# Implementation Plan: StoryBuddy MVP

**Branch**: `000-StoryBuddy-mvp` | **Date**: 2026-01-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/docs/features/000-StoryBuddy-mvp/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command.

## Summary

StoryBuddy 是一個親子說故事 App，核心功能包括：
1. 家長錄製中文語音樣本，用於 AI 聲音克隆
2. AI 使用家長聲音朗讀故事（外部匯入或 AI 生成）
3. 故事後互動問答模式，AI 回答故事相關問題，超出範圍的問題記錄供家長回答

技術上需要整合：聲音克隆（TTS）、中文語音識別（STT）、LLM 故事生成與問答

## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: NEEDS CLARIFICATION - 需研究 Voice Cloning API 選擇 (ElevenLabs / OpenAI TTS / Azure Speech)
**Storage**: SQLite（本地）+ Cloud Storage（語音檔案）
**Testing**: pytest
**Target Platform**: Mobile-first PWA 或原生 App - NEEDS CLARIFICATION（iOS/Android 優先順序）
**Project Type**: Mobile + Backend API
**Performance Goals**: 故事生成 < 30秒, 問答回應延遲 < 3秒
**Constraints**: 需支援離線播放已下載故事, 聲音克隆需符合隱私政策
**Scale/Scope**: MVP 階段 - 單一家庭使用, 預計 10-50 個故事

### AI/API 整合需研究項目

| 功能 | 待研究選項 | 研究重點 |
|------|-----------|---------|
| 聲音克隆 TTS | ElevenLabs / OpenAI TTS / Azure Speech | 中文支援、價格、聲音品質 |
| 語音識別 STT | OpenAI Whisper / Azure Speech / Google STT | 中文準確度、兒童語音支援 |
| 故事生成 & 問答 | OpenAI GPT / Claude / Azure OpenAI | 中文能力、內容安全過濾 |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Reference**: [Constitution v1.0.0](../../../.specify/memory/constitution.md)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First | PASS | pytest + TDD enforced |
| II. Modular Design | PASS | API / Service / Data layers separated |
| III. Security & Privacy | PASS | Voice encryption, env vars for keys, consent flow planned |
| IV. Observability | PASS | Structured JSON logging |
| V. Simplicity | PASS | MVP scope maintained, single-family use |

**Additional Standards**:

| Standard | Status | Notes |
|----------|--------|-------|
| Children's Safety | PASS | Claude content filtering, parental oversight, question boundaries |
| Privacy Requirements | PASS | Local-first storage, consent before cloning, deletion rights |
| Quality Gates | PASS | CI with tests, ruff, mypy configured |

## Project Structure

### Documentation (this feature)

```text
docs/features/000-StoryBuddy-mvp/
├── plan.md              # 實作計劃 (本文件)
├── research.md          # 技術研究結果
├── data-model.md        # 資料模型定義
├── quickstart.md        # 快速開始指南
├── contracts/
│   └── openapi.yaml     # API 規格 (OpenAPI 3.1)
└── tasks.md             # 任務清單 (待生成 - /speckit.tasks)
```

### Source Code (repository root)

```text
# Backend API (Python FastAPI)
src/
├── __init__.py
├── main.py                     # FastAPI 入口
├── config.py                   # 設定管理
├── api/                        # API 路由
│   ├── __init__.py
│   ├── voice.py                # 聲音模型 API
│   ├── stories.py              # 故事 API
│   ├── qa.py                   # 問答 API
│   └── questions.py            # 待回答問題 API
├── models/                     # Pydantic 模型
│   ├── __init__.py
│   ├── voice.py
│   ├── story.py
│   ├── qa.py
│   └── question.py
├── services/                   # 業務邏輯
│   ├── __init__.py
│   ├── voice_cloning.py        # ElevenLabs 整合
│   ├── speech_recognition.py   # Azure Speech 整合
│   ├── story_generator.py      # Claude 故事生成
│   └── qa_handler.py           # Claude 問答處理
└── db/                         # 資料庫
    ├── __init__.py
    ├── init.py
    └── repository.py

tests/
├── contract/                   # 合約測試
├── integration/                # 整合測試
└── unit/                       # 單元測試

# Mobile App (React Native + Expo) - 獨立 repo 或子目錄
app/
├── src/
│   ├── screens/                # 頁面
│   │   ├── HomeScreen.tsx
│   │   ├── RecordVoiceScreen.tsx
│   │   ├── StoryListScreen.tsx
│   │   ├── StoryPlayerScreen.tsx
│   │   ├── QAScreen.tsx
│   │   └── PendingQuestionsScreen.tsx
│   ├── components/             # 共用元件
│   ├── services/               # API 客戶端
│   └── hooks/                  # 自定義 hooks
└── tests/

# Local data (not committed)
data/
├── db/
│   └── storybuddy.db           # SQLite 資料庫
└── audio/
    ├── voice_samples/          # 家長錄音樣本
    ├── stories/                # 生成的故事語音
    ├── qa_responses/           # AI 問答回應
    └── parent_answers/         # 家長回答錄音
```

**Structure Decision**: 採用 Mobile + Backend API 架構
- **Backend**: Python FastAPI 提供 RESTful API，處理 AI 服務整合
- **Mobile**: React Native + Expo 提供跨平台支援，iOS 優先
- **Storage**: SQLite 本地資料庫 + 檔案系統儲存音訊

## Complexity Tracking

> 目前設計符合 MVP 簡單性原則，無需額外複雜性

| 項目 | 狀態 | 說明 |
|------|------|------|
| 單一資料庫 | PASS | SQLite 足夠 MVP 單一家庭使用 |
| 無 ORM 抽象 | PASS | 直接使用 aiosqlite，簡單直接 |
| 無微服務 | PASS | 單一 FastAPI 應用程式 |
| 無 Redis/Queue | PASS | 直接處理，無需佇列 |

## Post-Design Constitution Check

*Re-evaluation after Phase 1 design completion*

| 原則 | 狀態 | 說明 |
|------|------|------|
| 測試優先 | PASS | 設計包含 unit/integration/contract 測試結構 |
| 模組化設計 | PASS | API 層、服務層、資料層清楚分離 |
| 安全性 | PASS | 聲音資料本地儲存，API Keys 環境變數管理 |
| 可觀察性 | PASS | FastAPI 內建日誌 + 未來可加 structured logging |
| 簡單性 | PASS | 無過度工程，所有元件都有明確用途 |
| 隱私保護 | 需注意 | 聲音資料上傳 ElevenLabs - 需在 UI 告知用戶 |

**Gate Status**: PASS - 設計符合所有核心原則

---

## 生成的設計文檔

| 文件 | 路徑 | 狀態 |
|------|------|------|
| 技術研究 | `docs/features/000-StoryBuddy-mvp/research.md` | 完成 |
| 資料模型 | `docs/features/000-StoryBuddy-mvp/data-model.md` | 完成 |
| API 規格 | `docs/features/000-StoryBuddy-mvp/contracts/openapi.yaml` | 完成 |
| 快速開始 | `docs/features/000-StoryBuddy-mvp/quickstart.md` | 完成 |

## 下一步

執行 `/speckit.tasks` 生成實作任務清單
