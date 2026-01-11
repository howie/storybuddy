# Feature Specification: Full App UI Flow

**Feature Branch**: `002-full-app-ui-flow`
**Created**: 2026-01-09
**Status**: Draft
**Input**: User description: "Complete the app UI navigation flow to make all features accessible from the main interface"

## Overview

StoryBuddy 行動應用程式目前缺少主導航結構，導致多個已實作的功能頁面無法被使用者存取。本功能將補齊應用程式的 UI 導航流程，讓所有功能都可以從主介面輕鬆進入。

**現有問題**：
- 錄製聲音功能頁面存在但無法進入
- 設定頁面存在但無法進入
- 待答問題頁面存在但無法進入
- 故事詳情頁面缺少「生成語音」按鈕
- 播放按鈕只在有音檔時顯示，但沒有生成音檔的入口

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 家長進入聲音錄製功能 (Priority: P1)

家長首次使用 App 時，需要能夠找到並進入聲音錄製頁面，錄製自己的聲音樣本，讓 AI 可以模仿他們的聲音講故事。

**Why this priority**: 沒有聲音錄製入口，整個「用爸媽聲音講故事」的核心功能就無法啟動。這是使用流程的第一步。

**Independent Test**: 從故事列表頁面，透過導航選單進入聲音錄製頁面，完成錄音後返回。

**Acceptance Scenarios**:

1. **Given** 家長在故事列表頁面，**When** 打開導航選單，**Then** 看到「錄製聲音」選項
2. **Given** 家長點擊「錄製聲音」，**When** 頁面載入，**Then** 進入聲音錄製頁面
3. **Given** 家長完成聲音錄製，**When** 點擊返回，**Then** 回到故事列表頁面

---

### User Story 2 - 家長為故事生成語音 (Priority: P1)

家長選擇一個故事後，需要能夠觸發語音生成，讓 AI 用已錄製的聲音將故事轉換成音檔，之後才能播放。

**Why this priority**: 這是連接「錄音」和「播放故事」兩個核心功能的關鍵環節。沒有這個步驟，故事無法被播放。

**Independent Test**: 進入一個沒有音檔的故事詳情頁，點擊生成語音按鈕，等待處理完成後可以播放。

**Acceptance Scenarios**:

1. **Given** 家長在故事詳情頁面且故事沒有音檔，**When** 頁面載入，**Then** 顯示「生成語音」按鈕
2. **Given** 家長已有錄製的聲音模型，**When** 點擊「生成語音」，**Then** 系統開始生成語音並顯示進度
3. **Given** 語音生成完成，**When** 頁面更新，**Then** 「生成語音」按鈕變成「播放故事」按鈕
4. **Given** 家長沒有錄製聲音模型，**When** 點擊「生成語音」，**Then** 系統提示需要先錄製聲音並引導至錄音頁面

---

### User Story 3 - 家長存取設定頁面 (Priority: P2)

家長需要能夠調整應用程式設定，例如主題模式、自動播放下一個故事、問答提示開關等。

**Why this priority**: 設定功能提升使用體驗，但不影響核心功能運作。

**Independent Test**: 從導航選單進入設定頁面，修改設定後返回，確認設定已生效。

**Acceptance Scenarios**:

1. **Given** 家長在故事列表頁面，**When** 打開導航選單，**Then** 看到「設定」選項
2. **Given** 家長點擊「設定」，**When** 頁面載入，**Then** 顯示可調整的設定項目
3. **Given** 家長修改設定，**When** 返回故事列表，**Then** 設定變更已生效

---

### User Story 4 - 家長查看待答問題 (Priority: P2)

家長需要能夠查看小朋友在問答過程中提出的、超出故事範圍的問題清單。

**Why this priority**: 增進親子互動的重要功能，但需要先有問答功能運作才有意義。

**Independent Test**: 從導航選單進入待答問題頁面，查看問題清單。

**Acceptance Scenarios**:

1. **Given** 家長在故事列表頁面，**When** 打開導航選單，**Then** 看到「待答問題」選項
2. **Given** 有待答問題存在，**When** 進入待答問題頁面，**Then** 顯示問題清單
3. **Given** 沒有待答問題，**When** 進入待答問題頁面，**Then** 顯示空狀態提示

---

### User Story 5 - 導航選單顯示聲音狀態 (Priority: P3)

家長需要在導航選單中看到聲音模型的當前狀態，了解是否已錄製聲音、聲音模型是否就緒。

**Why this priority**: 改善使用體驗，讓家長清楚知道系統狀態，但不是必要功能。

**Independent Test**: 查看導航選單中聲音狀態的顯示是否正確反映實際狀態。

