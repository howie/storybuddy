# Feature Specification: Flutter Mobile App

**Feature Branch**: `001-flutter-mobile-app`
**Created**: 2026-01-05
**Status**: In Progress (~70% complete)
**Progress**: Phase 1-2 ✅ | US1-US4 (Voice, Stories, Playback, Q&A) ~90% | US5-US7 ~50%
**Input**: User description: "用 flutter 產生 mobile app 父母可以用這個 mobile app 給小孩聽故事和互動"

## Overview

This feature implements the Flutter mobile application for StoryBuddy. Parents use this app to:
- Record their voice for AI voice cloning
- Select/import stories
- Play stories using cloned voice
- Enable child interaction through Q&A

The app connects to the existing Python backend API (from 000-StoryBuddy-mvp).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 家長錄製聲音樣本 (Priority: P1)

家長首次使用 App 時，錄製一段中文語音樣本（約 30 秒至 1 分鐘），系統用於建立聲音模型，之後 AI 可以模仿這個聲音講故事。

**Why this priority**: 這是整個 App 的核心功能基礎。沒有家長聲音樣本，就無法提供「用爸爸媽媽聲音講故事」的獨特價值。

**Independent Test**: 家長完成錄音後，可以播放預覽，確認錄音品質，並儲存聲音樣本。

**Acceptance Scenarios**:

1. **Given** 家長首次開啟 App，**When** 點擊「錄製聲音」按鈕並說話 30 秒以上，**Then** 系統顯示錄音完成，並可播放預覽
2. **Given** 家長完成錄音，**When** 點擊「確認儲存」，**Then** 聲音樣本成功上傳至後端，系統顯示「聲音模型建立中」
3. **Given** 錄音時間不足 30 秒，**When** 嘗試儲存，**Then** 系統提示「請錄製至少 30 秒的語音」

---

### User Story 2 - AI 用家長聲音講故事 (Priority: P1)

家長或小朋友選擇一個故事後，AI 使用已建立的家長聲音模型，以模仿家長聲音的方式朗讀故事。

**Why this priority**: 這是 App 的核心價值主張 - 讓忙碌的家長能讓 AI 用自己的聲音為孩子講故事。

**Independent Test**: 選擇故事後，可聽到 AI 用模仿家長聲音的方式講故事。

**Acceptance Scenarios**:

1. **Given** 已有家長聲音模型和一個故事，**When** 點擊「開始講故事」，**Then** App 請求後端生成語音並開始播放
2. **Given** 故事正在播放，**When** 點擊「暫停」，**Then** 故事暫停，可隨時繼續
3. **Given** 故事正在播放，**When** 故事播放完畢，**Then** 系統提示「故事講完了！要開始問答嗎？」
4. **Given** App 在背景或螢幕鎖定，**When** 故事播放中，**Then** 繼續播放（背景播放支援）

---

### User Story 3 - 故事後問答互動 (Priority: P1)

故事講完後，小朋友可以與 AI 進行對話，詢問關於故事的問題。AI 會用簡單易懂的方式回答故事範圍內的問題。

**Why this priority**: 這是教育價值的核心 - 幫助小朋友理解故事內容，培養思考能力。

**Independent Test**: 故事播放完畢後，小朋友可以語音提問並獲得 AI 回答。

**Acceptance Scenarios**:

1. **Given** 故事播放完畢進入問答模式，**When** 小朋友按住麥克風按鈕說話，**Then** 語音被識別並送至後端處理
2. **Given** 小朋友問故事範圍內的問題，**When** AI 回答，**Then** App 播放 AI 語音回答
3. **Given** 小朋友問的問題超出故事範圍，**When** AI 判斷超出範圍，**Then** AI 回答「這是個好問題！我們先記錄起來，等一下問爸爸媽媽好不好？」
4. **Given** 語音無法識別，**When** 重試 3 次後仍失敗，**Then** 顯示「我沒聽清楚，請再試一次或輸入文字」

---

### User Story 4 - 故事列表與選擇 (Priority: P1)

家長或小朋友可以瀏覽故事列表，選擇要播放的故事。

**Why this priority**: 沒有故事列表，用戶無法選擇故事開始聽。

**Independent Test**: 打開 App 可以看到故事列表，點擊任一故事可以進入播放頁面。

**Acceptance Scenarios**:

1. **Given** App 首頁，**When** 顯示故事列表，**Then** 顯示故事標題、來源（匯入/AI生成）、建立時間
2. **Given** 故事列表，**When** 點擊某個故事，**Then** 進入故事詳情/播放頁面
3. **Given** 無網路連線，**When** 查看故事列表，**Then** 顯示已下載的故事（離線模式）

---

### User Story 5 - 匯入外部故事 (Priority: P2)

家長可以匯入外部故事文本（如繪本文字、網路上的故事），作為 AI 講故事的素材。

**Why this priority**: 擴展故事來源，讓家長可以使用自己喜歡的故事內容。

**Independent Test**: 匯入一段故事文字後，可在故事列表中看到並選擇播放。

**Acceptance Scenarios**:

1. **Given** 在故事管理頁面，**When** 點擊「匯入故事」並貼上文字，**Then** 故事被送至後端儲存，加入故事列表
2. **Given** 匯入的文字過長（超過 5000 字），**When** 嘗試儲存，**Then** 系統提示「故事過長，請分成多個章節」
3. **Given** 已匯入故事，**When** 在故事列表點選，**Then** 可以開始用 AI 聲音講述

