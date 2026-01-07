# Feature Specification: Selectable Voice Kit

**Feature Branch**: `003-selectable-voice-kit`
**Created**: 2026-01-05
**Status**: Draft
**Input**: User description: "研究市面上有哪些語音模組，可以模仿特定卡通人物或性別角色，如旺旺隊，巧虎..等，之後可以用來切換"

## Overview

This feature enables StoryBuddy to offer multiple pre-built character voices for storytelling, beyond just the parent's cloned voice. Children can choose to hear stories narrated by popular cartoon character voices (e.g., PAW Patrol characters, Shimajiro) or different gender/age personas.

The feature involves:
- Research and integration of TTS services that provide character-like voices
- Voice kit management (bundled voices, downloadable voice packs)
- Voice switching UI in the mobile app
- Backend API extensions for voice selection

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 選擇角色聲音播放故事 (Priority: P1)

小朋友可以選擇一個預設的角色聲音（如男孩、女孩、阿公、阿嬤，或卡通風格）來播放故事，而非使用家長的複製聲音。

**Why this priority**: 這是本功能的核心價值 - 讓小朋友可以選擇喜歡的聲音角色來講故事。

**Independent Test**: 選擇角色聲音後，播放故事確認聲音符合選擇的角色特徵。

**Acceptance Scenarios**:

1. **Given** 已有故事準備播放，**When** 點擊「選擇聲音」，**Then** 顯示可用的聲音角色列表
2. **Given** 聲音選擇清單，**When** 選擇「小男孩」角色，**Then** 播放該角色的聲音樣本預覽
3. **Given** 選擇了「小男孩」角色並確認，**When** 開始播放故事，**Then** 故事用小男孩聲音播放

---

### User Story 2 - 下載額外聲音包 (Priority: P2)

家長可以下載額外的聲音角色包（如卡通角色風格），增加可選擇的聲音種類。

**Why this priority**: 擴展聲音選擇，但基本功能可先用內建聲音運作。

**Independent Test**: 下載聲音包後，新角色出現在可選清單中。

**Acceptance Scenarios**:

1. **Given** 在聲音管理頁面，**When** 點擊「下載更多聲音」，**Then** 顯示可下載的聲音包列表
2. **Given** 選擇「卡通冒險風格」聲音包，**When** 點擊下載，**Then** 顯示下載進度並完成後加入可用清單
3. **Given** 已下載某聲音包，**When** 長按該聲音包，**Then** 可選擇刪除以釋放空間

---

### User Story 3 - 混合使用家長聲音與角色聲音 (Priority: P2)

家長可以設定故事中的旁白使用家長聲音，角色對話使用特定角色聲音。

**Why this priority**: 進階功能，需要故事腳本支援角色標記。

**Independent Test**: 播放有多角色的故事時，不同角色使用不同聲音。

**Acceptance Scenarios**:

1. **Given** 故事有多個角色（旁白、主角、配角），**When** 進入聲音配置，**Then** 可為每個角色指定不同聲音
2. **Given** 已配置多角色聲音，**When** 播放故事，**Then** 各角色使用指定的聲音

---

### Edge Cases

- 聲音包下載中斷怎麼辦？支援斷點續傳，並顯示重試選項
- 選擇的聲音服務暫時不可用怎麼辦？回退到預設聲音並顯示提示
- 聲音包版本更新怎麼辦？提示用戶可更新，但不強制

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST 提供聲音選擇介面，列出所有可用角色聲音
- **FR-002**: App MUST 支援播放聲音樣本預覽（3-5 秒）
- **FR-003**: App MUST 記住用戶的聲音偏好設定
- **FR-004**: App MUST 支援下載額外聲音包
- **FR-005**: Backend MUST 支援多種 TTS 服務的聲音生成
- **FR-006**: Backend MUST 提供聲音包目錄 API
- **FR-007**: App MUST 顯示聲音來源標示（如「Powered by ElevenLabs」）

### Technical Requirements

- **TR-001**: 聲音模組架構 MUST 支援插件式擴展（便於新增 TTS 服務）
- **TR-002**: 聲音包 MUST 包含 metadata（名稱、描述、適用年齡、授權資訊）
- **TR-003**: 已下載的聲音包 MUST 加密儲存
- **TR-004**: TTS 請求 MUST 包含 voice_id 參數
- **TR-005**: Backend MUST 支援至少兩種 TTS 服務作為冗餘

### Key Entities

- **VoiceKit**: 聲音包（id, name, description, provider, voices[], downloadSize, isDownloaded）
- **VoiceCharacter**: 單一角色聲音（id, kitId, name, previewUrl, gender, ageGroup, style）
- **VoicePreference**: 用戶偏好設定（userId, defaultVoiceId, storyVoiceMapping{}）
- **TTSProvider**: TTS 服務提供者（id, name, apiEndpoint, supportedLanguages[]）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 聲音預覽播放延遲不超過 1 秒
- **SC-002**: 聲音包下載速度至少達到用戶網速的 80%
- **SC-003**: 支援至少 6 種預設角色聲音（內建，不需下載）
- **SC-004**: 聲音切換在播放中生效延遲不超過 0.5 秒

## Research Questions (本功能核心)

以下問題需要在 plan.md Phase 0 研究階段解答：

1. **市場上有哪些 TTS 服務支援角色化聲音？**
   - ElevenLabs、Azure TTS、Google Cloud TTS、Amazon Polly 等
   - 是否有專門針對兒童/卡通聲音的服務？

2. **授權與版權問題**
   - 能否合法使用「類似」旺旺隊、巧虎風格的聲音？
   - 各 TTS 服務的商業授權條款

3. **中文支援程度**
   - 哪些服務支援自然的繁體中文發音？
   - 支援台灣口音 vs 中國口音

4. **客製化程度**
   - 能否微調現有聲音（如提高音調、加快語速）？
   - 能否用少量樣本訓練新角色？

5. **成本分析**
   - 各服務的定價模式（按字數、按請求、訂閱制）
   - 預估每個故事的語音生成成本

## Privacy & Security Requirements

- **PS-001**: 聲音包下載 MUST 使用 HTTPS
- **PS-002**: 第三方 TTS API 金鑰 MUST 不暴露給客戶端
- **PS-003**: 聲音包授權資訊 MUST 清楚顯示給用戶