**Acceptance Scenarios**:

1. **Given** 家長尚未錄製聲音，**When** 打開導航選單，**Then** 聲音選項顯示「尚未錄製」狀態
2. **Given** 聲音模型正在處理中，**When** 打開導航選單，**Then** 聲音選項顯示「處理中」狀態
3. **Given** 聲音模型已就緒，**When** 打開導航選單，**Then** 聲音選項顯示「已就緒」狀態

---

### Edge Cases

- 家長在語音生成過程中離開頁面怎麼辦？系統在背景繼續處理，返回時顯示當前進度
- 家長有多個聲音模型怎麼辦？生成語音時預設使用最新的就緒聲音模型
- 網路斷線時嘗試生成語音怎麼辦？顯示離線提示，語音生成需要網路連線
- 導航選單開啟時收到通知怎麼辦？選單保持開啟，通知以非阻擋方式顯示

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST 在故事列表頁面提供導航選單入口（例如抽屜選單或 AppBar 選單）
- **FR-002**: 導航選單 MUST 包含以下選項：錄製聲音、待答問題、設定
- **FR-003**: 導航選單 MUST 顯示聲音模型的當前狀態（未錄製/處理中/已就緒）
- **FR-004**: 故事詳情頁面 MUST 在故事沒有音檔時顯示「生成語音」按鈕
- **FR-005**: 點擊「生成語音」MUST 觸發後端語音生成並顯示處理進度
- **FR-006**: 語音生成完成後，「生成語音」按鈕 MUST 變成「播放故事」按鈕
- **FR-007**: 若家長沒有可用的聲音模型，點擊「生成語音」MUST 引導至聲音錄製頁面
- **FR-008**: 導航選單的每個選項 MUST 能正確導航至對應頁面
- **FR-009**: 從子頁面返回 MUST 回到正確的父頁面

### Key Entities

- **VoiceProfile（聲音模型）**: 代表家長錄製的聲音樣本及其處理狀態（pending/processing/ready/failed）
- **Story（故事）**: 包含故事內容、是否有音檔（hasAudio）、音檔路徑
- **NavigationState（導航狀態）**: 追蹤當前頁面和導航歷史

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 使用者可在 2 次點擊內從故事列表到達任何功能頁面（錄音、設定、待答問題）
- **SC-002**: 100% 的已實作頁面都可從主介面存取
- **SC-003**: 語音生成流程完成率達到 90%（從點擊「生成語音」到成功播放）
- **SC-004**: 首次使用者可在 5 分鐘內完成「錄音 → 選故事 → 生成語音 → 播放」的完整流程
- **SC-005**: 導航選單的聲音狀態顯示與實際狀態一致率達 100%

## Assumptions

- 使用 Drawer（抽屜選單）作為主導航方式，因為這是行動應用的常見模式
- 語音生成使用已有的後端 API 端點
- 聲音模型狀態可透過已有的 voice profile API 取得
- 現有的頁面 UI 不需修改，只需補齊導航入口

## Dependencies

- 依賴 001-flutter-mobile-app 的現有頁面實作
- 依賴 000-StoryBuddy-mvp 的後端 API（語音生成、聲音模型狀態）

## Learnings & Notes

### ElevenLabs Voice Cloning Requirements (2026-01-10)

**問題發現**：Voice Profile 上傳功能在後端呼叫 ElevenLabs API 時失敗。

**根本原因**：
1. **API Key 權限**：需要 `voices_write` 權限才能建立自訂聲音
2. **訂閱方案限制**：即使有 `voices_write` 權限，免費方案不支援 Instant Voice Cloning

**ElevenLabs 錯誤訊息**：
```json
{"detail":{"status":"can_not_use_instant_voice_cloning","message":"Your subscription has no access to use instant voice cloning, please upgrade."}}
```

**解決方案**：
- 升級 ElevenLabs 訂閱至 **Creator 方案**（$22/月）或更高
- Creator 方案包含：
  - Instant Voice Cloning（即時聲音克隆）
  - Professional Voice Cloning（專業聲音克隆）
  - 每月 100,000 字元額度

**測試檔案**：
- `tests/integration/test_elevenlabs_voice_cloning.py` - ElevenLabs 整合測試
- 使用 `@elevenlabs_paid` marker 標記需要付費訂閱的測試
- 執行方式：`pytest tests/integration/test_elevenlabs_voice_cloning.py -m "not elevenlabs_paid"`

**影響範圍**：
- User Story 2（家長為故事生成語音）需要 ElevenLabs 付費訂閱才能完整運作
- App 端的 UI 流程已完成，但後端聲音克隆功能需要訂閱升級
