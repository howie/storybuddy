# StoryBuddy Backend API - E2E Test Cases

> **Review Document** - 請審閱以下測試案例，確認後我將產生自動化測試程式

## 測試範圍概述

| 模組 | 端點數量 | 測試案例數量 |
|------|---------|-------------|
| Health Check | 2 | 2 |
| Parents API | 5 | 15 |
| Stories API | 9 | 28 |
| Voice Profiles API | 6 | 22 |
| Q&A API | 4 | 18 |
| **Total** | **26** | **85** |

---

## 1. Health Check & Root Endpoints

### 1.1 GET /health
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| HC-001 | 健康檢查端點回應 | 200 OK, `{"status": "healthy", "version": "0.1.0"}` | P0 |

### 1.2 GET /
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| HC-002 | 根端點回應 API 資訊 | 200 OK, 包含 name, version, docs_url | P0 |

---

## 2. Parents API (`/api/v1/parents`)

### 2.1 POST /api/v1/parents - 建立家長帳號
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PA-001 | 使用完整資料建立家長 | 201 Created, 回傳 ParentResponse | P0 |
| PA-002 | 僅使用 name 建立家長 (email 可選) | 201 Created | P0 |
| PA-003 | name 超過 100 字元 | 422 Validation Error | P1 |
| PA-004 | email 格式無效 | 422 Validation Error | P1 |
| PA-005 | 重複 email | 400 Bad Request 或 409 Conflict | P1 |

### 2.2 GET /api/v1/parents - 列出所有家長
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PA-006 | 預設分頁取得家長列表 | 200 OK, limit=100, offset=0 | P0 |
| PA-007 | 自訂 limit 和 offset | 正確分頁回應 | P1 |
| PA-008 | limit 超過 100 | 422 或限制為 100 | P2 |

### 2.3 GET /api/v1/parents/{parent_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PA-009 | 取得存在的家長 | 200 OK, ParentResponse | P0 |
| PA-010 | 取得不存在的 parent_id | 404 Not Found | P0 |
| PA-011 | 無效的 UUID 格式 | 422 Validation Error | P1 |

### 2.4 PATCH /api/v1/parents/{parent_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PA-012 | 更新家長 name | 200 OK, updated_at 更新 | P0 |
| PA-013 | 更新家長 email | 200 OK | P1 |
| PA-014 | 更新不存在的家長 | 404 Not Found | P1 |

### 2.5 DELETE /api/v1/parents/{parent_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PA-015 | 刪除家長及關聯資料 | 204 No Content | P0 |

---

## 3. Stories API (`/api/v1/stories`)

### 3.1 POST /api/v1/stories - 建立故事
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-001 | 建立匯入故事 (source=imported) | 201 Created, word_count 計算正確 | P0 |
| ST-002 | 建立 AI 生成故事 (source=ai_generated) | 201 Created | P0 |
| ST-003 | content 超過 5000 字元 | 422 Validation Error | P1 |
| ST-004 | title 超過 200 字元 | 422 Validation Error | P1 |
| ST-005 | parent_id 不存在 | 404 Not Found | P0 |

### 3.2 GET /api/v1/stories - 列出故事
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-006 | 使用 parent_id 查詢故事 | 200 OK, StoryListResponse | P0 |
| ST-007 | 使用 X-Parent-ID header 查詢 | 200 OK | P1 |
| ST-008 | 使用 source 篩選故事 | 正確篩選結果 | P1 |
| ST-009 | 分頁測試 (limit/offset) | 正確分頁 | P1 |
| ST-010 | 無 parent_id 參數 | 400 或 422 Error | P1 |

### 3.3 GET /api/v1/stories/{story_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-011 | 取得存在的故事 | 200 OK, StoryResponse | P0 |
| ST-012 | 取得不存在的故事 | 404 Not Found | P0 |

### 3.4 PUT /api/v1/stories/{story_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-013 | 更新故事 title | 200 OK | P0 |
| ST-014 | 更新故事 content | 200 OK, word_count 重新計算 | P0 |
| ST-015 | 更新不存在的故事 | 404 Not Found | P1 |