---

### User Story 6 - AI 編寫故事 (Priority: P2)

家長可以給 AI 一些關鍵字或主題，讓 AI 創作一個適合小朋友的原創故事。

**Why this priority**: 提供無限故事來源，解決「故事講完了」的問題。

**Independent Test**: 輸入主題後，AI 生成一個完整故事並可播放。

**Acceptance Scenarios**:

1. **Given** 在創作故事頁面，**When** 輸入「小兔子、森林、勇敢」，**Then** App 請求後端，AI 生成一個包含這些元素的故事
2. **Given** AI 生成故事後，**When** 家長預覽不滿意，**Then** 可以點擊「重新生成」
3. **Given** AI 生成故事滿意，**When** 點擊「儲存」，**Then** 故事加入故事列表

---

### User Story 7 - 待答問題列表 (Priority: P2)

家長可以查看小朋友問過的超出故事範圍的問題清單。

**Why this priority**: 保留教育機會，增進親子互動。

**Independent Test**: 小朋友問了故事外的問題後，家長可以在「問題清單」中看到。

**Acceptance Scenarios**:

1. **Given** 家長開啟「待答問題」頁面，**When** 列表載入，**Then** 顯示所有待回答問題及提問時間
2. **Given** 家長點選某個問題，**When** 查看詳情，**Then** 可以看到問題內容和關聯的故事

---

### Edge Cases

- 錄音時背景噪音過大怎麼辦？App 監測音量，超過閾值時提示「環境太吵，請找安靜的地方錄音」
- 小朋友連續問很多問題怎麼辦？App 從後端取得問答限制（如 10 個問題），達到後提示「今天問答時間到囉！」
- 網路連線不穩定時怎麼辦？已下載的故事可離線播放，AI 功能需要連線時顯示提示
- 故事播放被來電中斷怎麼辦？App 監聽中斷事件，自動暫停，中斷結束後可手動繼續
- 麥克風權限被拒絕怎麼辦？顯示引導頁面說明如何開啟權限

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST 提供錄音介面，顯示即時波形圖和計時器
- **FR-002**: App MUST 在錄音前請求麥克風權限，權限被拒時顯示引導說明
- **FR-003**: App MUST 將錄製的語音檔案上傳至後端 API
- **FR-004**: App MUST 顯示聲音模型狀態（pending/processing/ready/failed）
- **FR-005**: App MUST 從後端取得故事列表並顯示
- **FR-006**: App MUST 請求後端生成語音並串流播放
- **FR-007**: App MUST 支援語音播放控制（播放/暫停/進度）
- **FR-008**: App MUST 支援背景播放（螢幕關閉、切換 App）
- **FR-009**: App MUST 提供問答互動介面，支援語音輸入
- **FR-010**: App MUST 顯示問答對話歷史
- **FR-011**: App MUST 提供故事匯入介面（文字輸入）
- **FR-012**: App MUST 提供 AI 故事生成介面（關鍵字輸入）
- **FR-013**: App MUST 顯示待答問題列表
- **FR-014**: App MUST 快取已播放的語音檔案供離線使用

### Technical Requirements (Flutter 特定)

- **TR-001**: App MUST 使用 Flutter 3.x 開發，支援 iOS 和 Android
- **TR-002**: App MUST 支援 iOS 14+ 和 Android 8+ (API 26)
- **TR-003**: 錄音 MUST 使用 WAV 或 AAC 格式（44.1kHz、16-bit）
- **TR-004**: App MUST 使用 HTTPS 與後端 API 通訊
- **TR-005**: 敏感資料（如 tokens）MUST 使用 Flutter Secure Storage 儲存
- **TR-006**: App MUST 使用 Provider 或 Riverpod 進行狀態管理
- **TR-007**: App UI MUST 支援深色/淺色主題
- **TR-008**: App MUST 支援國際化（至少繁體中文）
- **TR-009**: 語音播放 MUST 使用 just_audio 或等效套件
- **TR-010**: 語音錄製 MUST 使用 record 或等效套件

### Key Entities (App 端狀態)

- **VoiceProfileState**: 聲音模型狀態（id, status, createdAt）
- **Story**: 故事（id, title, content, source, createdAt, isDownloaded）
- **StoryPlayback**: 播放狀態（currentPosition, duration, isPlaying, audioUrl）
- **QASession**: 問答會話（storyId, messages[], isActive）
- **PendingQuestion**: 待答問題（id, question, storyTitle, askedAt）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: App 啟動時間不超過 3 秒（冷啟動）
- **SC-002**: 錄音介面在按下錄音按鈕後 500ms 內開始錄製
- **SC-003**: 故事列表載入時間不超過 2 秒
- **SC-004**: 語音播放延遲（從點擊到開始播放）不超過 2 秒
- **SC-005**: App 大小不超過 50MB（未含下載內容）
- **SC-006**: 離線模式下可正常播放已下載的故事
- **SC-007**: UI 在各種螢幕尺寸下正確顯示（手機/平板）

## Privacy & Security Requirements

- **PS-001**: 本地快取的語音檔案 MUST 加密儲存
- **PS-002**: API 通訊 MUST 使用 TLS 1.2+
- **PS-003**: 首次錄音前 MUST 顯示隱私同意說明
- **PS-004**: App MUST 提供刪除本地資料的選項
- **PS-005**: 不得在 App 內儲存使用者密碼明文