### 3.5 DELETE /api/v1/stories/{story_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-016 | 刪除故事 | 204 No Content | P0 |
| ST-017 | 刪除不存在的故事 | 404 Not Found | P1 |

### 3.6 POST /api/v1/stories/import
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-018 | 匯入故事 (需 X-Parent-ID header) | 201 Created, source=imported | P0 |
| ST-019 | 缺少 X-Parent-ID header | 400 或 422 Error | P1 |
| ST-020 | estimated_duration_minutes 計算正確 | 基於 word_count/200 | P2 |

### 3.7 POST /api/v1/stories/generate
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-021 | 使用關鍵字生成故事 | 201 Created (目前為 placeholder) | P0 |
| ST-022 | keywords 超過 5 個 | 422 Validation Error | P1 |
| ST-023 | keywords 少於 1 個 | 422 Validation Error | P1 |

### 3.8 POST /api/v1/stories/{story_id}/audio
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-024 | 為故事生成語音 | 202 Accepted (非同步) | P0 |
| ST-025 | voice_profile_id 不存在 | 404 Not Found | P1 |
| ST-026 | story_id 不存在 | 404 Not Found | P1 |

### 3.9 GET /api/v1/stories/{story_id}/audio
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| ST-027 | 下載已生成的語音 | 200 OK, audio/mpeg | P0 |
| ST-028 | 語音尚未生成 | 404 Not Found | P1 |

---

## 4. Voice Profiles API (`/api/v1/voice-profiles`)

### 4.1 POST /api/v1/voice-profiles - 建立語音檔案
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-001 | 建立語音檔案 | 201 Created, status=pending | P0 |
| VP-002 | name 超過 100 字元 | 422 Validation Error | P1 |
| VP-003 | parent_id 不存在 | 404 Not Found | P0 |

### 4.2 GET /api/v1/voice-profiles
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-004 | 列出家長的語音檔案 | 200 OK | P0 |
| VP-005 | 缺少 parent_id 參數 | 422 Validation Error | P1 |
| VP-006 | 空結果 (無語音檔案) | 200 OK, 空陣列 | P2 |

### 4.3 GET /api/v1/voice-profiles/{profile_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-007 | 取得語音檔案詳情 | 200 OK, VoiceProfileResponse | P0 |
| VP-008 | 不存在的 profile_id | 404 Not Found | P0 |

### 4.4 DELETE /api/v1/voice-profiles/{profile_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-009 | 刪除語音檔案 | 204 No Content | P0 |
| VP-010 | 刪除不存在的檔案 | 404 Not Found | P1 |

### 4.5 POST /api/v1/voice-profiles/{profile_id}/upload
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-011 | 上傳 WAV 格式語音樣本 | 200 OK, status→processing | P0 |
| VP-012 | 上傳 MP3 格式語音樣本 | 200 OK | P0 |
| VP-013 | 上傳 M4A 格式語音樣本 | 200 OK | P1 |
| VP-014 | 上傳不支援的格式 | 400 Bad Request | P1 |
| VP-015 | 檔案大小超過 50MB | 400 Bad Request | P1 |
| VP-016 | 音檔長度少於 30 秒 | 400 Bad Request | P1 |
| VP-017 | 音檔長度超過 180 秒 | 400 Bad Request | P1 |
| VP-018 | profile_id 不存在 | 404 Not Found | P1 |

### 4.6 POST /api/v1/voice-profiles/{profile_id}/preview
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| VP-019 | 預覽語音 (text 1-500 字) | 200 OK, VoicePreviewResponse | P0 |
| VP-020 | text 超過 500 字元 | 422 Validation Error | P1 |
| VP-021 | text 空白 | 422 Validation Error | P1 |
| VP-022 | profile 狀態非 ready | 400 Bad Request | P1 |

---

## 5. Q&A API (`/api/v1/qa`)

### 5.1 POST /api/v1/qa/sessions - 建立 Q&A 會話
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| QA-001 | 為故事建立 Q&A 會話 | 201 Created, status=active | P0 |
| QA-002 | story_id 不存在 | 404 Not Found | P0 |
| QA-003 | 驗證初始 message_count=0 | message_count: 0 | P1 |

### 5.2 GET /api/v1/qa/sessions/{session_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| QA-004 | 取得會話詳情 (含訊息) | 200 OK, QASessionWithMessages | P0 |
| QA-005 | session_id 不存在 | 404 Not Found | P0 |
| QA-006 | 驗證訊息按 sequence 排序 | 訊息正確排序 | P2 |

### 5.3 PATCH /api/v1/qa/sessions/{session_id}
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| QA-007 | 結束會話 (status=completed) | 200 OK, ended_at 設定 | P0 |
| QA-008 | 結束會話 (status=timeout) | 200 OK | P1 |
| QA-009 | 結束不存在的會話 | 404 Not Found | P1 |
| QA-010 | 結束已結束的會話 | 400 Bad Request | P2 |

### 5.4 POST /api/v1/qa/sessions/{session_id}/messages
| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| QA-011 | 發送問題並取得回應 | 200 OK, SendMessageResponse | P0 |
| QA-012 | 驗證回傳 user_message + assistant_message | 兩則訊息 | P0 |
| QA-013 | content 超過 500 字元 | 422 Validation Error | P1 |
| QA-014 | session_id 不存在 | 404 Not Found | P1 |
| QA-015 | 超過 10 則訊息限制 | 400 Bad Request | P0 |
| QA-016 | 對已結束會話發送訊息 | 400 Bad Request | P1 |
| QA-017 | 驗證 message_count 遞增 | 每次 +2 (問+答) | P2 |
| QA-018 | 驗證 is_in_scope 欄位 | boolean 值正確回傳 | P2 |

---

## 6. 整合測試場景 (E2E Flows)

### 6.1 完整故事生命週期
| ID | 測試案例 | 步驟 | 優先級 |
|----|---------|------|-------|
| E2E-001 | 家長建立→故事匯入→語音生成→Q&A | 1. 建立家長<br>2. 匯入故事<br>3. 建立語音檔案<br>4. 上傳語音樣本<br>5. 生成故事語音<br>6. 建立 Q&A 會話<br>7. 問答互動<br>8. 結束會話 | P0 |

### 6.2 資源關聯刪除測試
| ID | 測試案例 | 步驟 | 優先級 |
|----|---------|------|-------|
| E2E-002 | 刪除家長後關聯資源清除 | 1. 建立家長<br>2. 建立故事、語音檔案<br>3. 刪除家長<br>4. 驗證故事、語音檔案已刪除 | P1 |

### 6.3 Q&A 訊息限制測試
| ID | 測試案例 | 步驟 | 優先級 |
|----|---------|------|-------|
| E2E-003 | 達到 10 則訊息上限 | 1. 建立故事<br>2. 建立 Q&A 會話<br>3. 發送 5 次問答 (10 則訊息)<br>4. 第 6 次問答應被拒絕 | P0 |

---

## 7. 效能與穩定性測試

| ID | 測試案例 | 預期結果 | 優先級 |
|----|---------|---------|-------|
| PERF-001 | 健康檢查回應時間 < 100ms | 快速回應 | P2 |
| PERF-002 | 列表 API 分頁效能 | 100 筆資料 < 500ms | P2 |
| PERF-003 | 併發請求處理 | 10 個併發請求正常處理 | P2 |

---

## 測試環境需求

- **Python**: 3.11+
- **Database**: SQLite (測試用獨立 DB)
- **Test Framework**: pytest + pytest-asyncio + httpx
- **環境變數**: 測試專用 `.env.test`

---

## 待確認項目

請審閱以上測試案例並回覆：

1. **優先級調整** - 是否需要調整任何測試案例的優先級？
2. **缺漏場景** - 是否有遺漏的測試場景？
3. **排除項目** - 是否有不需要測試的項目？
4. **Mock 策略** - 外部服務 (ElevenLabs, Azure, Claude) 是否全部 mock？
5. **測試資料** - 是否需要準備特定的測試資料檔案 (如音檔範例)？

---

*最後更新: 2026-01-06*
